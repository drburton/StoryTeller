# 0020. Visual Novel StoryTeller Studio: a block-based story builder for students

- **Status:** Accepted; hosting and storage replaced by 0021 (apps for iOS and Android)
- **Date:** 2026-10-12

## Context

StoryTeller should be easy enough for a middle school student to use. Today every story is built inside the Godot editor, either as TaleScript text or with the card editor in the Story tab. The Godot editor is crowded and confusing for a 12-year-old, the card editor looks like a form, and the target students work on iPads, which can't run the Godot editor at all.

## Decision

- StoryTeller becomes two products in this repository. **Visual Novel StoryTeller** is the Godot plugin for adults, finishing as 1.0 from the current 0.1.0 beta. **Visual Novel StoryTeller Studio** is for kids: a standalone product in the `studio/` folder with its own releases and version numbers.
- Build **Visual Novel StoryTeller Studio**: a standalone story builder, made with Godot, that runs in a web browser on iPads (and on laptops). Students never see the Godot editor.
- Stories are built with **Scratch-style blocks** that snap together, next to a live stage preview and a Play button. Most middle schoolers know Scratch from elementary school.
- The Studio reads and writes the same `.tale` files as the plugin, editing them line by line through the card model (decision 0012). A student's story can move into Godot later.
- The Studio is hosted on GitHub Pages as a single-threaded web export, needs no accounts or servers, and keeps stories in the browser's storage, with sharing by `.zip` file.
- The Studio is milestone M8, which runs alongside finishing the plugin's 1.0. It starts with a feasibility check on a real iPad. The full design is in `docs/studio-design.md`.
- The maintainer is writing a textbook for teachers to use with the Studio, so the Studio keeps a stable interface within each major version and keeps every major version online (`docs/studio-design.md` §13).

## Alternatives considered

- **A kid mode inside the Godot editor:** less new work, but students would still install and open Godot, which iPads can't run.
- **Friendlier cards:** less new work, but still a form with fields; blocks are more familiar to the age group.
- **Storyboard panels:** very visual, but branching and numbers are hard to show.
- **A native iPad app:** better access to Photos and storage, but needs the App Store, an Apple developer account, and school device management to install.
- **A separate repository for the Studio:** clearer product identity, but the Studio depends on the plugin's parser, checker, card model, and runtime, and building it will change them often. One repository keeps those changes together and tested together; `studio/` can move to its own repository later with its history.

## Consequences

- The parser, checker, and editing layer must run in an exported game, without the Godot editor; editor-only code moves behind a small interface.
- The plugin's runtime must work in a web export with the Compatibility renderer, on touch screens. That is tested on an iPad first.
- Browser storage on iPads can be cleared after seven days without a visit, so the Studio asks students to add it to the Home Screen and reminds them to download copies.
- The plugin keeps its usability test with adult writers (M5). The Studio has its own classroom test with middle school students (M8, step S6).
- The plugin's 1.0 does not wait for the Studio.
- The textbook needs an interface freeze before it is written, lesson projects in the repository, and screenshots made by a script.
