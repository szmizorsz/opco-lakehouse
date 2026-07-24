# ADR-0002: Two deployment profiles — `free` and `full`

**Status:** accepted · **Date:** 2026-07-13

## Context

A reference implementation serves two audiences with conflicting needs. Practitioners who want
to *run* it need zero-friction, zero-cost setup — anything that starts with "create an Azure
subscription" loses most of them. Architects and platform teams who want to *evaluate* it need
the parts that only exist with real cloud infrastructure: the Terraform account layer, network
isolation, per-OpCo service principals, grants as code.

Databricks Free Edition covers a surprising share of the stack (Unity Catalog, serverless jobs
and SQL, declarative pipelines, Asset Bundles, Genie) but is serverless-only, single-workspace,
and has no account-level APIs — the platform layer cannot be demonstrated there.

## Decision

Ship **two first-class deployment profiles from the same codebase**:

- **`free`** — targets Databricks Free Edition. Simulator runs locally or in-notebook; ingestion,
  medallion pipelines, contracts/quality, metric views and Genie all work. Deployable with
  Asset Bundles only. This is the default path in every README.
- **`full`** — targets an Azure subscription. Adds the Terraform account/platform layer,
  per-OpCo isolation, secure networking. Designed to be **ephemeral**: applied for a demo or
  recording session and destroyed after (fixed-cost networking components — NAT gateway,
  private endpoints — make an always-on demo platform pointlessly expensive).

Profile selection is a bundle target / variable, never a code fork.

## Consequences

- Adoption and credibility are served by different profiles instead of compromising one path.
- "The entire platform deploys from zero in under an hour, reproducibly" becomes a demonstrated
  claim rather than a slide — `terraform apply` → demo → `destroy` is part of the story.
- Cost of the discipline: every feature must state which profiles it supports; CI validates the
  `free` profile on every PR, the `full` profile on a schedule.
