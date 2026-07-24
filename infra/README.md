# infra — Terraform platform layer (`full` profile)

Lands in M1 (see roadmap). Planned stacks, one state file each (ADR-0005, draft):

- `bootstrap/` — one-time script: management RG + state storage account (blob-lease locking,
  versioning, Entra-only auth — no account keys anywhere)
- `account/` — regional foundation: the UC metastore, one workspace per env, metastore
  assignment, and account-level groups; applied rarely
- `platform/` — per-OpCo, per-env: catalogs, external locations, SPNs, grants as code;
  stamped from `opcos/*.yml`, state key `platform-{opco}-{env}.tfstate`
- `networking/` — optional secure-networking module (VNet injection, private endpoints);
  the most-destroyed stack, since its idle cost is the platform's highest

## Azure portal footprint vs. control-plane objects

Half of this platform is *not* an Azure resource, which trips people up. Two Terraform providers
split the work along that line:

- **`azurerm`** creates the **Azure-portal objects** — the ones you can browse in a resource group:
  the workspace (`Microsoft.Databricks/workspaces`, portal name "Azure Databricks Service"), its
  auto-created managed resource group, the Access Connector
  (`Microsoft.Databricks/accessConnectors`, UC's managed identity for storage), and the storage
  accounts behind the metastore/catalogs and the Terraform state.
- **`databricks`**, pointed at the **account host** (`accounts.azuredatabricks.net`), creates the
  **control-plane objects** that have *no* Azure resource at all: the Unity Catalog **metastore**,
  **catalogs**, external locations, grants, and account-level groups/SPNs.

So the things ADR-0001 hinges on — the **Databricks account** (≈ your Entra tenant, 1:1, no ARM
object), the **account console** (`accounts.azuredatabricks.net`, not a portal blade), and the
**metastore** (a control-plane object) — will *not* appear when a reviewer browses resource groups.
The portal only ever shows **workspaces, access connectors, storage, and managed RGs**; everything
governance-related lives in the account console and is managed by the `databricks` provider. The
`account/` stack is where that provider runs; `platform/` uses it for per-OpCo catalogs/grants and
`azurerm` for the storage/connector each OpCo needs.

Auth note: the `databricks` provider authenticates against the account as an **account admin** —
initially the Entra tenant's Global Administrators, then whoever they designate.
