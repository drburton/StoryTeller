# TaleScript conformance suite

This suite defines how TaleScript behaves. It follows decision 0025 (docs/decisions/0025-talescript-cross-engine-language.md). Any implementation of TaleScript, such as the Godot plugin or a C# port for Unity, proves it behaves the same by running every case here and comparing its output with the expected file, character for character.

The Godot plugin is the reference implementation. The expected files are what it prints today. The language itself is described in docs/talescript-spec.md.

## The three kinds of case

Each kind has its own folder. A case is a `.tale` file plus the files that share its name.

| Folder | Files | What it tests |
|---|---|---|
| `parse/` | `<name>.tale`, `<name>.expected.txt` | The parse tree dump. Run by tests/unit/talescript/test_tale_golden.gd. |
| `check/` | `<name>.tale`, optional `<name>.context.json`, `<name>.expected.txt` | The problems the checker finds. |
| `run/` | `<name>.tale`, optional `<name>.run.json`, `<name>.expected.txt` | The transcript of playing the tale. |

The first line of most cases is a `##` comment that says what the case shows.

## Check cases

The checker is given the tale and a context that says what the game offers. The context file is JSON. All keys are optional.

| Key | Meaning |
|---|---|
| `tale_name` | Name of the tale. Defaults to the case name. |
| `actions` | Checked actions: `{name: {"params": [names], "required": n}}`. `required` is how many leading parameters must be given. |
| `actions_unchecked` | Action names that accept any arguments. |
| `cast` | Cast members: `{id: [moods]}` or `{id: {"moods": [...], "fields": [...]}}`. |
| `exposed` | Names that game code exposes to tales. |
| `tales` | Other tales: `{name: {"beats": [...], "vars": [...]}}`. |

The output has one problem per line. Parse problems come first, then checker problems, each in the order found:

- `<line>: <message>` for an error
- `<line>: warning: <message>` for a warning
- `<line>: parse: <message>` for a parse error
- `(no problems)` when there is nothing to report

## Run cases

The tale is compiled and played from the start beat. The only crew member is the director. Stage, audio, and effect actions and `ask_text` are not used. The run file is JSON. All keys are optional.

| Key | Meaning |
|---|---|
| `start` | Beat to start in. Default `start`. |
| `picks` | What the player chooses, one entry per choice, in order. An entry is the text of an option, the index of an option, or -1 to let a timed choice run out. When the list is used up, the first enabled option is taken. |

Lines are shown at once. The tale name is the case name.

### Transcript format

The transcript has one event per line:

- `line: <speaker>: <text>` for dialogue, or `line: <text>` for narration
- `choose: <option> | <option> | [<disabled option>]` for a choice, with ` (timed)` added for a timed choice. Disabled options are shown in square brackets. Options that are hidden are left out.
- `pick: <option text>` for the option taken, or `pick: (time runs out)`
- `signal: <name> <value as JSON>` for each `emit`
- `error: line <n>: <message>` for a runtime error
- `compile error: line <n>: <message>` for each error found when compiling. The tale is not played then.

When the story ends, one line `var: <name> = <value as JSON>` is added for each top-level var and const of the tale, sorted by name. The last line is always `end`.

Text in a `line:` event is the text after interpolation, as the presenter receives it. Multi-line text keeps its line breaks.

## Using the suite in an implementation

1. For each case, read the `.tale` file and the optional settings file.
2. Produce the output for the kind of case in the format above.
3. Compare it with the `.expected.txt` file. The comparison is exact, including the final newline.
4. Report any case that differs.

Runtime error messages and compile error messages are part of the expected output, so a port must use the same wording.

## Updating the expected files in the reference

The runner is tests/unit/conformance/test_conformance.gd. To run the suite:

    godot --headless --path . -s res://tests/run_tests.gd -- --filter=conformance

After an intended change to the language, rewrite the expected files:

    godot --headless --path . -s res://tests/run_tests.gd -- --filter=conformance --update-conformance

Then review the diff of every changed `.expected.txt` file. A change in an expected file is a change in the language, so check it against the spec before you commit it. When you add a case, write the `.tale` file and the settings, update the expected files, and read the new expected file by hand.
