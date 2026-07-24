# Architecture Decision Register

Every consequential decision gets an ADR: context, the decision, its consequences, and the
alternatives that lost. ADRs are immutable once accepted — a changed mind is a *new* ADR that
supersedes the old one, so the register stays an honest history of the design.

| # | Decision | Status |
|---|---|---|
| [0001](ADR-0001-platform-as-deployment-unit.md) | Platform as deployment unit, parameterized by OpCo | accepted |
| [0002](ADR-0002-two-deployment-profiles.md) | Two deployment profiles: `free` and `full` | accepted |
| [0003](ADR-0003-metadata-driven-ingestion.md) | Metadata-driven ingestion — declare sources, don't code them | accepted |
| [0004](ADR-0004-license-and-contribution.md) | License and contribution model | accepted |
| [0005](ADR-0005-terraform-state-layout.md) | Terraform state layout and keyless auth | accepted |
| 0006 | Contract-first quality: ODCS + DQX, quarantine over drop | draft |
