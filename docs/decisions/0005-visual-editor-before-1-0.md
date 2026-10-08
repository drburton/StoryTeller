# 0005. Visual editor ships before 1.0

- **Status:** Accepted
- **Date:** 2026-10-08

## Context

Many writers prefer not to type syntax. A visual editor that stays in sync with text files would set StoryTeller apart from other visual novel tools.

## Decision

- A card-based visual editor and the Story Map ship in milestone M5, before 1.0.
- The `.tale` text file remains the only saved format; the visual editor and the text editor are two views of it.
- The parser preserves comments and formatting from M1 onward so visual edits produce minimal text changes.
- The visual editor and Story Map are planned for the free tier (to be confirmed with decision 0006's tier split).

## Alternatives considered

- **Visual editor after 1.0:** rejected because it is a primary differentiator.
- **Separate visual file format:** rejected because two formats would drift apart and complicate version control.

## Consequences

- The parser design in M1 must support lossless round trips, which adds work early.
- The 1.0 schedule grows by about seven weeks.
