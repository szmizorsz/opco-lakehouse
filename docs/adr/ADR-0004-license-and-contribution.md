# ADR-0004: License and contribution model

**Status:** accepted · **Date:** 2026-07-14

## Context

This is a public reference implementation whose value depends on being **adoptable and forkable**.
It is developed under Datapao (who owns the repository and the copyright), but its whole purpose —
as an accelerator, a marketing and thought-leadership asset, and a portable body of work for its
authors — requires that anyone, including future maintainers, can use, fork, and continue it
without asking. A repository that is "promised to be opened later" stays closed; only an actually
published open-source license guarantees continuation rights.

Contributors at Datapao commit from their **personal GitHub accounts**, so authorship lives in
commit metadata rather than a corporate identity.

## Decision

**Apache License 2.0, applied from the first commit, in a public repository.**

- **Apache-2.0** (not MIT/BSD) for the explicit **patent grant and termination** clauses — the
  right choice for a platform others will deploy in production.
- **Public and licensed from commit one** — not "open it when it's polished." This is the single
  term that makes the fork/continuation right real and irrevocable.
- **Copyright: Datapao**; recorded in `LICENSE` (appendix) and `NOTICE`.
- **Contributions** are accepted by pull request under inbound-equals-outbound (Apache-2.0 §5):
  submitting a PR licenses it under the same terms, no separate CLA. A **DCO `Signed-off-by`**
  line is encouraged on commits.
- **Commits come from personal GitHub accounts**, so attribution travels with the author.
- A **named maintainer** is recorded in the README.

## Consequences

- The project can be forked and continued by anyone, permanently — the property the whole strategy
  depends on.
- The fictional retail/OpCo scenario and generic patterns keep contributions clear of any client
  IP; "patterns, not artifacts" is the standing rule for what may be added.
- No CLA keeps the contribution barrier low; the DCO gives a lightweight provenance trail.

## Alternatives considered

- **MIT / BSD** — rejected: no explicit patent grant; weaker protection for a deployable platform.
- **Proprietary / internal-only** — rejected: kills adoption, marketing, and continuation rights;
  an internal accelerator is used twice and forgotten.
- **"Open it later"** — rejected: unpublished intentions are not licenses; only a published license
  guarantees the fork right.
- **Requiring a CLA** — deferred: unnecessary friction for a project using Apache-2.0
  inbound-equals-outbound; revisit only if a foundation or relicensing need ever arises.
