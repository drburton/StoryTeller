# 0019. Everything is open source; no Pro tier

- **Status:** Accepted
- **Date:** 2026-10-12

## Context

Decisions 0006, 0009, and 0014 planned a paid Pro add-on next to the free tier, deferred until the free tier worked. The project's focus has since moved to students: StoryTeller should be easy enough for a middle schooler (decision 0020). Schools and students are poorly served by a paid tier, and maintaining two products would slow the work that matters most.

## Decision

- There is no Pro tier. Every StoryTeller feature is open source under the MIT license (decision 0008).
- The features once planned for Pro become free features. The stage preview, "play from here", and starter templates come first, with Visual Novel StoryTeller Studio (decision 0020); the Story tab gets the same preview in a plugin 1.x release. The rest follow in 1.x releases.
- Support for the project comes through GitHub Sponsors.
- Decisions 0006, 0009, and 0014 are superseded. The extension points built for Pro (`docs/PLANNING.md` §12.3) stay, since community add-ons use them.

## Alternatives considered

- **Keep Pro, deferred (decision 0009):** keeps a revenue option open, but splits attention and fits poorly with classroom use.
- **Paid hosting or school licenses for the Studio:** the Studio runs as a static web page that costs nothing to host (decision 0020), so there is little to charge for without adding accounts and servers that schools would need to approve.

## Consequences

- No EULA, pricing, storefront, private repository, or license checks to plan.
- The plan's §12 becomes a schedule for the former Pro features, all free.
- The legal review (§2.8) no longer covers a Pro EULA. Contributions still use DCO sign-offs (`CONTRIBUTING.md`).
