# ADR-0005: Terraform state layout and keyless auth

**Status:** accepted · **Date:** 2026-07-14

## Context

The platform is deployed by several Terraform stacks (`account/`, `platform/` per OpCo × env,
`networking/`, `cicd/`) and is run **ephemerally** — `apply` for a demo, then `destroy` (ADR-0002).
That model puts three hard constraints on state:

1. **Bootstrap ordering.** The state backend must exist *before* any Terraform runs, so it cannot
   be managed by the Terraform that consumes it, and a per-stack `destroy` must never be able to
   delete the state itself.
2. **Blast radius.** A `destroy` of one OpCo's platform stack must not touch another stack's state.
3. **No secrets.** The project's security posture is keyless end-to-end (ADR spec §1) — Terraform
   state, which stores resource attributes in plaintext, must not be reachable via account keys.

## Decision

**One management-scoped storage account, created by a one-time bootstrap step outside every
Terraform lifecycle, holding one state file per stack, accessed keylessly via Entra ID.**

- **Bootstrap** (`infra/bootstrap/bootstrap.sh`, az CLI): a dedicated `rg-lkh-mgmt` resource group
  and a single state storage account `stlkhtfstate<suffix>`, created once per subscription and
  never managed by a platform stack. Documented as "run once."
- **The storage account:** Standard/LRS, hot tier, **blob versioning + soft-delete enabled** (a
  state time machine), **`shared_access_key_enabled = false`**, no public access. State locking is
  free via Azure **blob leases** — no DynamoDB-equivalent needed.
- **One container `tfstate`, one key per stack**, named `{stack}-{opco}-{env}.tfstate` (e.g.
  `account.tfstate`, `platform-alp-dev.tfstate`). "Shared" state means shared across *machines and
  CI*, not one monolithic file.
- **Keyless backend:** the `azurerm` backend uses `use_azuread_auth = true`; humans and the CI SPN
  authenticate with Entra ID holding **Storage Blob Data Contributor** on the container.
- **Backend blocks can't interpolate variables**, so the per-stack key is supplied at init time via
  `-backend-config=<stack>.tfbackend` files, not hardcoded.
- **Cross-stack values pass as explicit input variables**, never `terraform_remote_state` — e.g.
  `account/` outputs `metastore_id`, which is fed to `platform/` as a var. Remote-state data
  sources create hidden coupling between stacks' internals; explicit inputs keep the contract visible.

## Consequences

- The bootstrap step is a documented manual prerequisite, not reproducible-from-zero Terraform —
  an accepted, well-understood exception (the chicken-and-egg is inherent).
- Per-stack keys keep `destroy` blast radius to one stack; the most-destroyed stacks (`networking/`,
  per-OpCo `platform/`) can never endanger `account.tfstate`.
- Keyless + versioned state means a corrupted state rolls back in seconds and no key ever leaks.
- Passing outputs as vars adds a little plumbing per cross-stack dependency, paid deliberately to
  avoid remote-state coupling.

## Alternatives considered

- **Key-based backend auth** (the azurerm default `listKeys`) — rejected: needs account keys /
  control-plane access, breaks the keyless posture, and doesn't work with `Storage Blob Data
  Contributor` alone.
- **One monolithic state file** — rejected: any `destroy` risks the whole platform; no blast-radius
  isolation.
- **`terraform_remote_state` for cross-stack values** — rejected: hidden inter-stack coupling; an
  explicit input var is a visible contract.
- **A mini-Terraform (with local state) for bootstrap** — rejected for a solo project: a ~20-line
  az CLI script is more honest and easier to explain than yet another state file.
- **A state SA per OpCo** — deferred: this is the multi-team answer (separate lifecycles/RBAC per
  owning team), and mirrors the ADR-0001 escalation. Right-sized answer now is one SA + per-stack
  keys; split when an OpCo gets a separate owning team.
