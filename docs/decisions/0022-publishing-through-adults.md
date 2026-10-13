# 0022. Students share; adults publish in Godot

- **Status:** Accepted
- **Date:** 2026-10-12

## Context

Students using Visual Novel StoryTeller Studio will want others to play what they make. The Studio is an app for children aged 11 to 14 (decisions 0020 and 0021), so anything that puts their work in front of the public needs care: children's privacy rules (COPPA in the US, and the App Store's Kids category and Google Play's Families policy), what a story says, and whose names and photos are in it. The design listed "sharing a playable link" as a later idea (`docs/studio-design.md` §12) without deciding how.

## Decision

- **The Studio does not publish.** A student shares a story only as a story file: **Share** makes a `.zip` that goes where the student sends it, such as to a teacher or a parent. The Studio has no playable links, uploads, accounts, or servers.
- **Adults publish, in Godot.** A teacher or parent opens the story file in a Godot project with the StoryTeller plugin, plays it and reviews it there, and exports it as a game: a web build for itch.io or a class website, or a desktop or Android build. The adult decides whether and where it goes public, and posts it themselves.
- **The story file holds everything a build needs.** Besides the tale and its `story.json`, it carries the pictures and sounds the story uses (the starter library's and the student's own) and a story config, so the story plays in Godot without the Studio.
- **The plugin opens Studio stories.** A command in the plugin unpacks a story file into the project as its own story folder with its own `StoryConfig`, ready to play in the editor and to export.

## Alternatives considered

- **A playable link from the Studio:** the easiest for students, but it needs hosting and accounts, makes the project responsible for what is published, and brings children's privacy rules to the servers. Removed from the plan.
- **Exporting a web game inside the Studio:** no servers, but a student could post the game anywhere with no adult in between, and the Studio would need Godot's export templates on the tablet.
- **Story files only, with no way into Godot:** the story could be played only in the Studio, so it could never become a game anyone can download.

## Consequences

- Nothing leaves the device unless the student shares a file, which keeps the app's privacy details simple for both stores.
- The story file grows with the starter library (M8, S4): `pictures/`, `sounds/`, and a config beside the tale. Its format is documented, since teachers and the plugin depend on it.
- The plugin gains "Open a Studio story", with a test that a story file opens, plays, and exports. The plugin's web export must work, since that is how most student stories will be published; it is tested before Studio 1.0.
- Teachers need a short guide to publishing a student's story, which the textbook can point to.
- This replaces "Sharing a playable link instead of a file" in `docs/studio-design.md` §12.

## Update (2026-10-12)

Built in M8, S5. A story file holds `story.json`, `tales/<id>.tale`, and the story's pictures, sounds, and character profiles in their usual folders (`StoryFile`). It carries no story config: a Godot resource in a shared file could run code, so story files never hold one, and **Open a Studio story** writes the config and a `main.tscn` when it adds the story to a project. `tools/check_studio_story.sh` tests that a story file opens, plays, and exports for the web, and `docs/guides/publishing-studio-stories.md` is the teacher's guide.
