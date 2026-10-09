# TaleScript Language Specification

Version: **draft 0.4** (milestone M6)

TaleScript is the language StoryTeller stories are written in. It follows GDScript's syntax wherever GDScript has a way to express something, and adds a few statements for writing stories. This document is the reference for the parser, the checker, the editor tools, and writers who want precise rules.

Implementation status:

| Part | Status |
|---|---|
| Lexical rules, statements, expressions (§2 to §6) | Implemented (`TaleLexer`, `TaleParser`) |
| Checks listed in §9 | Implemented (`TaleChecker`) |
| Runtime meaning of statements (§5) | Implemented (`TaleCompiler`, `TaleDirector`) |
| Interpolation (§7.2) and `[pause]` tags (§7.1) | Implemented |
| `[speed]`, `[instant]`, `[sound]`, `[act]` tags (§7.1) | Implemented (M6) |
| CGs (`cg`, `hide_cg`), cast renames (`display_name`), cast animations and drawing order, cast fields (§13.1, §13.2, §13.4) | Implemented (M6) |
| `@heading` for the route chart (§8) | Implemented (M6) |
| Cast members, moods, stage positions, camera, built-in actions (§13) | Implemented (M2) |
| `@no_rewind`, `@skip_safe` (§8), player input and dialogue style actions (§13.1) | Implemented (M3) |
| Translation (§7.3), effect, collection, and movie actions (§13.1) | Implemented (M4) |
| Syntax tree guarantees used by the visual editor (§12) | Implemented (M5) |

---

## 1. Files

- A tale is a UTF-8 text file with the extension `.tale`.
- A tale's name is its file name without the extension (`prologue.tale` is the tale `prologue`). Other tales refer to it by that name, as in `jump prologue.start`.
- Line endings may be `\n` or `\r\n`. Tools must preserve whichever the file uses.

---

## 2. Lexical structure

### 2.1 Lines and indentation

- A statement normally occupies one line.
- Blocks are formed by indentation, exactly as in GDScript. A block header ends with `:` and the following lines are indented deeper than the header.
- Indentation may use tabs or spaces, but one file must use only one of them. A line mixing both is an error.
- A dedent must return to the indentation of an enclosing block.
- Blank lines and comment-only lines are ignored for indentation.

### 2.2 Line joining

A logical line continues onto the next physical line when:

1. the line break is inside `( )`, `[ ]`, or `{ }`;
2. the line ends with a backslash `\`; or
3. the line break is inside a triple-quoted string.

**Bracket rule (differs from GDScript):** inside brackets, each continuation line must be indented deeper than the line where the bracket opened, unless it starts with a closing bracket. A line that breaks this rule ends the bracket early with the error "'(' is never closed", so one missing bracket cannot hide the rest of the file.

```gdscript
show(
	"mira",
	fade = 0.5,
)    # fine: starts with the closing bracket
```

### 2.3 Comments

- `#` starts a comment that runs to the end of the line.
- `##` starts a doc comment. At the top of a file it describes the tale; before a beat it describes the beat. Tools show doc comments in the Story Map.

### 2.4 Identifiers

Identifiers start with a letter, `_`, or any non-ASCII character, followed by letters, digits, `_`, or non-ASCII characters. They are case-sensitive.

### 2.5 Keywords

```
and  await  beat  break  choose  const  continue  elif  else  false  for
if  in  jump  match  not  null  or  pass  return  true  var  when  while
```

Keywords cannot be used as names. `timeout` is an ordinary identifier with a special meaning only inside `choose:` blocks.

### 2.6 Literals

| Literal | Examples |
|---|---|
| Integer | `42`, `1_000`, `0xFF`, `0b1010` |
| Float | `2.5`, `.5`, `1e3`, `1.5e-2` |
| String | `"text"`, `'text'`, `"""multi-line"""`, `'''multi-line'''` |
| Boolean | `true`, `false` |
| Null | `null` |
| Array | `[1, 2, 3]` |
| Dictionary | `{"a": 1, b = 2}` (both GDScript forms) |

