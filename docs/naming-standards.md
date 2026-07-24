# Naming standards

One page, no exceptions. Tokens: `{domain}` = source-aligned or product domain (`pos`, `erp`,
`hr`, `gold_group`), `{opco}` = 3-letter OpCo token (`alp`, `bor`), `{env}` = `dev | uat | prd`.

| Object | Pattern | Example |
|---|---|---|
| Catalog (per-OpCo) | `{domain}_{opco}_{env}` | `pos_alp_prd` |
| Catalog (group products) | `gold_group_{env}` | `gold_group_prd` |
| Schema | medallion stage | `bronze`, `silver`, plus `quarantine` |
| External location | `{domain}-{opco}-{env}` | `pos-alp-prd` |
| Storage container prefix | `{storage_prefix}-{env}` | `lkh-alp-prd` |
| Deployment SPN | `SVC-LKH-{OPCO}-DEPLOY` | `SVC-LKH-ALP-DEPLOY` |
| Jobs SPN | `SVC-LKH-{OPCO}-JOBS` | `SVC-LKH-ALP-JOBS` |
| Entra group | `RBAC-LKH-{OPCO}-{role}` | `RBAC-LKH-ALP-Engineer` |
| Job / pipeline | `{opco}-{domain}-{purpose}` | `alp-pos-ingest` |
| Bundle target | `{opco}_{env}` | `bor_dev` |
| Terraform state key | `{stack}-{opco}-{env}.tfstate` | `platform-alp-dev.tfstate` |

Rules of thumb:

- **Underscores inside Unity Catalog names, hyphens everywhere Azure prefers them.** Never mix.
- Environment lives at the **end** of every name; scanning any sorted list groups by function first.
- The OpCo token appears in **every** per-OpCo object name — if you can't tell whose object it
  is from the name alone, the name is wrong.
- No abbreviations beyond the fixed tokens; `wrk`, `tmp`, `misc` are how platforms rot.
