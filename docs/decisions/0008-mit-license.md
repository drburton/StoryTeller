# 0008. MIT license

- **Status:** Accepted
- **Date:** 2026-10-08

## Context

The free tier needs a license that the Godot community trusts, that works with commercial games, and that leaves room for a separate paid Pro add-on later. Options compared in `docs/PLANNING.md` §13: MIT, Apache 2.0, MPL 2.0, GPL/LGPL, and a custom source-available license.

## Decision

StoryTeller is released under the **MIT license**.

- The full text is in `LICENSE` at the repository root, with a copy in `addons/storyteller/LICENSE` because the addon folder is distributed on its own. A test keeps the two files identical.
- Contributions are accepted under the same license (inbound equals outbound).
- A future Pro add-on is a separate work and can use its own proprietary EULA.

## Alternatives considered

- **Apache 2.0:** adds a patent grant and a trademark clause, but is longer and less common in the Godot ecosystem.
- **MPL 2.0:** keeps changes to StoryTeller's files open, but is less familiar and adds obligations for users.
- **GPL / LGPL:** would discourage commercial games.
- **Source-available:** strongest protection, but not open source and less trusted.

## Consequences

- Matches Godot's own license, so users already understand the terms.
- Anyone may fork or resell the free tier; the project accepts this in exchange for wide adoption.
- The StoryTeller name is not protected by MIT; trademark questions are handled separately (`docs/PLANNING.md` §2.8).