String escapes: `\n`, `\t`, `\r`, `\\`, `\"`, `\'`, `\uXXXX`, `\UXXXXXX`. A backslash before a line break inside a string joins the lines. Any other escape is an error.

### 2.7 Operators and punctuation

```
+  -  *  /  %  **  ~  &  |  ^  <<  >>
<  >  <=  >=  ==  !=  and  or  not  &&  ||  !  in  not in
=  +=  -=  *=  /=  %=  **=  &=  |=  ^=  <<=  >>=  :=
(  )  [  ]  {  }  ,  :  .  @
```

`;` is not used. Each statement goes on its own line.

### 2.8 Annotations

`@name` or `@name(arguments)`. Annotations come before the statement they apply to, either on the same line (`@global var seen := false`) or on their own line above it (`@id("intro_04")`).

---

## 3. File structure

The top level of a tale may contain only:

- annotations that apply to the whole tale, such as `@title("Prologue")`;
- `var` and `const` declarations;
- `beat` blocks;
- comments and blank lines.

Story content (dialogue, narration, actions) must be inside a beat.

```gdscript
## The first morning at school.
@title("Prologue")

const HERO := "Alex"
var trust := 0
@global var prologue_done := false

beat start:
	"Sunlight spills across rows of empty desks."
```

---

## 4. Variables and constants

```gdscript
var trust := 0                 # type inferred from the value
var gold: int = 10             # explicit type
var flags: Array[String] = []  # typed array
var unset                      # starts as null
const MAX_TRIES := 3
```

| Where declared | Scope | Saved |
|---|---|---|
| Top level of a tale | **Story variable**, visible to the whole tale and to other tales as `tale_name.variable` | In each save slot |
| Top level with `@global` | **Global variable**, shared across all playthroughs | In the global save file |
| Inside a beat | **Temporary**, visible until the end of the beat | Yes, while the beat runs |

Constants must have a value and cannot be assigned.

---

## 5. Statements

### 5.1 Beats

```gdscript
beat name:
	statements
```

A beat is a named section of a tale. Beats cannot be nested and take no parameters. A beat ends when its last statement runs or at `return`.

- `jump` replaces the current beat with another one.
- A beat call (`name()`) runs another beat and then continues after the call.
- When a beat ends, the story continues after the most recent beat call. If there is none, the story ends.

### 5.2 Narration and dialogue

```gdscript
"The door creaks open."                  # narration
mira: "Who's there?"                     # dialogue
mira (scared): "Who's there?"            # dialogue with a mood change
mira ("face=pale, outfit=coat"): "Hm."   # quoted mood for layered looks
jonas: """It was a long night.
Longer than I'd like to admit."""        # multi-line text
```

- The speaker is a cast member id or a `const` holding a display name.
- The text must be a single string literal. Values are inserted with `{...}` (§7).
- The mood in parentheses changes the speaker's mood before the line is shown.

### 5.3 Jumps and beat calls

```gdscript
jump honest             # beat in this tale
jump chapter_1.start    # beat in another tale
side_quest()            # call a beat in this tale, then come back
chapter_1.flashback()   # call a beat in another tale
```

A call looks like a function call with no arguments. Whether `name()` calls a beat or an action is decided by the checker: beats in the current tale take priority, then actions.

### 5.4 Actions and expressions as statements

```gdscript
backdrop("classroom", transition = "fade", time = 1.0)
mira.enter("smile", at = LEFT)
await mira.move_to(CENTER, time = 0.6)
```

An action starts its effect and returns immediately. `await` waits for it to finish. Before showing any dialogue or narration, the director waits for running stage effects to finish (configurable).

### 5.5 Assignment

```gdscript
trust += 1
mira.mood = "angry"
inventory["key"] = true
```

