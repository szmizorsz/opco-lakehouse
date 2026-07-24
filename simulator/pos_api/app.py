"""VendaPOS simulator — a deliberately imperfect POS REST API.

Serves synthetic retail data for Alpina Sports with the pathologies real
integrations meet: late-arriving sales, occasional duplicates, and a slowly
drifting product schema. The imperfections are configurable so pipeline
quality gates can be demonstrated (and tested) against known bad input.

Run locally:  uvicorn simulator.pos_api.app:app --reload
"""

from __future__ import annotations

import random
from datetime import date, datetime, timedelta

from fastapi import FastAPI, Header, HTTPException, Query
from pydantic import BaseModel

app = FastAPI(title="VendaPOS simulator", version="0.1.0")

SEED = 20260713
STORES = [
    {"storeId": f"ST{i:03d}", "name": name, "country": country, "openedOn": opened}
    for i, (name, country, opened) in enumerate(
        [
            ("Alpina Wien Mitte", "AT", "2014-03-01"),
            ("Alpina Graz", "AT", "2016-09-15"),
            ("Alpina München Ost", "DE", "2018-05-20"),
            ("Alpina Zürich HB", "CH", "2021-11-02"),
        ],
        start=1,
    )
]


class Sale(BaseModel):
    saleId: str
    storeId: str
    soldAt: datetime
    sku: str
    quantity: int
    unitPrice: float
    currency: str


def _require_auth(authorization: str | None) -> None:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")


@app.get("/v2/stores")
def stores(authorization: str | None = Header(default=None)):
    """Snapshot endpoint: always returns current state of all stores."""
    _require_auth(authorization)
    return {"items": STORES, "cursor": None}


@app.get("/v2/sales")
def sales(
    from_: date = Query(alias="from"),
    to: date = Query(),
    cursor: int = 0,
    authorization: str | None = Header(default=None),
):
    """Delta endpoint, window-parameterized, max 7 days per request.

    Pathologies on purpose:
      - ~1% duplicate saleIds across adjacent windows (late re-delivery)
      - sales can arrive up to 3 days after their business date
    """
    _require_auth(authorization)
    if (to - from_).days > 7:
        raise HTTPException(status_code=400, detail="Window exceeds 7 days")

    rng = random.Random(f"{SEED}-{from_}-{to}-{cursor}")
    page = [
        Sale(
            saleId=f"S{from_:%Y%m%d}{cursor + n:06d}",
            storeId=rng.choice(STORES)["storeId"],
            soldAt=datetime.combine(from_, datetime.min.time())
            + timedelta(minutes=rng.randrange(0, 7 * 24 * 60)),
            sku=f"SKU{rng.randrange(1, 5000):05d}",
            quantity=rng.choice([1, 1, 1, 2, 3]),
            unitPrice=round(rng.uniform(4.5, 399.0), 2),
            currency="EUR",
        ).model_dump()
        for n in range(500)
    ]
    if rng.random() < 0.01 and cursor > 0:  # duplicate leak across pages
        page[0]["saleId"] = f"S{from_:%Y%m%d}{cursor - 1:06d}"

    next_cursor = cursor + 500 if cursor < 2000 else None
    return {"items": page, "cursor": next_cursor}
