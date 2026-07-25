# Infra — end-state specification

**Status:** living spec · **Owner:** platform · **Profile:** `full` only (see [ADR-0002](../../adr/ADR-0002-two-deployment-profiles.md))

This document defines the **target end-state** of the Terraform platform layer (`infra/`) and the
**iterations** that build toward it. Each iteration is a reviewable increment with its own
definition-of-done and its own spec under this folder:

- **Iteration 1 — Foundation:** [iteration-1-foundation.md](iteration-1-foundation.md) ✅ landed

Everything else is specified here first, then implemented against this spec.

The `free` profile deploys **no infrastructure** — Databricks Free Edition already supplies a
workspace and metastore. Everything below is the `full` (Azure + Terraform) profile only.

---

## 1. Design inputs

| Input | Source | What it fixes |
|---|---|---|
| Platform-as-deployment-unit; catalog is the OpCo boundary | [ADR-0001](../../adr/ADR-0001-platform-as-deployment-unit.md) | One account, one metastore/region, per-env workspaces, per-OpCo catalogs |
| Two deployment profiles | [ADR-0002](../../adr/ADR-0002-two-deployment-profiles.md) | Infra is `full`-profile only; runs ephemerally (apply → demo → destroy) |
| Metadata-driven onboarding | [ADR-0003](../../adr/ADR-0003-metadata-driven-ingestion.md) | Per-OpCo stacks are stamped from `opcos/*.yml` |
| State layout & keyless auth | [ADR-0005](../../adr/ADR-0005-terraform-state-layout.md) | One state file per stack, keyless AAD backend, blob-lease locking |
| Naming | [naming-standards.md](../../naming-standards.md) | Every resource name below follows the token rules |

**Non-negotiable principles**

- **Keyless everywhere.** No storage-account keys, no client secrets. Humans/CI use Entra ID; CI
  uses OIDC federated credentials; the state backend uses `use_azuread_auth = true`.
- **Heterogeneity in parameters, never in code.** A new OpCo is a new `opcos/*.yml` + a new state
  key — no new `.tf`.
- **Ephemeral-first.** Every stack must `destroy` cleanly; `force_destroy = true` is acceptable
  because the platform is demo/reference, not a system of record.
- **The metastore, account, and account console are control-plane objects with no Azure resource**
  (see [infra/README.md](../../../infra/README.md)); Terraform manages them via the account-host
  `databricks` provider.

---

## 2. Target architecture

The platform is built by **one bootstrap step plus four Terraform stacks**, deliberately split so
each has its own lifecycle, blast radius, and state file. Read them as layers: `bootstrap` prepares
somewhere to keep Terraform state, `account` builds the shared regional base, `platform` stamps each
OpCo onto it, `networking` optionally hardens it, and `cicd` gives automation an identity. The rest
of this section defines the stacks (2.1), how they authenticate (2.2) and store state (2.3), exactly
what each creates (2.4), and what a reviewer actually sees in the Azure portal (2.5).

### 2.1 Stack map

| # | Stack | Lifecycle | Providers | State key |
|---|---|---|---|---|
| 0 | `bootstrap/` | once per subscription (not Terraform) | az CLI | — (creates the backend) |
| 1 | `account/` | rarely | `azurerm` + `databricks`(account) | `account.tfstate` |
| 2 | `platform/` | per OpCo × env | `azurerm` + `databricks`(workspace) | `platform-{opco}-{env}.tfstate` |
| 3 | `networking/` | most-destroyed (idle cost) | `azurerm` | `networking-{env}.tfstate` |
| 4 | `cicd/` | rarely | `azuread` + `azurerm` + `databricks`(account) | `cicd.tfstate` |

**What each stack is for**

- **`bootstrap/`** — the chicken-and-egg breaker. Before Terraform can store its state anywhere,
  *something* must first create the storage that holds that state. A tiny one-time `az` script makes
  a management resource group and a locked-down storage account, then gets out of the way. Run once
  per subscription, never again.
