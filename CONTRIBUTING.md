# Contributing to StoryTeller

Thank you for your interest in StoryTeller. This guide covers project setup, coding conventions, and the originality rules every contribution must follow.

> **Outside code contributions are not open yet** while the core is being built. Bug reports and feature ideas are welcome now through GitHub issues.

StoryTeller is released under the [MIT license](LICENSE). By submitting a contribution, you agree that it is licensed under the same terms.

## 1. Originality rules (required reading)

StoryTeller covers a feature scope similar to Naninovel for Unity. It must remain an independent work. Every contributor agrees to these rules:

1. **Do not read, copy, or translate Naninovel source code**, and do not consult it while working on StoryTeller. This also applies to the source of any other commercial visual novel engine.
2. **Use only public, feature-level information** for inspiration: what a feature does for the user. Design the implementation yourself.
3. **Do not reuse another product's vocabulary, command names, script syntax, file formats, documentation text, sample content, art, audio, or UI layouts.** Use the StoryTeller terms listed in `docs/PLANNING.md` §3.
4. **Do not use the Naninovel name or branding** in code, user-facing text, or marketing, and do not claim compatibility or affiliation.
5. **Record significant design decisions** in `docs/decisions/` with the reasoning behind them (see below).
6. **If you have previously worked with Naninovel's source code,** say so in your first pull request so maintainers can assign you work on unrelated areas.

When unsure whether something is acceptable, open an issue and ask before writing code.

## 2. Setup

1. Install **Godot 4.7.2** (the supported version; see `docs/decisions/0003-godot-version-policy.md`). The standard build is enough; the .NET build is not needed.
2. Clone the repository and open `project.godot` in Godot. The StoryTeller plugin is enabled in the project already.

## 3. Running tests

Tests run headless with a small built-in runner (`tests/run_tests.gd`).

**Windows (PowerShell):**

```powershell
.\tools\run_tests.ps1 -Godot D:\Godot              # folder containing Godot_v4.7.2-stable_win64_console.exe
.\tools\run_tests.ps1 -Godot D:\Godot -Filter crew # only tests whose name contains "crew"
```

You can also set `GODOT_BIN` once (`$env:GODOT_BIN = "D:\Godot"`) and run `.\tools\run_tests.ps1` with no arguments.

**Linux and macOS:**

```bash
GODOT_BIN=/path/to/godot tools/run_tests.sh
GODOT_BIN=/path/to/godot tools/run_tests.sh --filter=crew
```

Some tests check error handling on purpose, so `ERROR:` and `WARNING:` lines from StoryTeller appear in the output. The run only fails when a test assertion fails, a script crashes during a test (`SCRIPT ERROR`), or any script fails to compile.

### Writing tests

- Put test files in `tests/unit/`, named `test_<topic>.gd`.
- Start each file with `extends "res://tests/framework/story_test.gd"`.
- Every method named `test_*` runs on a fresh instance. Use `before_each()` and `after_each()` for shared setup.
- Assertions: `assert_true`, `assert_false`, `assert_eq`, `assert_ne`, `assert_null`, `assert_not_null`, `assert_has`, `fail`.
- Wrap nodes you create with `track(node)` so they are freed after the test.
- Put helper scripts and sample data in `tests/fixtures/`.
- **Golden tests:** each `tests/fixtures/talescript/*.tale` has a `*.expected.txt` with its parse tree. After an intended parser change, regenerate them with `.\tools\run_tests.ps1 -Godot D:\Godot -UpdateGolden` (Windows) or `tools/run_tests.sh --update-golden` (Linux and macOS), then review the diff before committing.

## 4. Code style

- Follow the official [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html).
- Indent with tabs (configured in `.editorconfig`).
- Use static typing everywhere (`var count := 0`, `func run(time: float) -> void`).
- Write `##` doc comments on every public class, method, signal, and exported property. These feed the built-in Godot help and the generated reference docs.
- Prefix private members with an underscore.
- Global class names in the addon start with `Story` or `Tale` to avoid collisions with user projects.
- Keep the addon self-contained: no files outside `addons/storyteller/` are required at runtime.
- Commit `.uid` files that Godot generates next to scripts.

## 5. Commits and pull requests

- Work on a branch and open a pull request against `main`.
- Write commit messages in the imperative mood ("Add rewind snapshots"), with a short summary line and an optional body explaining why.
- Every pull request must pass CI (Linux and Windows test jobs).
- Add or update tests for behavior changes.
- Fill in the pull request template, including the originality checklist.

## 6. Design decisions

Significant choices (new systems, language syntax, file formats, public APIs, dependencies) are recorded as short decision records in `docs/decisions/`. Copy `docs/decisions/0000-template.md`, give it the next number, and include it in the pull request that implements the decision.