Operators: `=`, `+=`, `-=`, `*=`, `/=`, `%=`, `**=`, `&=`, `|=`, `^=`, `<<=`, `>>=`. The target must be a name, an attribute, or an index.

### 5.6 Conditionals

```gdscript
if trust > 2:
	mira: "Thanks."
elif trust == 0:
	mira: "Hmm."
else:
	pass

if done: jump ending    # single-line form
```

### 5.7 Match

```gdscript
match route:
	"good":
		jump good_end
	"bad", "worse":
		jump bad_end
	_ when trust > 5:
		jump secret_end
	_: jump normal_end
```

Patterns are literals, constants, or `_` (anything). Several patterns separated by commas match any of them. `when` adds a guard condition. Binding patterns (`var x`) and array or dictionary patterns are reserved for a later version.

### 5.8 Loops

```gdscript
while gold < 10:
	gold += 1
for item in inventory_items:
	"You have {item}."
```

`break` and `continue` work as in GDScript. Loops stop with an error after a configurable number of iterations (default 10,000) to prevent runaway scripts.

### 5.9 Choices

```gdscript
choose:
	"Open the door":
		jump hallway
	"Knock first" if not knocked:
		knocked = true
	@once "Ask about the key":
		mira: "I lost it last week."
	"Leave" if has_item("map"): jump exit
```

```gdscript
choose(style = "hotspots", timeout = 5.0):
	"Left door": jump left
	"Right door": jump right
	timeout:
		"You hesitate too long."
```

- Each option is a string, an optional `if` condition, `:`, and a body.
- Options whose condition is false are hidden, unless `@show_disabled` is used.
- `timeout:` runs when the `timeout` argument expires.
- `choose` arguments: `style` (menu style name), `timeout` (seconds), and style-specific options.

### 5.10 Other statements

| Statement | Meaning |
|---|---|
| `return` | Leave the current beat early. In a called beat, continue after the call. |
| `pass` | Do nothing; used for empty blocks. |
| `break`, `continue` | Loop control. |

---

## 6. Expressions

### 6.1 Precedence

From lowest to highest, matching GDScript:

| Level | Operators | Associativity |
|---|---|---|
| 1 | `a if condition else b` | right |
| 2 | `or`, `\|\|` | left |
| 3 | `and`, `&&` | left |
| 4 | `not`, `!` (prefix) | |
| 5 | `in`, `not in` | left |
| 6 | `<`, `>`, `<=`, `>=`, `==`, `!=` | left |
| 7 | `\|` | left |
| 8 | `^` | left |
| 9 | `&` | left |
| 10 | `<<`, `>>` | left |
| 11 | `+`, `-` | left |
| 12 | `*`, `/`, `%` | left |
| 13 | `-`, `+` (prefix) | |
| 14 | `~` (prefix) | |
| 15 | `**` | left (as in GDScript) |
| 16 | `await` (prefix) | |
| 17 | calls `f()`, attributes `a.b`, indexing `a[i]` | left |

`&&`, `||`, and `!` are accepted as spellings of `and`, `or`, and `not`.

### 6.2 Calls and named arguments

```gdscript
backdrop("forest", transition = "fade", time = 1.5)
```

- Positional arguments come first, named arguments after.
- A named argument may appear only once.
- Named arguments are a TaleScript addition; GDScript does not have them.

### 6.3 Names available in expressions

- Story, global, and temporary variables, and constants.
- Cast members by id (`mira`), with the methods and properties listed in §13.
- `camera`, with the methods and properties listed in §13.
- Stage positions: `LEFT`, `CENTER`, `RIGHT` (`Vector2(0.25, 0)`, `Vector2(0.5, 0)`, `Vector2(0.75, 0)`), or any `Vector2`. The x value runs from 0 (left edge) to 1 (right edge); the y value lifts a character's feet above the bottom of the screen, as a fraction of the screen height.
- Constants of value types, such as `Color.RED`, `Color.TRANSPARENT`, `Vector2.ZERO`, and `Vector2.LEFT`.
- Built-in functions: `randi_range`, `randf`, `min`, `max`, `clamp`, `round`, `len`, `str`, `visited("tale.beat")`, `collected("id")`, `tr("key")`.
- Objects and functions that game code exposes with `Story.expose()`. Nothing else in the engine is reachable. List their names in `StoryConfig.exposed_names` so tales that use them import without errors and the Story editor suggests them.

