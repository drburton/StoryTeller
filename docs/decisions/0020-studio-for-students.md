# 0020. StoryTeller Studio: a block-based story builder for students

- **Status:** Accepted
- **Date:** 2026-10-12

## Context

StoryTeller should be easy enough for a middle school student to use. Today every story is built inside the Godot editor, either as TaleScript text or with the card editor in the Story tab. The Godot editor is crowded and confusing for a 12-year-old, the card editor looks like a form, and the target students work on iPads, which can't run the Godot editor at all.

## Decision

- Build **StoryTeller Studio**: a standalone story builder, made with Godot, that runs in a web browser on iPads (and on laptops). Students never see the Godot editor.
- Stories are built with **Scratch-style blocks** that snap together, next to a live stage preview and a Play button. Most middle schoolers know Scratch from elementary school.
- The Studio reads and writes the same `.tale` files as the plugin, editing them line by line through the card model (decision 0012). A student's story can move into Godot later.
- The Studio is hosted on GitHub Pages as a single-threaded web export, needs no accounts or servers, and keeps stories in the browser's storage, with sharing by `.zip` file.
- The Studio is milestone M8, before 1.0. It starts with a feasibility check on a real iPad. The full design is in `docs/studio-design.md`.

## Alternatives considered

- **A kid mode inside the Godot editor:** less new work, but students would still install and open Godot, which iPads can't run.
- **Friendlier cards:** less new work, but still a form with fields; blocks are more familiar to the age group.
- **Storyboard panels:** very visual, but branching and numbers are hard to show.
- **A native iPad app:** better access to Photos and storage, but needs the App Store, an Apple developer account, and school device management to install.

## Consequences

- The parser, checker, and editing layer must run in an exported game, without the Godot editor; editor-only code moves behind a small interface.
- The plugin's runtime must work in a web export with the Compatibility renderer, on touch screens. That is tested on an iPad first.
- Browser storage on iPads can be cleared after seven days without a visit, so the Studio asks students to add it to the Home Screen and reminds them to download copies.
- The M5 usability test with writers is extended into a classroom test with middle school students (M8, step S6).
- The 1.0 date moves out by about twelve weeks.
