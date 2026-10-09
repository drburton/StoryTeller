# 0017. Importing Yarn Spinner scripts

- **Status:** Accepted
- **Date:** 2026-10-09

## Context

M6 adds Yarn Spinner import so writers can bring existing dialogue into StoryTeller. Yarn Spinner is an open-source dialogue format (MIT licensed), so reading it does not conflict with the originality rules (§2 of the plan). Its model is close to TaleScript's: nodes, lines with speakers, shortcut options, conditions, variables, and commands. Some parts have no direct match, such as custom commands, dynamic jumps, and line groups.

## Decision

- **A one-way conversion to TaleScript text,** not a runtime that plays `.yarn` files. The result is an ordinary tale that the checker, the card editor, the Story Map, translation export, and the route chart all understand, and that writers keep editing in StoryTeller.
- **Names.** Each node becomes a beat named in snake_case, with the node title kept as its `@heading` for the route chart when they differ. Speakers whose name matches a cast member id speak as that cast member; others become `const` names holding the speaker's name. `$variables` become story variables, declared from `<<declare>>` or, failing that, with a starting value of the type first assigned.
- **What converts.** Lines, shortcut options with conditions and nested bodies, `<<if>>` chains, `<<set>>`, `<<declare>>`, `<<jump>>`, `<<detour>>` (a beat call), `<<return>>`, `<<stop>>`, `<<wait>>`, `#line:` ids (as `@id`), Yarn's word operators, and `visited()`, `random()`, `random_range()`, and `dice()`.
- **Nothing is dropped silently.** Commands without an equivalent stay in the tale as `# Yarn:` comments, and every such case is returned as a note with its Yarn line number.
- **Where it runs.** `YarnConverter` does the work; **Import Yarn** in the Story tab and `import_yarn.gd` on the command line write the tale into the tales folder. An existing tale is never overwritten.

## Alternatives considered

- **Playing `.yarn` files directly:** two languages to support at runtime, and Yarn content would not get the visual editor, the checker, or translation export.
- **Mapping custom commands to actions by name:** guesses would often be wrong; a comment the writer replaces is clearer.

## Consequences

- Imported tales may need small fixes where notes point, such as custom commands and `visited_count()`.
- Yarn's own localization files are not imported; translations are exported again from the new tale.