---

## 7. Text

### 7.1 Markup

Dialogue and narration strings use Godot BBCode (`[b]`, `[i]`, `[color=red]`, `[wave]`, and so on). StoryTeller adds:

| Tag | Effect |
|---|---|
| `[pause]` | Wait for the player, then keep typing on the same line. |
| `[pause=0.5]` | Wait half a second. |
| `[speed=2.0]...[/speed]` | Type the enclosed text at a multiple of the player's text speed: `2.0` is twice as fast, `0.5` half as fast. Spans can nest; their speeds multiply. |
| `[instant]...[/instant]` | Show the enclosed text at once, without typing. |
| `[sound=bell]` | Play a sound when typing reaches this point. Same as `[act=sound("bell")]`. |
| `[act=shake(0.2)]` | Evaluate an expression, usually an action, when typing reaches this point. |

Details:

- `[speed]` and `[instant]` without a closing tag last to the end of the line. A closing tag without an opening one is an error.
- `[act=...]` takes any expression, checked like `{expression}`. Typing continues while the action runs, unless the expression awaits: `[act=await wait(1)]` holds the typing for a second. As with actions on their own lines, the next line waits for actions that are still running.
- `[sound=...]` takes a name, optionally quoted. To choose a sound with an expression, write `[act=sound(name)]`.
- When the player clicks while a line types, the text shows at once up to the next `[pause]`, and the `[act]` and `[sound]` tags on the way still run. While skipping, timed pauses are skipped and sounds are silent; actions still run and finish at once.
- Values may come from `{expression}`, for example `[pause={delay}]`; such values are checked while the story plays.
- Choice options leave out `[act]` and `[sound]` tags.
- The history and save slots show the text without these tags.

**Named text styles.** `StoryConfig.text_styles` maps names to BBCode, and `[name]...[/name]` in a line expands to that BBCode and its closing tags before the line is shown (and in the history). The defaults are `[whisper]` (gray italic), `[shout]` (large bold), and `[thought]` (pale blue italic); projects change them or add their own. Names that are not in `text_styles` are left as written. Translations use the same styles.

### 7.2 Interpolation

`{expression}` inserts a value: `"You have {gold} gold."`. Write `{{` and `}}` for literal braces.

### 7.3 Translation

Lines, narration, and choice options are translated through Godot's translation system (decision 0011). Each one is keyed `<tale>:<id>`, where the id comes from `@id("...")` or, without it, from the beat name and a hash of the text. Changing the text of a line without `@id` therefore gives it a new key.

A translation may use `{expression}` and the markup in §7.1, just like the original. While the game's language is `StoryConfig.source_language`, lines are shown as written in the tale.

Speaker names, tale titles, beat headings, and text passed through `tr("...")` are keyed by their text:

```gdscript
player_name = await ask_text(tr("What's your name?"), tr("Sam"))
```

**Export Strings** in the Story tab (or `addons/storyteller/editor/export_strings.gd` from the command line) writes every key to `StoryConfig.translation_file`, a CSV that translators fill in and Godot imports. Exporting again keeps existing translations and marks rows whose key is no longer used, or whose source text changed, in the `_status` column.

---

## 8. Annotations

