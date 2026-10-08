# 0009. Defer the Pro tier until the free tier works

- **Status:** Accepted
- **Date:** 2026-10-08

## Context

Decision 0006 set a free base tier and a paid Pro tier, with Pro features scheduled alongside milestones M4 and M5. Building both in parallel splits effort before the core is proven.

## Decision

- Work on the Pro tier starts only once the free tier is a working system.
- Features marked Pro in `docs/PLANNING.md` §7 are removed from the 1.0 schedule and listed as the "Pro phase".
- The private Pro repository, EULA, pricing, and storefront are deferred with it.
- The free tier is still designed with clean extension points so Pro can be added later without changing the core.

## Alternatives considered

- **Build Pro alongside the free tier (decision 0006's schedule):** rejected for now because it slows the path to a working system.

## Consequences

- The schedule to 1.0 shortens from about 30 weeks to about 28.
- Decision 0006 still describes the intended business model; this record changes only its timing.
