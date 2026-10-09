# 0012. The visual editor edits the text, line by line

- **Status:** Accepted
- **Date:** 2026-10-08

## Context

Decision 0005 makes the `.tale` file the only saved format and asks the visual editor to change only the lines it touches. Decision 0010 gives every statement a line range. M5 had to choose how cards turn into text, how undo works across the text and card views, and where the Story Map keeps beat positions.

## Decision

- **Cards are views of statements.** `TaleCard` reads fields (speaker, mood, text, call arguments, option conditions) from the syntax tree. Statements with no card (loops, `match`, local variables, one-line `if x: jump y`, and anything with syntax errors) become script cards that show and edit the raw text.
- **Edits are line replacements.** `TaleEdit` rewrites, inserts, deletes, and moves whole statements by line range and keeps comments, annotations, CRLF line endings, and the file's indentation. A field change reprints only its own statement with `TaleExpr.to_source()`. Blocks emptied by a delete or move get `pass`, so the tale stays valid.
- **One undo history.** The Story tab applies each card edit to the text editor as a single undoable change covering only the lines that differ, so Ctrl+Z works the same in both views and the saved file diffs cleanly.
- **Action forms come from signatures.** Parameter names, types, and defaults are read from each action's `run()` method (and cast and camera methods). Required parameters are written positionally and optional ones as named arguments. Text fields show strings without quotes; a value starting with `=` is written as an expression.
- **The Story Map stores layout beside the tale.** Positions of beats moved on the map go in `<tale>.tale.map` (JSON), never in the tale itself.

## Alternatives considered

- **Regenerating the whole file from the tree:** simpler, but reformats lines nobody edited and loses formatting choices.
- **A separate undo stack for cards:** easier to build, but Ctrl+Z would behave differently in each view and could undo the wrong thing after switching views.
- **Storing map positions as comments in the tale:** keeps one file, but adds noise to the text writers read and to every diff.

## Consequences

- A field edit can change the spacing inside that one statement (for example `time=1` becomes `time = 1`), and an end-of-line comment is kept but its spacing is normalized.
- Script cards guarantee nothing is hidden, but loops and `match` need the text view or a script card to edit.
- `.tale.map` files should be committed with their tales if a team wants to share the map layout.
