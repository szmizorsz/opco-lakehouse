# Infra — Iteration 1: Foundation

**Status:** ✅ landed · `validate` clean + dry-run planned against Datapao; `apply` pending sign-off · **Parent:** [infra-end-state-spec.md](infra-end-state-spec.md)

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
| Management RG | `rg-opco-mgmt` | bootstrap; outside every TF lifecycle |
| State storage account | `stopcotfstate<suffix>` | keyless, versioned, soft-delete (ADR-0005) |
| Metastore | `opco-metastore-{region}` | one per region; **no** metastore-root storage |
| Workspace × env | `adb-opco-{env}` | Premium SKU; `for_each` over `environments` |
| Metastore assignment × env | — | every workspace → the one metastore |
| Account group | `RBAC-OPCO-PLATFORM-Admin` | group platform team |

## File layout

Three parts: a one-off **bootstrap** script, reusable **modules**, and the **`account/`** root stack
that composes them into the deployment. Nothing here is OpCo-specific.

```
infra/
├── bootstrap/
│   └── bootstrap.sh          # az CLI, run ONCE per subscription (pre-Terraform):
│                             #   creates rg-opco-mgmt + the keyless state storage account
│
├── modules/                  # reusable building blocks (abstraction, not a script)
│   ├── metastore/
│   │   ├── main.tf           #   databricks_metastore — one per region, no root storage
│   │   ├── variables.tf      #   name, region, force_destroy
│   │   ├── outputs.tf        #   id → consumed by the account stack
│   │   └── versions.tf       #   required_providers: databricks/databricks
│   └── workspace/
│       ├── main.tf           #   azurerm_databricks_workspace — Premium, one per env
│       ├── variables.tf      #   name, env, resource_group_name, location
│       ├── outputs.tf        #   workspace_id, workspace_url, resource_id
│       └── versions.tf       #   required_providers: hashicorp/azurerm
│
└── account/                  # the ROOT stack — `terraform apply` runs here
    ├── providers.tf          #   azurerm + account-host databricks provider + version pins
    ├── backend.tf            #   azurerm remote state, use_azuread_auth (keyless — ADR-0005)
    ├── account.tfbackend     #   state SA + KEY, passed at init (backend blocks can't take vars)
    ├── variables.tf          #   subscription_id, databricks_account_id, region, environments,
    │                         #     existing_metastore_id, resource_group_name
    ├── terraform.tfvars.example  # copy → terraform.tfvars (gitignored) and fill in
    ├── main.tf               #   composes the modules: metastore (create OR reuse) +
    │                         #     workspace per env + metastore assignment + account group
    └── outputs.tf            #   metastore_id, workspace_ids, workspace_urls (Iteration-2 contract)
```

**How the pieces fit.** `bootstrap.sh` runs first, by hand, creating the state backend that
`backend.tf` then points at — a deliberate chicken-and-egg break (ADR-0005). `account/main.tf` is
the only file that *composes*: it calls the `metastore` and `workspace` modules and wires the
`databricks_metastore_assignment` between them. Configuration arrives in **two** files on purpose —
`account.tfbackend` (*where state lives*, supplied at `terraform init`) and `terraform.tfvars`
(*this deployment's values*, gitignored). The modules never touch a backend or read tfvars; they
take inputs and return outputs, which is exactly what keeps them reusable across stacks.

## Design decisions specific to this iteration

- **Workspaces live in `account/`, not a separate stack.** They are group-level and per-env, so
  they belong with the metastore in the apply-rarely foundation (keeps to the 4 documented stacks).
- **Metastore has no root storage.** Managed storage is set at the catalog level in Iteration 2,
  keeping each OpCo's data in its own boundary rather than a shared metastore root.
- **Provider split is visible here:** `providers.tf` configures the **account-host** `databricks`
  provider (metastore/assignment/groups) alongside `azurerm` (workspaces) — the boundary from
  [infra/README.md](../../../infra/README.md).
- **Metastore is create-or-reuse** via `existing_metastore_id`. A shared account already has a
  metastore in the region (ADR-0001: one per region), so the stack *reuses* it (assignment only);
  set the var to `""` for a fresh region/sandbox to *create* one. Each module also declares its own
  `required_providers` (`versions.tf`) so the stack initialises cleanly.

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
STATE_SA=stopcotfstate<suffix> infra/bootstrap/bootstrap.sh

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
- [x] `terraform validate` clean
- [x] `terraform plan` verified against Datapao (dry-run: reuses the WEU metastore, dev-only, 4 to add)
- [ ] `terraform apply` — pending platform-owner sign-off + subscription Contributor rights

## Follow-ups

- Run the first ephemeral `apply` once sign-off + Contributor rights are in place (last DoD item).
- Consider account-layer hardening in a later pass: metastore admin assignment, audit-log delivery,
  IP access lists.
