# 0003. Target the latest stable Godot release

- **Status:** Accepted
- **Date:** 2026-10-08

## Context

Supporting several Godot versions slows development and blocks newer engine features. The project owner prefers to stay current.

## Decision

- StoryTeller supports **Godot 4.7.2**, the latest stable release when this record was written.
- `project.godot` declares the `4.7` feature tag, and CI downloads 4.7.2 (`GODOT_VERSION` in `.github/workflows/ci.yml`).
- When a new stable minor version ships, StoryTeller moves to it in its next minor release, after that Godot version's first patch release.
- A non-blocking CI job tests the newest Godot beta when the repository variable `GODOT_BETA` is set (for example `4.8-beta1`).
- To change versions, update `GODOT_VERSION` in the workflow, the feature tag in `project.godot`, `CONTRIBUTING.md`, and this record's successor.

## Alternatives considered

- **Support every Godot 4.x version:** rejected because of the testing cost and the loss of newer APIs such as typed dictionaries and the `Logger` class.

## Consequences

- Users must use a current Godot version, which is normal for actively developed Godot projects.
- Newer engine APIs can be used without compatibility shims.
