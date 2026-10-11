# TaleScript for writers

A cheat sheet for writing tales without a programming background. Each topic has a short explanation and a small example. The full rules are in the [language specification](../talescript-spec.md), and every action is listed in the [action reference](../action-reference.md).

The examples use the demo project's characters `mira` and `ada`, its backdrops, and its music. Swap in your own names.

Contents:

- [Beats](#beats)
- [Narration and dialogue](#narration-and-dialogue)
- [Moods](#moods)
- [Speakers without art](#speakers-without-art)
- [Choices](#choices)
- [Variables](#variables)
- [Conditions](#conditions)
- [Jumps and beat calls](#jumps-and-beat-calls)
- [Text tags](#text-tags)
- [Common actions](#common-actions)
- [Headings and titles](#headings-and-titles)
- [Comments](#comments)

## Beats

A tale file holds one or more beats. Each beat holds a named section of the story, and everything the player sees happens inside one. Write `beat`, a name, and a colon, then indent the lines that belong to it. The name uses letters, digits, and underscores. New Game starts at the beat named `start`.

```gdscript
beat start:
	"The bell rings."
	jump hallway

beat hallway:
	"The hallway is quiet."
```

Indent with one tab per level. A file may use tabs or spaces, but each file must use only one of them.

## Narration and dialogue

A line of text in quotes on its own is narration. Put a character's name and a colon in front for dialogue.

```gdscript
beat start:
	"Sunlight spills across rows of empty desks."
	mira: "You're here early."
```

Long text can run over several lines inside triple quotes:

```gdscript
beat start:
	mira: """It was a long night.
Longer than I'd like to admit."""
```

To show a curly brace, double it: `{{` and `}}`.

## Moods

A mood picks which image shows for a character, such as `smile` or `curious`. Put it in parentheses after the name to switch before the line is shown. The character keeps that mood until you change it again.

```gdscript
beat start:
	mira.enter("smile", at = LEFT)
	mira: "You made it."
	mira (curious): "Did you read the chapter?"
	mira (smirk): "Of course you did."
```

`enter` takes the mood the character appears in. The moods come from the image names in the character's cast folder. The Text view suggests the available moods as you type.

## Speakers without art

A speaker who has no cast folder needs a constant that holds the display name. Declare it at the top of the file, outside any beat.

```gdscript
const GUARD := "Gate Guard"

beat start:
	GUARD: "Halt. Who goes there?"
	mira: "Just a student."
```

## Choices

`choose:` shows the player one button per option. Each option is a line of text ending in a colon, followed by an indented block that runs when it is picked.

```gdscript
beat start:
	mira: "Which way?"
	choose:
		"Take the stairs":
			mira: "Good for the legs."
		"Take the elevator":
			mira: "Lazy, but fair."
	"They arrive at the library."
```

When the player picks an option, its block runs, and then the story carries on after the whole `choose:`.

### Once-only options

Put `@once` before an option and it disappears after the player has picked it. It suits question menus, where each topic should come up one time.

```gdscript
beat start:
	choose:
		@once "Ask about the library":
			ada: "It opened before the school did."
		@once "Ask about the rain":
			ada: "It rarely lets up this month."
		"Leave":
			ada: "Come back soon."
```

### Conditions

Add `if` and a condition after the option text. The option only appears while the condition holds. Add `@show_disabled` to show it greyed out instead.

```gdscript
var trust := 0

beat start:
	choose:
		"Ask for the key":
			mira: "Here you go."
		"Ask about her secret" if trust > 2:
			mira (soft): "Okay. I will tell you."
		@show_disabled "Ask about the letter" if trust > 5:
			mira: "That one is private."
```

### Timeouts

`timeout` in the parentheses sets a time limit in seconds. A `timeout:` block at the end of the options runs when the time runs out.

```gdscript
beat start:
	choose(timeout = 5.0):
		"Open the door":
			"The door swings wide."
		"Knock first":
			"Three soft knocks."
		timeout:
			"You hesitate too long, and the moment passes."
```

### Picture choices

`choose(style = "pictures"):` shows picture cards instead of buttons. Name each option's picture with `@picture`. The pictures live in `res://story/choices/`, and you refer to them by file name without the extension.

```gdscript
beat start:
	mira (curious): "Is that rain? I didn't bring an umbrella."
	choose(style = "pictures"):
		@picture("umbrella") "Share mine":
			mira (smile): "My hero."
		@picture("door") "Run for it":
			mira (smirk): "You first."
```

## Variables

A variable remembers something. Declare story variables at the top of the file with `var`. They are saved with the player's game.

```gdscript
var trust := 0
var player_name := "Sam"

beat start:
	trust += 1
	mira: "Welcome, {player_name}. Trust is now {trust}."
```

- `{name}` inside a line shows the variable's current value.
- `+=` and `-=` add to a number and subtract from it. `=` replaces the value.
- Variables can hold numbers, text in quotes, and `true` or `false`.
- `@global var` makes a variable that carries across playthroughs.
- A variable from another tale is written `tale_name.variable`, for example `prologue.trust`.

To let the player type a name, wait for the answer:

```gdscript
var player_name := "Sam"

beat start:
	player_name = await ask_text("What's your name?", "Sam")
	mira: "Nice to meet you, {player_name}."
```

Characters can keep their own numbers too, such as `mira.friendship`. They are declared in the character's profile (see [cast members](../talescript-spec.md#132-cast-members)).

## Conditions

`if`, `elif`, and `else` pick what happens based on a variable. Use `==` to compare for equality, `>` and `<` for bigger and smaller, and `and`, `or`, and `not` to combine tests.

```gdscript
var trust := 0
var met_ada := false

beat start:
	if trust > 2 and met_ada:
		mira (smile): "You and Ada get along."
	elif trust > 0:
		mira: "Thanks for the help."
	else:
		mira: "Hm."
```

`visited("tale.beat")` is true once the player has been to that beat, so a scene can notice what came before.

```gdscript
beat start:
	if visited("prologue.honest"):
		mira: "You were honest with me earlier."
	else:
		mira: "Let's start fresh."
```

## Jumps and beat calls

`jump` leaves the current beat for another one and does not come back. Use a tale name and a dot to reach a beat in another tale.

```gdscript
beat start:
	"The exam is over."
	jump results

beat results:
	"The scores are posted."
	jump chapter_1.start
```

A beat call runs another beat and then continues after the call. Write the beat's name with empty parentheses.

```gdscript
beat start:
	"A rainy afternoon."
	flashback()
	"Back in the present."

beat flashback:
	"Years ago, the same rain fell."
```

`return` ends the current beat early. In a beat that was called, the story continues after the call.

## Text tags

Tags go inside the quotes and change how a line types out. Basic formatting uses tags such as `[b]bold[/b]` and `[i]italic[/i]`.

| Tag | Effect |
|---|---|
| `[pause]` | Waits for the player, then keeps typing on the same line |
| `[pause=0.5]` | Waits half a second |
| `[speed=0.5]...[/speed]` | Types the enclosed text at half speed. `2.0` is twice as fast |
| `[instant]...[/instant]` | Shows the enclosed text at once |
| `[whisper]...[/whisper]` | Gray italic text |
| `[shout]...[/shout]` | Large bold text |
| `[thought]...[/thought]` | Pale blue italic text |

```gdscript
beat start:
	mira: "You're here early.[pause] Couldn't sleep?"
	ada: "Tags change how a line types: [speed=0.3]slowly[/speed], or [instant]all at once[/instant]."
	mira (curious): "[whisper]Sorry, Ada.[/whisper]"
	mira: "[shout]Found it![/shout]"
	mira (soft): "[thought]I hope she doesn't notice.[/thought]"
```

The whisper, shout, and thought styles are defaults. A project can change them or add more in `StoryConfig.text_styles`.

## Common actions

Actions are written like `name(details)` and change what the player sees or hears. An action starts at once. Put `await` in front to wait until it finishes. Extra details written as `name = value` can come in any order after the plain ones, and you can leave out any that have a default. The [action reference](../action-reference.md) lists them all.

### Backdrop and music

```gdscript
beat start:
	backdrop("library", transition = "fade", time = 1.0)
	music("library_theme", volume = 0.6)
	"The library hums with quiet."
	backdrop("library_night", transition = "dissolve", time = 2.0)
	stop_music(fade = 1.5)
```

Transitions include `fade`, `dissolve`, `cut`, `none`, and wipes and slides in four directions. `sound("chime")` plays a one-off sound effect.

### Cast: enter, exit, and move

Stage positions include `LEFT`, `CENTER`, and `RIGHT`.

```gdscript
beat start:
	mira.enter("smile", at = LEFT)
	ada.enter("neutral", at = RIGHT, time = 0.6)
	mira: "Ada, meet me in the middle."
	await mira.move_to(CENTER, time = 0.6)
	ada.exit(time = 0.6)
	mira.exit(transition = "slide_left")
```

### Props

```gdscript
beat start:
	prop("book", at = Vector2(0.66, 0.4))
	"A book lies open on the table."
	hide_prop("book")
```

### CGs

A CG shows a full-screen event picture. A folder in `res://story/cgs/` holds one image per variant, and the second name picks the variant. `hide_cg()` brings the stage back.

```gdscript
beat start:
	cg("window_table", "afternoon", time = 1.5)
	"The afternoon slips by between pages."
	cg("window_table", "rain", transition = "dissolve", time = 2.0)
	hide_cg(time = 1.0)
```

### Wait

`wait` pauses the story for some seconds.

```gdscript
beat start:
	"The lights flicker."
	wait(1.0)
	"Then they steady."
```

## Headings and titles

`@heading` above a beat names it on the route chart that players see under Extras. Without one, the chart shows the beat's own name. `@title` at the top of the file gives the tale a display name, which the chart shows above that tale's beats.

```gdscript
@title("Chapter 1")

@heading("The walk home")
beat walk:
	"The street is wet and empty."
```

## Comments

Everything after a `#` on a line stays out of the game, so you can use it for notes to yourself. A comment that starts with `##` right before a beat describes that beat. At the top of the file, it describes the tale.

```gdscript
## The first morning at school.
beat start:
	# Mira arrives before the others.
	mira.enter("smile", at = LEFT)
	mira: "Early again."  # keep this line short
```
