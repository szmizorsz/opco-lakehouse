# Infra — Iteration 1: Foundation

**Status:** ✅ landed (untested against a live subscription) · **Parent:** [infra-end-state-spec.md](infra-end-state-spec.md)

The regional foundation every later iteration stands on: the **state backend**, the **one metastore
per region**, the **per-environment workspaces**, and their **metastore assignment**. This iteration
contains nothing OpCo-specific — it is the group platform team's layer (ADR-0001).

## Scope

| In | Out (later iterations) |
|---|---|
| `bootstrap/` state backend | per-OpCo catalogs, grants, SPNs → Iteration 2 |
| `account/` stack (metastore, workspaces, assignment, account group) | secure networking → Iteration 3 |
| `modules/metastore`, `modules/workspace` | CI identity → Iteration 4 |

## Delivered resources

| Resource | Name | Notes |
|---|---|---|
| Management RG | `rg-lkh-mgmt` | bootstrap; outside every TF lifecycle |
| State storage account | `stlkhtfstate<suffix>` | keyless, versioned, soft-delete (ADR-0005) |
| Metastore | `lkh-metastore-{region}` | one per region; **no** metastore-root storage |
| Workspace × env | `adb-lkh-{env}` | Premium SKU; `for_each` over `environments` |
| Metastore assignment × env | — | every workspace → the one metastore |
| Account group | `RBAC-LKH-PLATFORM-Admin` | group platform team |

## File layout

```
infra/
├── bootstrap/bootstrap.sh              # az CLI, run once per subscription
├── modules/
│   ├── metastore/{main,variables,outputs}.tf
│   └── workspace/{main,variables,outputs}.tf
└── account/
    ├── providers.tf                    # azurerm + account-host databricks provider
    ├── backend.tf + account.tfbackend  # keyless AAD backend, per-stack key
    ├── variables.tf + terraform.tfvars.example
    ├── main.tf                         # metastore + workspaces + assignment + group
    └── outputs.tf                      # metastore_id, workspace_ids, workspace_urls
```

## Design decisions specific to this iteration

- **Workspaces live in `account/`, not a separate stack.** They are group-level and per-env, so
  they belong with the metastore in the apply-rarely foundation (keeps to the 4 documented stacks).
- **Metastore has no root storage.** Managed storage is set at the catalog level in Iteration 2,
  keeping each OpCo's data in its own boundary rather than a shared metastore root.
- **Provider split is visible here:** `providers.tf` configures the **account-host** `databricks`
  provider (metastore/assignment/groups) alongside `azurerm` (workspaces) — the boundary from
  [infra/README.md](../../../infra/README.md).

## Interface consumed by later iterations

`account/outputs.tf` is the contract (passed as **input vars**, not remote state — ADR-0005):

| Output | Consumer |
|---|---|
| `metastore_id` | Iteration 2 `platform/` — catalog creation |
| `workspace_urls[env]` | Iteration 2 `platform/` — workspace-host provider target |
| `workspace_ids[env]` | assignment / diagnostics |

## How to apply

```bash
# 0. once per subscription
STATE_SA=stlkhtfstate<suffix> infra/bootstrap/bootstrap.sh

# 1. the account stack
cd infra/account
cp terraform.tfvars.example terraform.tfvars   # fill subscription_id + databricks_account_id
terraform init -backend-config=account.tfbackend
terraform plan
terraform apply
```

## Definition of done

- [x] Files exist, formatted, provider/auth split documented
- [x] `metastore_id` / `workspace_urls` exposed as the Iteration-2 contract
- [ ] `terraform validate` clean *(blocked: no CLI/creds in this environment)*
- [ ] `plan`/`apply` verified against a live Azure subscription *(pending Azure access)*

## Follow-ups

- Promote the two unchecked DoD items once Azure access exists (first ephemeral apply).
- Add a workspace-name row to [naming-standards.md](../../naming-standards.md) (`adb-lkh-{env}` —
  workspaces aren't in the table yet, since they're not per-OpCo).
- Consider account-layer hardening in a later pass: metastore admin assignment, audit-log delivery,
  IP access lists.
