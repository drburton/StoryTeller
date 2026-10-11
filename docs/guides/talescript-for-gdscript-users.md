# TaleScript for GDScript users

TaleScript follows GDScript syntax: indentation blocks, `var x := 0`, `if`/`elif`/`else`, `match`, `for`, `while`, array and dictionary literals, operators, and `#` comments all work as you expect. This page lists only the differences. The full rules are in the [TaleScript specification](../talescript-spec.md), and every built-in action is in the [action reference](../action-reference.md).

## At a glance

| You write | In GDScript | In TaleScript |
|---|---|---|
| `func name():` | A function | Not available. Use `beat name:`, which takes no parameters and returns nothing. |
| `name()` on its own line | Calls a function | Calls the beat `name` of this tale, then continues after the call. If no beat has that name, it calls the action `name`. |
| `other.name()` | Calls a method | Calls a beat of the tale `other`. |
| `return` | Leaves the function | Leaves the beat. In a called beat, the story continues after the call. |
| `"text"` on its own line | Does nothing | Narration. |
| `mira: "text"` | Syntax error | Dialogue. |
| `jump other_beat` | Not available | Replaces the current beat with another one. |
| `choose:` | Not available | A menu of string options. |
| `f(x, time = 1.0)` | Positional arguments only | Named arguments are allowed after the positional ones. |
| `@global var x` | Not available | A variable shared across playthroughs. |

## Beats, jumps, and beat calls

```gdscript
var trust := 0

beat start:
	"The bell rings."
	side_quest()                # runs the beat, then comes back here
	if trust > 2: jump good_end # one-line form
	jump other_tale.start       # a beat in another tale

beat side_quest:
	trust += 1
	return                      # back to the line after side_quest()

beat good_end:
	"Good."
```

- Beats cannot be nested.
- A beat ends after its last statement or at `return`. When it ends, the story continues after the most recent beat call. Without one, the story ends.
- `jump` replaces the current beat. A `jump` inside a called beat still returns to the caller once the new beat ends.
- Write a beat call on a line of its own. Using it inside an expression, such as `x = side_quest()`, reports a runtime error.
- `visited("tale.beat")` is true once the player has entered that beat in the current playthrough.

## Dialogue and narration

```gdscript
const HERO := "Alex"
var gold := 5

beat start:
	"A string on its own line is narration."
	mira: "Dialogue names a cast member."
	mira (smile): "A mood in parentheses changes the look first."
	HERO: "A const holding a display name can speak too."
	mira: "You have {gold} gold. Write {{braces}} twice to show them."
```

- The speaker is a cast member id or a `const` holding a name. Characters with layered looks take a quoted mood, as in `mira ("face=pale, outfit=coat"): "..."`.
- The text is one string literal. Triple quotes span several lines.
- `{expression}` inserts a value. Strings use Godot BBCode, plus the tags `[pause]`, `[pause=0.5]`, `[speed=2.0]`, `[instant]`, `[sound=name]`, and `[act=expression]`. Named styles from `StoryConfig.text_styles` such as `[whisper]` expand to BBCode.

## Choose blocks

```gdscript
var knocked := false
var has_key := false

beat hallway:
	choose(style = "pictures", timeout = 5.0, columns = 3):
		@picture("door") "Open the door":
			jump inside
		"Knock first" if not knocked:
			knocked = true
		@once "Ask about the key":
			mira: "I lost it last week."
		@show_disabled "Use the key" if has_key:
			jump inside
		timeout:
			"You hesitate too long."

beat inside:
	"Inside."
```

- Each option is a string, an optional `if` condition, and an indented body.
- Options whose condition is false are hidden, unless the option has `@show_disabled`.
- `timeout:` runs when the `timeout` argument runs out.
- `choose` arguments: `style` (`"list"` or `"pictures"`, plus any style your project adds), `timeout` in seconds, and style options such as `columns`.
- `timeout` is an ordinary identifier outside `choose` blocks.

## Annotations

Annotations come before the statement they apply to, on the same line or on the line above.