| Annotation | Applies to | Meaning |
|---|---|---|
| `@title("...")` | Tale (top level) | Display name for save slots and the Story Map. |
| `@global` | `var` at top level | Variable shared across playthroughs. |
| `@once` | Choice option | Option disappears after it is chosen once in a playthrough. |
| `@show_disabled` | Choice option | Show the option greyed out when its condition is false. |
| `@id("...")` | Dialogue, narration, or choice option | Pins the id used for translation (§7.3), read tracking, and `@once`. |
| `@voice("...")` | Dialogue or narration | Assigns a voice clip. |
| `@no_rewind` | Any statement | The player cannot rewind past this point. |
| `@skip_safe` | Beat | Treat the beat's lines as already read, so skip passes them even when the player only skips read lines. Useful for recaps. |
| `@heading("...")` | Beat | Name shown for the beat in the players' route chart. Translated like tale titles, keyed by its text. Without it, the chart shows the beat's name. |

---

## 9. Checks

The checker runs after parsing and reports, with file and line:

- unknown actions, beats, tales, variables, cast members, and moods;
- wrong argument names, counts, or types for actions;
- `elif` or `else` without a preceding `if`;
- `break` or `continue` outside a loop;
- assignment to a constant;
- annotations used in the wrong place;
- unreachable statements after `jump` or `return`;
- expression statements that have no effect (warning);
- duplicate `@id` values, unknown annotations, and annotations on the wrong kind of line;
- `choose` blocks without options, extra `timeout:` branches, and unreachable `match` branches.

### 9.1 Runtime errors

Mistakes that can only be found while playing (adding text to a number, an index outside a list, calling a method that game code did not expose) do not crash the game. The director reports them through its `runtime_error` signal and the Output panel, with tale and line, and continues with the next line. A loop that runs 100,000 steps without showing a line or choice is stopped the same way.

---

## 10. Grammar

Notation: `|` alternatives, `[ ]` optional, `{ }` zero or more, quoted text is literal. `NEWLINE`, `INDENT`, and `DEDENT` come from the line and indentation rules in §2.

```ebnf
tale            = { top_item } ;
top_item        = annotation_line | var_decl | const_decl | beat ;
annotation_line = annotation { annotation } NEWLINE ;
annotation      = "@" IDENT [ "(" [ arguments ] ")" ] ;

var_decl        = { annotation } "var" IDENT [ ":" type ] [ ( "=" | ":=" ) expression ] NEWLINE ;
const_decl      = { annotation } "const" IDENT [ ":" type ] ( "=" | ":=" ) expression NEWLINE ;
type            = IDENT [ "[" IDENT "]" ] ;

beat            = { annotation } "beat" IDENT ":" block ;
block           = simple_statement | NEWLINE INDENT statement { statement } DEDENT ;

statement       = annotation_line | { annotation } ( simple_statement | compound_statement ) ;
simple_statement = ( narration | dialogue | jump | assignment | expression
                   | var_decl_body | const_decl_body | "return" [ expression ]
                   | "pass" | "break" | "continue" ) NEWLINE ;
narration       = STRING ;
dialogue        = IDENT [ "(" ( IDENT | STRING ) ")" ] ":" STRING ;
jump            = "jump" IDENT [ "." IDENT ] ;
assignment      = target assign_op expression ;
target          = IDENT | postfix "." IDENT | postfix "[" expression "]" ;
assign_op       = "=" | "+=" | "-=" | "*=" | "/=" | "%=" | "**="
                | "&=" | "|=" | "^=" | "<<=" | ">>=" ;

compound_statement = if_chain | while_loop | for_loop | match_block | choose_block ;
if_chain        = "if" expression ":" block { "elif" expression ":" block } [ "else" ":" block ] ;
while_loop      = "while" expression ":" block ;
for_loop        = "for" IDENT [ ":" type ] "in" expression ":" block ;
match_block     = "match" expression ":" NEWLINE INDENT branch { branch } DEDENT ;
branch          = pattern { "," pattern } [ "when" expression ] ":" block ;
pattern         = expression ;
choose_block    = "choose" [ "(" [ arguments ] ")" ] ":" NEWLINE INDENT option { option } DEDENT ;
option          = { annotation } ( STRING [ "if" expression ] | "timeout" ) ":" block ;

expression      = ternary ;
ternary         = binary [ "if" binary "else" ternary ] ;
binary          = unary { binary_op unary } ;           (* precedence per §6.1 *)
unary           = ( "-" | "+" | "~" | "not" | "!" | "await" ) unary | postfix ;
postfix         = primary { "(" [ arguments ] ")" | "." IDENT | "[" expression "]" } ;
primary         = INT | FLOAT | STRING | "true" | "false" | "null" | IDENT
                | "(" expression ")" | array | dictionary ;
array           = "[" [ expression { "," expression } [ "," ] ] "]" ;
dictionary      = "{" [ entry { "," entry } [ "," ] ] "}" ;
entry           = expression ":" expression | IDENT "=" expression ;
arguments       = argument { "," argument } [ "," ] ;
argument        = expression | IDENT "=" expression ;
```

