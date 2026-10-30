# 0025. TaleScript is a cross-engine language

- **Status:** Accepted
- **Date:** 2026-10-30

## Context

The maintainer is writing a textbook on visual novel creation for game development courses. This year every one of the maintainer's students chose Unity with Naninovel over Godot with StoryTeller, because they already knew Unity. For the book to be adopted, the tool has to exist in the engines schools teach (decision 0026). A book that covers one tool in three engines only works if a tale behaves the same way in all of them. Story craft and TaleScript chapters can then be written once, and only short engine labs differ.

The Godot plugin already has a large set of tests for the language: parse-tree golden files in `tests/fixtures/talescript`, checker messages, and compiler and director tests.

## Decision

- TaleScript is a language that belongs to no single engine. The Godot plugin is the reference implementation: when the engines disagree, the plugin's behavior is the answer until the language is changed on purpose.
- The existing tests become a language conformance suite. Inputs and expected outputs are data files (tales, parse trees, checker messages, compiled output, and director traces) that any engine's version can read. Every engine's version must pass the whole suite.
- The language has one version number, shared by all engines. A release of an engine names the language version it implements.
- A change to the language starts in the suite: the new cases are written first, then every engine is brought up to pass them.

## Alternatives considered

- **A separate language for each engine:** each could use its engine's habits, but the book could not cover them once, and tales could not move between engines.
- **One compiler that emits JSON, with thin runtimes only:** the least code to keep in step. It is rejected for Unity, because writers need errors while they type and the path explorer inside Unity, and those need the parser, checker, and director there. It stays the approach for Unreal 1.1, which plays compiled tales and checks them with the C# command-line tool.
- **A shared native core in C++ or Rust:** one implementation for every engine, but it would replace the working GDScript core, add a native build for each platform, and slow 1.0.

## Consequences

- Work on the suite comes first (milestone M10). The tests have to be split into engine-neutral data and the small parts that stay engine-specific.
- Each engine's CI runs the suite. Without that check, the engines would drift apart.
- Language changes cost more than before, since the suite and every engine change together. This is the price of tales and book chapters that stay true everywhere.
- A tale that works in one engine works in the others, apart from the engine's own assets and actions.
