# 0002. TaleScript follows GDScript conventions

- **Status:** Accepted
- **Date:** 2026-10-08

## Context

Writers need a text format for stories. Godot users already know GDScript, and the language should feel familiar while keeping dialogue light to type.

## Decision

- Stories are written in **TaleScript**, stored in `.tale` files, and organized into `beat` blocks.
- TaleScript reuses GDScript forms wherever possible: `#` comments, `##` doc comments, indentation with `:` headers, `var`, `const`, `:=`, type hints, `if`/`elif`/`else`, `match`, `await`, and `@annotations`.
- It adds only five things: dialogue and narration statements, `beat` blocks, `jump`, `choose:` blocks, and named arguments in action calls.
- Tales compile to an instruction list run by StoryTeller's own interpreter, rather than to GDScript.
- The parser keeps comments and formatting (a lossless syntax tree) so the visual editor can edit files without disturbing them.

## Alternatives considered

- **Compile to real GDScript:** rejected because running GDScript coroutines cannot be saved, which rules out mid-scene saves, rewind, and live reload.
- **Line-prefix command syntax** (as used by several existing engines): rejected because it is unfamiliar to Godot users and close to existing products.
- **JSON or resource files edited only in the inspector:** rejected because text is faster to write, review, and diff.

## Consequences

- Godot users can read tales immediately, and the "for GDScript users" documentation stays short.
- StoryTeller maintains its own lexer, parser, and interpreter.