---

## 11. Differences from GDScript

TaleScript is GDScript plus the following. Anything not listed here behaves as in GDScript.

**Additions**

1. Narration statements: a string literal on its own line.
2. Dialogue statements: `speaker: "text"` and `speaker (mood): "text"`.
3. `beat` blocks instead of `func`, without parameters or return values.
4. `jump` for one-way transfer between beats.
5. `choose:` blocks with string options and `timeout:`.
6. Named arguments in calls: `f(x, time = 1.0)`.
7. Story annotations: `@title`, `@global`, `@once`, `@show_disabled`, `@id`, `@voice`, `@no_rewind`, `@skip_safe`, `@heading`.

**Restrictions**

1. Top level holds only annotations, `var`, `const`, and `beat`.
2. No `func`, `class`, `class_name`, `extends`, `signal`, `enum`, `static`, `@tool`, `@export`, or `@onready`.
3. No `$Node` or `%Node` paths, `preload`, `load`, `is`, or `as`.
4. No lambdas.
5. `match` supports literal, constant, and `_` patterns with `when` guards; binding, array, and dictionary patterns are not supported yet.
6. Only objects exposed by game code are reachable.
7. Continuation lines inside brackets must be indented deeper than the opening line (§2.2).
8. Loops have an iteration limit.

---

## 12. Syntax tree guarantees (for tools)

The visual editor in the Story tab relies on these guarantees to edit one statement at a time (decision 0012).

The parser (`TaleParser.parse()`) returns a `TaleDocument` whose tree satisfies:

1. **Complete coverage.** Every physical line of the source belongs to exactly one node. Blank lines are `BLANK` nodes and comment-only lines are `COMMENT` nodes.
2. **Lossless printing.** `TaleDocument.to_source()` rebuilds the source from the tree and returns exactly the original text, including line endings, indentation, comments, trailing spaces, and the presence or absence of a final newline.
3. **Error tolerance.** A line that cannot be parsed becomes an `ERROR` node with a message, and parsing continues. Error lines ending in `:` still open a block, so their bodies don't cause further errors.
4. **Comment placement.** Blank and comment lines belong to the block of the next statement, except comments indented deeper than that statement, which stay in the block that just ended.
5. **Inline bodies.** In `if done: jump end`, the `jump` node is marked `inline` and shares the header's line.

These guarantees let the visual editor change one statement by replacing only that statement's lines.

---

## 13. Built-in actions and stage objects

Actions are called like functions. Named arguments may be given in any order after the positional ones. Every action starts at once; put `await` in front to wait for it to finish. Lines and choices wait for running actions before they appear.

### 13.1 Actions

