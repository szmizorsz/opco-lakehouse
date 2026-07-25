"""Silver sales — one pipeline definition, instantiated per OpCo.

The OpCo token arrives as a pipeline configuration value (set by the bundle
target, which is generated from the OpCo parameter pack). The same code runs
as `opco-alp-pos-silver` and `opco-bor-pos-silver`; nothing here knows an OpCo by name.

Quality gates follow the contract-first pattern: expectations are generated
from the ODCS data contract for `sales` (contracts/sales.odcs.yml — M2), with
violations quarantined rather than dropped, so data quality is observable
instead of silently "clean".
"""

import dlt
from pyspark.sql import functions as F

OPCO = spark.conf.get("opco.token")         # e.g. "alp" — injected per bundle target
CATALOG = spark.conf.get("opco.catalog")    # e.g. "opco_pos_alp_dev"

SALES_EXPECTATIONS = {
    "valid_sale_id": "saleId IS NOT NULL",
    "valid_store": "storeId IS NOT NULL",
    "positive_quantity": "quantity > 0",
    "sane_price": "unitPrice > 0 AND unitPrice < 10000",
}


@dlt.table(name="silver_sales", comment=f"Deduplicated, contract-validated sales for {OPCO}")
@dlt.expect_all_or_drop(SALES_EXPECTATIONS)
def silver_sales():
    return (
        dlt.read_stream(f"{CATALOG}.bronze.sales")
        # late re-deliveries and page-boundary duplicates are expected (see
        # simulator pathologies) — dedup on business key, keep latest landing
        .withWatermark("soldAt", "3 days")
        .dropDuplicates(["saleId"])
        .withColumn("opco", F.lit(OPCO))
        .withColumn("saleDate", F.to_date("soldAt"))
    )


@dlt.table(name="quarantine_sales", comment="Contract violations, kept observable")
def quarantine_sales():
    src = dlt.read_stream(f"{CATALOG}.bronze.sales")
    failed = ~F.expr(" AND ".join(f"({c})" for c in SALES_EXPECTATIONS.values()))
    return src.where(failed).withColumn("_quarantined_at", F.current_timestamp())
