# ADR-0003: Metadata-driven ingestion — declare sources, don't code them

**Status:** accepted · **Date:** 2026-07-13

## Context

Across OpCos the *transport* patterns repeat (REST APIs, CDC-capable databases, file drops)
while the *specifics* vary endlessly: which endpoint, which auth, full snapshot vs incremental
delta, windowed by date vs threshold by key, pagination style, quirks. Writing a connector per
entity per OpCo multiplies code linearly with acquisitions — the exact failure mode ADR-0001
exists to prevent.

The industry default for managed connectors (Lakeflow Connect) covers standard databases and
SaaS sources, but acquired retailers reliably bring at least one system it does not cover —
typically a niche POS with a bespoke REST API or file exports.

## Decision

Ingestion preference order: **Lakeflow Connect → Auto Loader for files → the in-repo
metadata-driven REST framework → anything custom (last resort, requires an ADR)**.

For REST sources, entities are **declared, not coded**, in `ingestion/sources/*.yml`. The
framework interprets two orthogonal axes per entity:

- **`load_type`** — what a fetched batch *means*:
  - `snapshot`: the API returns current state; land it, and let the base layer preserve
    history (a snapshot **never overwrites** base — see the layering note below).
  - `delta`: the API returns changes since a point; land increments.
- **`param_style`** — how the API is *asked*:
  - `window`: date-range parameters (`from`/`to`), driven by a watermark;
  - `threshold`: a monotonic key (`since_id`, sequence number);
  - `none`: unparameterized full pull.

The combinations cover every REST source encountered so far (`snapshot+none`,
`snapshot+window` for active-window APIs, `delta+window`, `delta+threshold`), and the base
layer stays append-only with dedup/versioning downstream — history is a property of the
lakehouse, not of the source API's memory.

## Consequences

- Onboarding a new REST entity is a YAML entry plus a data contract, not new code paths.
- The framework must resist featuritis: anything not expressible in the two axes goes to a
  custom job *with an ADR*, keeping the abstraction honest.
- Testing shifts from per-connector tests to axis-combination tests against the simulator,
  which deliberately emits late data, duplicates, and schema drift.