| Annotation | Applies to | Effect |
|---|---|---|
| `@title("...")` | Tale | Display name shown on save slots and in the route chart. |
| `@global` | Top-level `var` | Shared across playthroughs. |
| `@once` | Choice option | Disappears after being chosen once in a playthrough. |
| `@show_disabled` | Choice option | Shown greyed out when its condition is false. |
| `@id("...")` | Line or option | Pins the id used for translation, read tracking, and `@once`. |
| `@voice("...")` | Line | Voice clip to play. |
| `@no_rewind` | Any statement | The player cannot rewind past it. |
| `@skip_safe` | Beat | Counts the beat's lines as already read for skipping. |
| `@picture("...")` | Choice option | Picture for the `"pictures"` style. |
| `@heading("...")` | Beat | Name shown in the route chart. |

GDScript annotations such as `@export` and `@onready` do not exist here.

## Variables

| Declared | Scope | Saved |
|---|---|---|
| At the top level | Story variable. Other tales read it as `tale_name.variable`. | In each save slot |
| At the top level with `@global` | Global variable | In the global save file |
| Inside a beat | Temporary, until the beat ends | With the running beat |

Constants need a value and cannot be assigned. A new game resets story variables. Cast members also keep data: fields declared in the cast profile are used like properties, as in `mira.friendship += 1`.

## Actions and await

Actions are called like functions: `backdrop("library", transition = "fade")`. An action starts at once and returns. Put `await` in front to wait for it to finish:

```gdscript
var player_name := ""

beat start:
	await fade_out(Color.BLACK, time = 1.0)
	player_name = await ask_text("Your name?", "Sam")
```

Before a line or choice appears, the director waits for running actions to finish. Named arguments work for actions and for cast and camera methods. Functions and objects exposed by game code take positional arguments only.

## The sandboxed evaluator

Expressions can reach only these names:

- story, global, and temporary variables, and constants;
- cast members by id, and `camera`;
- `LEFT`, `CENTER`, `RIGHT`, `PI`, `TAU`, `INF`, `NAN`;
- the constructors `Vector2`, `Vector2i`, `Vector3`, `Color`, `Rect2`, and constants such as `Color.RED` and `Vector2.ZERO`;
- the functions `abs`, `ceil`, `floor`, `round`, `clamp`, `min`, `max`, `len`, `str`, `int`, `float`, `randf`, `randi`, `randf_range`, `randi_range`, `tr`, `visited`, and `collected`;
- objects and functions that game code exposes.

Methods of plain values work as in GDScript, for example `items.erase("key")` or `names.is_empty()`. Engine objects, singletons, and nodes are out of reach, and there is no `preload`, `load`, `$Node`, or `%Node`.

A mistake found while playing, such as adding text to a number, does not crash the game. The director emits `TaleDirector.runtime_error`, prints the message with the tale and line, and continues with the next statement.

## Exposing game objects

Game code decides what a tale may touch. List the methods and properties you allow:

```gdscript
# In game code, after Story has started.
Story.expose("inventory", $Inventory, ["has_item", "add_item"], ["gold"])
Story.expose_function("day_of_week", func(): return calendar.weekday)
```

```gdscript
beat shop:
	if inventory.has_item("key") and day_of_week() == 3:
		inventory.gold += 5
```

Only the listed methods can be called, and only the listed properties can be read or written. Anything else reports an error to the tale.

List every exposed name in `StoryConfig.exposed_names` in your project's config resource. The checker reports unknown names without it, and the Story tab uses the list for suggestions. The list changes nothing at runtime; `Story.expose()` does the exposing.

## What is left out

| Removed | Notes |
|---|---|
| `func`, `class`, `class_name`, `extends`, `signal`, `enum`, `static`, `@tool`, `@export`, `@onready` | The top level holds only annotations, `var`, `const`, and `beat`. |
| `$Node`, `%Node`, `preload`, `load`, `is`, `as` | |
| Lambdas | |
| `match` binding, array, and dictionary patterns | Literal, constant, and `_` patterns with `when` guards work. |
| Loose bracket continuation | Inside brackets, continuation lines must be indented deeper than the line that opened the bracket. |
| Unlimited loops | A loop that runs 100,000 steps without showing a line or choice stops with a runtime error. |
