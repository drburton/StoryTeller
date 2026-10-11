# 0010. Lossless, line-based syntax tree

- **Status:** Accepted
- **Date:** 2026-10-08

## Context

The visual editor (decision 0005) edits `.tale` files that writers and programmers also edit as text. Edits made visually must not reformat or lose anything else in the file. The parser also has to report every error in a file at once, since writers fix several problems per pass.

## Decision

- The parser builds a tree in which **every physical line belongs to exactly one node**. Blank lines and comment lines are nodes too.
- Each node records its line range and indentation. `TaleDocument.to_source()` rebuilds the file from the tree and returns the original text byte for byte. Tests check this for every fixture and for edge cases (CRLF, missing final newline, broken code, unicode).
- A line that cannot be parsed becomes an `ERROR` node and parsing continues. An error line ending in `:` still opens a block, which avoids a cascade of indentation errors.
- Inside brackets, continuation lines must be indented deeper than the opening line (unless they start with a closing bracket). This differs slightly from GDScript and lets the lexer stop at a missing `)` instead of swallowing the rest of the file.
- Expected parse trees for fixture tales are stored as `*.expected.txt` files ("golden" tests) and regenerated with `-- --update-golden`.

## Alternatives considered

- **Token-level concrete syntax tree with trivia on every token:** more general, but much more code. TaleScript is line-oriented, so line ranges are enough for statement-level editing.
- **Reformat the whole file on save:** simpler, but rewrites lines nobody touched and produces noisy diffs.
- **Stop at the first error:** simpler, but a poor experience for writers.

## Consequences

- The visual editor can replace one statement by replacing only that statement's lines.
- Edits finer than a statement (for example, changing one argument) are done by reprinting the whole statement.
- The bracket rule is documented in `docs/talescript-spec.md` §2.2 and §11.
