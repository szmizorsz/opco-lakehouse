# Naming standards

One page, no exceptions.

**Platform prefix.** Every object this platform creates carries the fixed `opco` prefix (`opco_`
inside Unity Catalog names, `opco-` / `OPCO-` where Azure/Entra prefer hyphens or caps). The
platform deploys into **shared** infrastructure — an existing metastore holding many other catalogs,
a subscription full of resource groups and storage, a tenant full of service principals and groups —
so the prefix is what lets anyone tell *our* objects apart at a glance.

Tokens: `{domain}` = source-aligned or product domain (`pos`, `erp`, `hr`, `gold_group`),
`{opco}` = 3-letter OpCo token (`alp`, `bor`), `{env}` = `dev | uat | prd`.

## Per-OpCo objects

| Object | Pattern | Example |
|---|---|---|
| Catalog (per-OpCo) | `opco_{domain}_{opco}_{env}` | `opco_pos_alp_prd` |
| Catalog (group products) | `opco_gold_group_{env}` | `opco_gold_group_prd` |
| Schema | medallion stage | `bronze`, `silver`, plus `quarantine` |
| External location | `opco-{domain}-{opco}-{env}` | `opco-pos-alp-prd` |
| Storage container prefix | `{storage_prefix}-{env}` | `opco-alp-prd` |
| Deployment SPN | `SVC-OPCO-{OPCO}-DEPLOY` | `SVC-OPCO-ALP-DEPLOY` |
| Jobs SPN | `SVC-OPCO-{OPCO}-JOBS` | `SVC-OPCO-ALP-JOBS` |
| Entra group | `RBAC-OPCO-{OPCO}-{role}` | `RBAC-OPCO-ALP-Engineer` |
| Job / pipeline | `opco-{opco}-{domain}-{purpose}` | `opco-alp-pos-ingest` |
| Bundle target | `opco_{opco}_{env}` | `opco_bor_dev` |

`{storage_prefix}` is `opco-{opco}` (e.g. `opco-alp`), so a container is `opco-alp-prd`.

## Group-level / platform objects (not per-OpCo)

| Object | Pattern | Example |
|---|---|---|
| Workspace | `adb-opco-{env}` | `adb-opco-dev` |
| Metastore (when created) | `opco-metastore-{region}` | `opco-metastore-westeurope` |
| Platform resource group | `rg-opco-platform` | `rg-opco-platform` |
| Management resource group | `rg-opco-mgmt` | `rg-opco-mgmt` |
| State storage account | `stopcotfstate<suffix>` | `stopcotfstatea1b2` |
| Platform admin group | `RBAC-OPCO-PLATFORM-Admin` | `RBAC-OPCO-PLATFORM-Admin` |
| Terraform state key | `{stack}-{opco}-{env}.tfstate` | `platform-alp-dev.tfstate` |

## Rules of thumb

- **The `opco` prefix is on every object we create** — in a shared metastore/subscription/tenant you
  can spot ours at a glance. If a name doesn't start with `opco`, it isn't ours.
- **Underscores inside Unity Catalog names, hyphens everywhere Azure prefers them.** Never mix.
  Storage-account names allow neither, hence the run-together `stopcotfstate`.
- Environment lives at the **end** of every name; scanning a sorted list groups by function first.
- The OpCo token appears in **every** per-OpCo object name — if you can't tell whose object it is
  from the name alone, the name is wrong.
- No abbreviations beyond the fixed tokens; `wrk`, `tmp`, `misc` are how platforms rot.
