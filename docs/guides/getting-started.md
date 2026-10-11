# Getting started

This guide takes you from an empty Godot project to a short scene you can play. It needs Godot 4.7.2 (the standard build, .NET is not required) and takes about ten minutes.

You will:

1. Install the add-on.
2. Run the setup wizard.
3. Add a character and a backdrop.
4. Write a scene with a choice.
5. Play it.

## 1. Install the add-on

1. Copy the `addons/storyteller/` folder from the StoryTeller repository into your project, so it ends up at `res://addons/storyteller/`.
2. Open **Project > Project Settings > Plugins** and tick **Enable** next to **StoryTeller**.

A **Story** tab now sits at the top of the editor, next to 2D, 3D, and Script. Enabling the plugin also adds the `Story` autoload, which plays your tales.

## 2. Run the setup wizard

Open the **Story** tab. While the project has no StoryConfig, a banner reads "This project has no StoryConfig yet." Click **Set Up Project**.

The **Set Up StoryTeller** dialog asks for:

| Field | Meaning | Default |
|---|---|---|
| Game title | Shown on the title screen | empty |
| Story folder | Where the story folders go | `res://story` |
| Written in | The language you write the tale in | `en` |
| Translate into | Other languages, separated by commas (optional) | empty |

Two checkboxes are ticked by default: **Write a first tale to start from** and **Make a main scene that opens the title screen**. Click **Set Up**.

The wizard makes:

- The folders `tales`, `cast`, `backdrops`, `props`, `cgs`, `choices`, `transitions`, `collection`, `audio` (with `music`, `sounds`, `ambience`, and `voice` inside), and `translations` under your story folder.
- `story_config.tres`, a StoryConfig that points at those folders. Its start tale is `start`.
- `tales/start.tale`, a short sample tale that opens in the Story tab.
- `res://main.tscn` and `res://main.gd`, a main scene that calls `Story.show_title()`.

It also points the project at the new StoryConfig. If your project already has a main scene, the wizard leaves that setting alone, so call `Story.show_title()` from your own main scene. The wizard never overwrites a file that already exists.

Press **Play** to try it. The title screen shows your game title. **New Game** plays the sample tale.

## 3. Add a character

StoryTeller finds characters by name in the cast folder. The quickest way to add one is a folder named after the character, with one image per mood:

```
res://story/cast/rowan/neutral.png
res://story/cast/rowan/smile.png
res://story/cast/rowan/worried.png
```

The folder name becomes the name you use in tales (`rowan`), and each file name is a mood (`smile`). PNG, WebP, JPG, and SVG images work. The dialogue box shows the folder name with a capital letter ("Rowan"). When a character enters without a mood, StoryTeller uses `neutral` if it exists, and otherwise the first mood in alphabetical order.

If you have no art yet, copy any three images and rename them.

To set a different display name, a name color, a size, or fields such as `affection`, save a `CastProfile` resource as `res://story/cast/rowan.tres` instead. The profile's settings are documented in `addons/storyteller/stage/cast_profile.gd`, and section 13.2 of the [language specification](../talescript-spec.md#132-cast-members) lists what tales can do with cast members.

## 4. Add a backdrop

Backdrops are images in `res://story/backdrops/`. A tale refers to one by its file name without the extension. Save an image as `res://story/backdrops/cafe.png` and you can write `backdrop("cafe")`.

Other kinds of assets follow the same idea: music in `res://story/audio/music/`, sound effects in `res://story/audio/sounds/`, props in `res://story/props/`, and full-screen event pictures (CGs) in `res://story/cgs/`. The full list is in the [asset folders](../talescript-spec.md#134-asset-folders) table.

## 5. Write the scene

In the **Story** tab, click `start.tale` in the file list on the left. Select all the text and replace it with this:

```gdscript
@title("Chapter 1")

var warmth := 0

@heading("The cafe")
beat start:
	backdrop("cafe")
	rowan.enter("neutral", at = CENTER)
	"The cafe is almost empty. Rain taps on the window."
	rowan: "You're late."
	rowan (smile): "Just kidding. Sit down."
	choose:
		"Apologize":
			warmth += 1
			rowan: "Apology accepted."
		"Order a coffee":
			rowan (worried): "Rough day?"
	jump closing

@heading("Closing time")
beat closing:
	if warmth > 0:
		rowan (smile): "I'm glad you came."
	else:
		rowan: "Next time, text me first."
	rowan.exit()
	"The rain keeps falling."
```

Indent with a tab (or use spaces throughout the file, but not both). Press **Ctrl+S** to save.

What the lines do:

- `@title("Chapter 1")` gives the tale a display name. The route chart shows it above the tale's beats.
- `var warmth := 0` creates a story variable. It is saved with the game.
- `beat start:` opens the first beat. New Game begins at the beat named `start`.
- `backdrop("cafe")` fades in the backdrop. `rowan.enter("neutral", at = CENTER)` brings Rowan on stage in the middle (`LEFT` and `RIGHT` also work).
- A line of text in quotes on its own is narration. `rowan: "..."` is dialogue, and `rowan (smile): "..."` switches Rowan to the `smile` mood first.
- `choose:` shows one button per option. Each option has an indented body that runs when the player picks it.
- `jump closing` moves to the next beat.
- In `closing`, `if` and `else` pick a line by the value of `warmth`.
- `@heading(...)` above a beat names it on the route chart that players see under Extras.

If something is wrong, the problem list under the editor names the line. Unknown characters and misspelled actions show up there while you type. The Text view also suggests actions, characters, moods, and beats as you type.

## 6. Play it

Press **Play**. On the title screen, click **New Game**.

| Input | Action |
|---|---|
| Space, Enter, or click | Continue |
| Hold Ctrl | Skip |
| Escape or right click | Pause menu (save, load, history, settings) |
| Page Up or mouse wheel up | Rewind |
| V or middle click | Hide the dialogue box; any key brings it back |

A gamepad works too: A continues, the right shoulder skips, the left shoulder rewinds, Start opens the menu, Y toggles auto, X hides the dialogue box, and Back opens the history.

While the game runs from the editor, saving a tale reloads it in the running game and continues at the same line. Keep the game window open, change a line, press Ctrl+S, and watch the change.

Also try the **Cards** view in the Story tab. It shows the same beat as a stack of cards you can edit without typing syntax.

## Where to go next

- [The visual editor](visual-editor.md): build scenes with cards and the Story Map.
- [TaleScript for writers](talescript-for-writers.md): a cheat sheet for dialogue, choices, variables, text tags, and common actions.
- [Action reference](../action-reference.md): every built-in action with its arguments and defaults.
- [TaleScript specification](../talescript-spec.md): the full language rules, asset folders, and cast members.
- The demo: press Play in this repository's project and open `demo/tales/welcome.tale` for a tour with working examples.