| Action | Arguments (defaults) | Effect |
|---|---|---|
| `wait` | `seconds` | Pause. |
| `emit` | `signal_name`, `value = null` | Tell game code something happened (`TaleDirector.story_signal`). |
| `backdrop` | `name`, `transition = "fade"`, `time = 1.0`, `mask = ""` | Show a backdrop image, or a `Color`. `Color.TRANSPARENT` removes it. |
| `prop` | `name`, `at = Vector2(0.5, 0.5)`, `time = 0.3` | Show an image or scene, centered at a stage position. |
| `hide_prop` | `name`, `time = 0.3` | Remove a prop. |
| `clear_props` | `time = 0.3` | Remove all props. |
| `cg` | `name`, `variant = ""`, `transition = "fade"`, `time = 1.0` | Show a CG, a full-screen event picture, over the stage. A CG folder holds one image per variant; `variant` picks one (`""` shows `default`, or the first). Showing another CG or variant blends from the one on screen. Unlocks the CG's gallery entry. |
| `hide_cg` | `transition = "fade"`, `time = 1.0` | Remove the CG and show the stage again. |
| `shake` | `strength = 0.5`, `time = 0.4` | Shake the stage. |
| `music` | `track`, `volume = 1.0`, `fade = 1.0`, `loop = true` | Play music, crossfading from the current track. |
| `stop_music` | `fade = 1.0` | Fade out the music. |
| `sound` | `name`, `volume = 1.0` | Play a sound effect. |
| `ambience` | `name`, `volume = 1.0`, `fade = 1.0` | Play a looping background sound. |
| `stop_ambience` | `fade = 1.0` | Fade out the ambience. |
| `voice` | `clip` | Play a voice clip. Lines marked `@voice("clip")` do this automatically. |
| `stop_audio` | `fade = 0.5` | Stop music, ambience, sounds, and voice. |
| `ask_text` | `prompt`, `default = ""`, `max_length = 24` | Ask the player to type text. Use `await` to get it: `player_name = await ask_text("Your name?", "Sam")`. An empty answer gives `default`. |
| `ask_number` | `prompt`, `default = 0`, `min = 0`, `max = 100` | Ask for a whole number, kept between `min` and `max`. Use with `await`. |
| `dialogue_style` | `name` | Switch dialogue styles: `"classic"` (a box along the bottom) or `"page"` (lines collect on a full page). Games can add more in `StoryConfig.dialogue_styles`. |
| `clear_page` | | Start a new page in the `"page"` style. |
| `hide_dialogue` | | Hide the dialogue box until the next line, for example while the scene changes. |
| `weather` | `kind`, `strength = 1.0`, `fade = 1.0` | Start `"rain"` or `"snow"` over the stage, or stop it with `"none"`. |
| `filter` | `name`, `strength = 1.0`, `time = 0.5` | Recolor the stage: `"grayscale"`, `"sepia"`, `"night"`, `"warm"`, `"cold"`, or `"none"`. The dialogue box and menus keep their colors. |
| `flash` | `color = Color.WHITE`, `time = 0.3` | Flash the whole screen. |
| `fade_out` | `color = Color.BLACK`, `time = 0.5` | Fade the whole screen, dialogue box included, to a color. |
| `fade_in` | `time = 0.5` | Fade the screen back in. |
| `exit_all` | `time = 0.4` | Every cast member on stage exits. |
| `autosave` | | Save to the autosave slot. |
| `collect` | `id`, `notify = true` | Unlock a gallery picture, music track, or codex entry (a `CollectionItem` in `res://story/collection/`). `collected("id")` reads it. Unlocks are kept across playthroughs. |
| `play_movie` | `name`, `skippable = true` | Play an Ogg Theora (`.ogv`) movie from `res://story/movies/` over everything but the menus. A click or the continue key skips it. Use with `await`. |

Transitions for `backdrop`, `cg`, and `hide_cg`: `none`, `fade`, `dissolve`, `wipe_left`, `wipe_right`, `wipe_up`, `wipe_down`, `slide_left`, `slide_right`, `slide_up`, `slide_down`. With `dissolve`, `mask` names a grayscale image in `res://story/transitions/` that sets the order in which pixels change (dark first).

### 13.2 Cast members

