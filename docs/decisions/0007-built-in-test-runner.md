# 0007. Built-in test runner instead of GUT

- **Status:** Accepted
- **Date:** 2026-10-08

## Context

The plan originally named GUT (Godot Unit Test) as the test framework. StoryTeller tracks the newest stable Godot release (decision 0003), and third-party addons sometimes take time to support a new Godot version.

## Decision

StoryTeller uses a small built-in runner (`tests/run_tests.gd`, `tests/framework/`):

- Discovers `tests/unit/**/test_*.gd` and runs every `test_*` method on a fresh instance, with `await` support.
- Provides basic assertions and automatic freeing of tracked nodes.
- Uses Godot's `Logger` API to fail any test that triggers a script error.
- Exits with code 1 on any failure, for CI.
- A separate test compiles every script in the addon and test folders.

## Alternatives considered

- **GUT:** feature-rich and well known, but adds a vendored dependency of several thousand lines and can lag behind new Godot releases.
- **gdUnit4:** similar trade-offs.

## Consequences

- No external dependency and no waiting on third-party updates when Godot releases.
- Fewer features (no mocking, no parameterized tests). These can be added when needed, or the project can switch to GUT later through a new decision record.
