# TaleScript Language Specification

Version: **draft 0.1** (milestone M1)

TaleScript is the language StoryTeller stories are written in. It follows GDScript's syntax wherever GDScript has a way to express something, and adds a few statements for writing stories. This document is the reference for the parser, the checker, the editor tools, and writers who want precise rules.

Implementation status:

| Part | Status |
|---|---|
| Lexical rules, statements, expressions (§2 to §6) | Implemented in `addons/storyteller/talescript/` |
| Checks listed in §9 | Planned (checker, M1) |
| Runtime meaning of statements (§5) | Planned (director, M1) |
| Text markup and interpolation (§7) | Planned (M1) |

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

A beat is a named section of a tale. Beats cannot be nested and take no parameters. A beat ends when its last statement runs, at `return`, or at `jump`. When a beat that was **jumped** to ends, the tale ends. When a beat that was **called** ends, the story continues after the call.

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
- Cast members by id (`mira`), with their properties and methods.
- Stage positions: `LEFT`, `CENTER`, `RIGHT`, and `Vector2` for exact positions.
- Built-in functions: `randi_range`, `randf`, `min`, `max`, `clamp`, `round`, `len`, `str`, `visited("tale.beat")`, `collected("id")`, `tr("key")`.
- Objects and functions that game code exposes with `Story.expose()`. Nothing else in the engine is reachable.

---

## 7. Text

### 7.1 Markup

Dialogue and narration strings use Godot BBCode (`[b]`, `[i]`, `[color=red]`, `[wave]`, and so on). StoryTeller adds:

| Tag | Effect |
|---|---|
| `[pause]` | Wait for the player, then keep typing on the same line. |
| `[pause=0.5]` | Wait half a second. |
| `[speed=2.0]...[/speed]` | Change typing speed. |
| `[sound=bell]` | Play a sound at this point. |
| `[act=shake(0.2)]` | Run an action at this point. |

### 7.2 Interpolation

`{expression}` inserts a value: `"You have {gold} gold."`. Write `{{` and `}}` for literal braces.

---

## 8. Annotations

| Annotation | Applies to | Meaning |
|---|---|---|
| `@title("...")` | Tale (top level) | Display name for save slots and the Story Map. |
| `@global` | `var` at top level | Variable shared across playthroughs. |
| `@once` | Choice option | Option disappears after it is chosen once in a playthrough. |
| `@show_disabled` | Choice option | Show the option greyed out when its condition is false. |
| `@id("...")` | Dialogue or narration | Pins the line id used for translation and voice. |
| `@voice("...")` | Dialogue or narration | Assigns a voice clip. |
| `@no_rewind` | Any statement | The player cannot rewind past this point. |
| `@skip_safe` | Beat | Treat the beat as already read for skipping. |

---

## 9. Checks (planned)

The checker runs after parsing and reports, with file and line:

- unknown actions, beats, tales, variables, cast members, and moods;
- wrong argument names, counts, or types for actions;
- `elif` or `else` without a preceding `if`;
- `break` or `continue` outside a loop;
- assignment to a constant;
- annotations used in the wrong place;
- unreachable statements after `jump` or `return`;
- expression statements that have no effect (warning).

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
7. Story annotations: `@title`, `@global`, `@once`, `@show_disabled`, `@id`, `@voice`, `@no_rewind`, `@skip_safe`.

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

The parser (`TaleParser.parse()`) returns a `TaleDocument` whose tree satisfies:

1. **Complete coverage.** Every physical line of the source belongs to exactly one node. Blank lines are `BLANK` nodes and comment-only lines are `COMMENT` nodes.
2. **Lossless printing.** `TaleDocument.to_source()` rebuilds the source from the tree and returns exactly the original text, including line endings, indentation, comments, trailing spaces, and the presence or absence of a final newline.
3. **Error tolerance.** A line that cannot be parsed becomes an `ERROR` node with a message, and parsing continues. Error lines ending in `:` still open a block, so their bodies don't cause further errors.
4. **Comment placement.** Blank and comment lines belong to the block of the next statement, except comments indented deeper than that statement, which stay in the block that just ended.
5. **Inline bodies.** In `if done: jump end`, the `jump` node is marked `inline` and shares the header's line.

These guarantees let the visual editor change one statement by replacing only that statement's lines.