| Member | Description |
|---|---|
| `enter(mood = "", at = Vector2(0.5, 0), time = 0.4, transition = "fade")` | Show the character. Transitions: `fade`, `slide_left` (enters from the left edge), `slide_right`, `none`. |
| `exit(time = 0.4, transition = "fade")` | Hide the character. |
| `move_to(at, time = 0.5)` | Move to a stage position. |
| `scale_to(factor, time = 0.3)` | Resize relative to the profile's size. |
| `hop(height = 0.04, time = 0.35)` | Jump up and land. `height` is a fraction of the screen height. |
| `shake(strength = 0.5, time = 0.4)` | Shake from side to side, fading out. At strength 1 the character moves about 3% of the screen width each way. |
| `nod(time = 0.5)` | Dip and come back up twice. |
| `animate(name)` | Play a named animation of a scene-based look: the scene's `play_animation(name)` method, or the animation in its `AnimationPlayer`. Returns when it ends (at once for looping animations); the character then shows their mood again. Other looks report an error. |
| `to_front()`, `to_back()` | Draw the character in front of, or behind, the other cast members. |
| `mood` | Current mood; assign to change it. `speaker (mood): "..."` also changes it. |
| `tint` | `Color` multiplied over the character. |
| `flip` | `true` mirrors the character. |
| `on_stage` | `true` between `enter()` and `exit()` (read it; don't assign). |
| fields | Data the character keeps, declared with starting values in the cast profile's `fields` (for example `{"affection": 0}`). Read and change them like properties: `ada.affection += 1`, `if ada.affection > 2:`, `"{ada.affection}"`. Saved with the story and started over in a new game. The checker reports names that are not a member or field of that cast member. |
| `draw_order` | Whole number; higher numbers draw in front. Characters with the same number draw in the order they were first used. Saved with the stage. |
| `display_name` | Name shown in the dialogue box, the profile's name until a tale assigns another: `mira.display_name = "???"` before she introduces herself, or `mira.display_name = player_name`. Assign `""` to go back to the profile's name. Read it in text as `{mira.display_name}`. The name is saved, and translated by its text like profile names; Export Strings includes names assigned as text. |

`hop`, `shake`, and `nod` move only the character's picture, so they combine with `move_to`, and they finish at once while the player skips.

Speakers who are not talking are dimmed while a cast member speaks. This can be turned off with `StoryConfig.highlight_speaker`.

### 13.3 Camera

| Member | Description |
|---|---|
| `zoom(amount = 1.0, time = 0.5)` | Zoom toward the screen center. |
| `pan(to = Vector2.ZERO, time = 0.5)` | Move the view by a fraction of the screen. |
| `rotate(degrees = 0.0, time = 0.5)` | Tilt the view. |
| `shake(strength = 0.5, time = 0.4)` | Shake the view. |
| `reset(time = 0.5)` | Return to normal. |
| `zoom_level`, `offset`, `angle` | Current values; assign to change them at once. |

The camera moves backdrops, cast, and props together. The dialogue box and menus stay in place.

### 13.4 Asset folders

Assets are found by name, without extension, in the folders set in `StoryConfig`:

| Kind | Default folder | Formats |
|---|---|---|
| Tales | `res://story/tales/` | `.tale` |
| Cast members | `res://story/cast/` | `<id>.tres` (a `CastProfile`) or a `<id>/` folder with one image per mood |
| Backdrops | `res://story/backdrops/` | png, webp, jpg, svg |
| Props | `res://story/props/` | images, or scenes with a `Node2D` root |
| CGs | `res://story/cgs/` | `<name>.png` for a single picture, or a `<name>/` folder with one image per variant |
| Transition masks | `res://story/transitions/` | grayscale images |
| Music, sounds, ambience, voice | `res://story/audio/music/`, `sounds/`, `ambience/`, `voice/` | ogg, mp3, wav |
| Collection items | `res://story/collection/` | `CollectionItem` resources (`.tres`). Every CG gets a gallery item automatically; save one with `cg` set to give it a title, caption, or order. |
| Movies | `res://story/movies/` | ogv (Ogg Theora) |

When a beat starts, StoryTeller begins loading the assets it names in the background.