- **`account/`** — the shared regional foundation, built once and rarely touched. It owns the Unity
  Catalog metastore (or reuses the region's existing one), the per-environment workspaces, and the
  account-level admin group. Nothing here is OpCo-specific — it's the ground every OpCo stands on.
- **`platform/`** — the per-OpCo stack, and the heart of the "onboard an OpCo = one parameter pack"
  idea. Applied once per OpCo × environment, it reads `opcos/{opco}.yml` and stamps that OpCo's
  catalogs, storage, identities, and grants. Adding an OpCo is a new parameter pack + a new state
  key — no new code.
- **`networking/`** — the optional "make it secure" stack: VNet injection, private endpoints, NAT.
  Kept separate because it carries the platform's only meaningful idle cost, so it's the stack you
  spin up and tear down most often.
- **`cicd/`** — the identity CI deploys *with*. A keyless (OIDC) service principal plus just enough
  permissions to run `terraform` and `bundle deploy`. It provisions *who CI is*, not *what CI does*
  (those workflows live in platform-ops).

### 2.2 Provider & auth model

| Provider | Host | Manages | Auth |
|---|---|---|---|
| `azurerm` | Azure Resource Manager | workspaces, storage, access connectors, networking | Azure CLI / OIDC |
| `databricks` (account) | `accounts.azuredatabricks.net` | metastore, assignment, account groups & SPNs | account admin (Entra Global Admin → delegated) |
| `databricks` (workspace) | `https://adb-*.azuredatabricks.net` | catalogs, schemas, external locations, grants | workspace admin SPN / OIDC |

### 2.3 State model (ADR-0005)

One `azurerm` backend, container `tfstate`, **one key per stack** — split along blast-radius
boundaries so a `destroy` of one stack cannot touch another. Backend blocks can't interpolate
variables, so the key is passed per-stack via `-backend-config=*.tfbackend`. Locking is free
(blob leases). Cross-stack values (e.g. `metastore_id`) pass as **explicit input vars**, not
`terraform_remote_state`, to avoid hidden coupling.

### 2.4 Resource inventory (the end state)

**Stack 0 — `bootstrap/`** — breaks the state chicken-and-egg: creates the one place Terraform state
can live, *outside* any Terraform lifecycle so a `destroy` can never delete it. Run once, by hand.
- `rg-opco-mgmt` (management RG, outside every Terraform lifecycle)
- `stopcotfstate<suffix>` state SA — LRS, `shared_access_key_enabled = false`, blob versioning +
  soft-delete
- container `tfstate`; RBAC `Storage Blob Data Contributor` to admins + CI SPN

**Stack 1 — `account/`** *(regional foundation — see [iteration 1](iteration-1-foundation.md))* — the
shared base every OpCo builds on: one metastore (created, or reused in a shared account), the
per-environment workspaces, and the platform admin group. Applied once, rarely changed.
- `databricks_metastore` — one per region, no metastore-root storage (catalog-level storage instead)
- `azurerm_databricks_workspace` × env — `adb-opco-{env}`, Premium SKU
- `databricks_metastore_assignment` × env
- `databricks_group` `RBAC-OPCO-PLATFORM-Admin` (+ end-state: account SPN for CI, metastore admin)

**Stack 2 — `platform/`** *(per OpCo × env, from `opcos/{opco}.yml`)* — everything a single OpCo
needs, stamped from its parameter pack: data storage, the identities that reach it, the catalogs its
data lands in, and the grants that govern them. This is what an onboarding PR triggers. For each
`domain` × `env`:
- `azurerm_storage_account` per OpCo (ADLS Gen2, HNS) + container `{storage_prefix}-{env}` per env
- `azurerm_databricks_access_connector` per OpCo + `Storage Blob Data Contributor` role assignment
- `databricks_storage_credential` (wraps the access connector) + `databricks_external_location`
  `opco-{domain}-{opco}-{env}`
- `databricks_catalog` `opco_{domain}_{opco}_{env}` + `databricks_schema` `bronze` / `silver` / `quarantine`
- `databricks_service_principal` `SVC-OPCO-{OPCO}-DEPLOY` and `SVC-OPCO-{OPCO}-JOBS`
- `databricks_group` `RBAC-OPCO-{OPCO}-{role}` + `databricks_grants` on catalogs/schemas (grants as code)

**Stack 3 — `networking/`** *(secure profile, optional, per env)* — wraps the workspaces and storage
in private networking for the *secure* profile. Its own stack because private endpoints + NAT are
the platform's main idle cost, so it's applied and destroyed most often.
- `azurerm_virtual_network` + host/container subnets (VNet injection), NSGs
- `azurerm_private_endpoint` for workspace + storage; private DNS zones
- `azurerm_nat_gateway` (documented as the main idle cost — see ADR-0002 cost profile)

**Stack 4 — `cicd/`** *(keyless CI identity only — the workflows that use it live in `platform-ops/`)* —
gives CI a keyless identity to deploy with: a federated service principal plus exactly the role
assignments it needs, and nothing more.
- `azuread_application` + SPN with **GitHub OIDC federated credentials** (no secrets)
- role assignments: `Contributor` on platform RGs, `Storage Blob Data Contributor` on state + data SAs
- Databricks account/workspace admin membership for the deploy SPN

> **Boundary:** `infra/cicd/` provisions *identity and permissions* only. The GitHub Actions
> workflows that call `terraform plan/apply` and `databricks bundle deploy` are **platform-ops**
> (per the module map). Infra owns *who CI is allowed to be*; platform-ops owns *what CI does*.

### 2.5 Azure portal footprint

A reviewer browsing resource groups sees **only**: workspaces, access connectors, storage accounts,
networking, managed RGs, and the CI SPN. The **metastore, catalogs, grants, account groups** are
control-plane and live in the account console. This split *is* the `azurerm` vs `databricks`
provider boundary.

---

## 3. Iteration plan

Legend: ✅ done · 🔜 next · ⬜ planned

| Iter | Name | Delivers | Spec | Status |
|---|---|---|---|---|
| 1 | **Foundation** | `bootstrap/` + `account/` + `modules/{metastore,workspace}` | [iteration-1](iteration-1-foundation.md) | ✅ |
| 2 | **Platform** | `modules/opco_platform` + `platform/`, driven by `opcos/*.yml`; onboard Alpina + Boreal | *tbd* | 🔜 |
| 3 | **Networking** | `networking/` secure-profile module, applied/destroyed per demo | *tbd* | ⬜ |
| 4 | **CI/CD identity** | `cicd/` OIDC identity + role assignments (workflows are platform-ops) | *tbd* | ⬜ |

### Iteration 2 — Platform 🔜
The per-OpCo half that makes "onboard an OpCo = one parameter pack" real: `modules/opco_platform`
consumes `yamldecode(file("opcos/{opco}.yml"))`, loops `domains × environments`, and stamps the
Stack-2 inventory above. Instantiated per OpCo via `platform-{opco}-{env}.tfbackend`.
**DoD:** `terraform plan` produces the full Alpina resource set from `alpina.yml` and a *structurally
different but code-identical* set from `boreal.yml` (file-export POS, no UAT) — the demo moment.

### Iteration 3 — Networking ⬜
VNet injection + private endpoints + NAT, isolated in its own most-destroyed stack.
**DoD:** apply/destroy cycle documented with its idle-cost figure.

### Iteration 4 — CI/CD identity ⬜
Keyless GitHub OIDC → Azure + Databricks identity + role assignments. The consuming workflows
(`terraform plan` on PR, gated `apply` on merge, `bundle deploy`) are specified and built under
`platform-ops/`.
**DoD:** the CI SPN + federated credential exist in code; a platform-ops workflow can assume it
with no stored secrets.

---

## 4. Open decisions (resolve as iterations reach them)

1. **Storage granularity** — one SA per OpCo with per-domain-env containers (current assumption) vs
   one SA per domain. Trade-off: blast radius vs account-count limits.
2. **Catalog-managed storage vs external locations only** — whether each catalog gets managed
   storage or all data sits behind external locations. Affects the metastore-root decision.
3. **Per-OpCo env matrix** comes from the `environments:` list in each `opcos/*.yml` (Alpina =
   dev/uat/prd, Boreal = dev/prd) — the platform stack must not assume three envs.
4. **Multi-region** — a second metastore appears only when an OpCo needs another region (ADR-0001
   escalation). Out of scope until a trigger exists.
5. **RBAC role set** — which `{role}` groups per OpCo (Engineer / Reader / Steward?) and the exact
   grant matrix. Belongs in a grants sub-spec when Iteration 2 lands.
