# 0011. Localization with Godot's translation system

- **Status:** Accepted
- **Date:** 2026-10-08

## Context

M4 requires the demo to play in a second language. Stories need their lines, choice options, speaker names, and menus translated. Translators often work in spreadsheets or translation tools, and Godot projects already have a translation workflow for their own UI.

## Decision

- StoryTeller uses Godot's `TranslationServer` and its CSV or PO translation files. A game switches language the usual Godot way, and the Language setting does the same.
- Every dialogue line, narration line, and choice option is keyed as `<tale>:<line id>`. Line ids come from `@id("...")` when present, otherwise from the beat name and a hash of the text (as before).
- Speaker names, tale titles, and menu text are keyed by their source text, which is Godot's usual convention for UI strings.
- A translated line may use `{expr}` interpolation and text tags like the original. It is compiled when first shown and evaluated through the same sandbox as the original line. A translation that fails to compile is reported once and the original text is shown.
- An export tool writes one CSV with a `keys` column, the source language, one column per target language, and `_context` and `_status` columns for translators (Godot's importer ignores columns that start with `_`). Exporting again keeps existing translations, adds new keys, and marks keys that are no longer used, or whose source text changed, so no translation work is lost.
- Text that has already been translated (dialogue, options, history) is shown with Godot's automatic translation turned off, so a line that happens to match a menu key is not translated twice.

## Alternatives considered

- **Our own string table format:** full control, but a second system next to Godot's, and no support from existing translation tools.
- **Separate `.tale` files per language:** easy to read, but branching logic would be duplicated and drift between languages.
- **Keys made only from the source text:** simple, but two identical lines in different scenes could not be translated differently.

## Consequences

- Editing a line's text without `@id` changes its key. The export tool marks the old row as unused and keeps its translation for reference.
- Projects must register the generated translation files in **Project Settings > Localization**. The export tool in the Story tab does this automatically.
