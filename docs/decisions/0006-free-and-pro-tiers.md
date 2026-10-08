# 0006. Free base tier and paid Pro tier

- **Status:** Accepted (feature split, pricing, and license still open)
- **Date:** 2026-10-08

## Context

The project needs a sustainable business model while staying attractive to the Godot community.

## Decision

- StoryTeller ships as a free base tier and a paid Pro tier.
- The free tier must be able to ship complete commercial games.
- Pro is a separate add-on (`addons/storyteller_pro/`) in its own private repository and uses only the free tier's public extension points.
- The free tier contains no license checks. Pro is governed by its EULA.
- Games built with either tier pay no royalties.

## Alternatives considered

- **Fully free with donations:** less predictable income.
- **Paid only:** limits adoption in a community used to free tools.
- **License keys or DRM in Pro:** weak protection for GDScript source and a burden on paying customers.

## Consequences

- Public extension points must be strong enough to build all Pro features, which also benefits community add-ons.
- Pricing, storefront, the exact feature split (`docs/PLANNING.md` §12.2), and the license (§13) remain to be decided.
