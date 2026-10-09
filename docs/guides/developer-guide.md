# Developer guide

This guide covers extending StoryTeller from GDScript: adding runtime systems, actions, character looks, dialogue and choice styles, transitions, themes, and editor tools, and running StoryTeller inside your own 2D or 3D game. Writers do not need any of it. The language itself is in the [TaleScript specification](../talescript-spec.md), and short worked examples are in the [recipes](recipes.md).

All class and method names below come from `addons/storyteller/`. Doc comments (`##`) in those files show up in Godot's built-in help.

- [The Story autoload and StoryConfig](#the-story-autoload-and-storyconfig)
- [Crew members](#crew-members)
- [Custom actions](#custom-actions)
- [Cast looks](#cast-looks)
- [Dialogue styles](#dialogue-styles)
- [Choice styles](#choice-styles)
- [Transitions](#transitions)
- [Menus and theme](#menus-and-theme)
- [Embedding in your own game](#embedding-in-your-own-game)
- [Saving custom state](#saving-custom-state)
- [Story tab hooks for editor add-ons](#story-tab-hooks-for-editor-add-ons)

## The Story autoload and StoryConfig

The plugin registers `Story` (`core/story.gd`) as an autoload. In its `_ready()` it calls `Story.start(Story.load_config())`. `load_config()` loads the `StoryConfig` resource at the project setting `storyteller/config_path` (default `res://story/story_config.tres`) and falls back to a default `StoryConfig` when none exists.

`start()` shuts down any earlier crew members, creates one member for each script in `StoryConfig.crew`, and emits `crew_ready`. Everything else in StoryTeller hangs off those members.

| Member | Purpose |
|---|---|
| `start(config)` | Creates the crew from `config`. Call it again to restart with another config. |
| `config`, `is_ready` | The active `StoryConfig`, and whether `start()` has finished. |
| `get_crew(name)`, `has_crew(name)`, `get_crew_names()` | Look up crew members by name. |
| `add_crew(member)` | Adds a member created in code. Returns `false` for an empty or duplicate name. |
| `clear_all()` | Calls `clear()` on every member. Use it when you begin a new game yourself. |
| `capture()`, `restore(state)` | The state of all members, used by saves and rewind. |
| `play(tale_name, beat = "start")` | Plays a tale. Awaitable: returns when the story ends. |
| `show_title()` | Opens the title screen of the Menus crew member. |
| `expose(name, object, methods, properties)` | Makes a game object available to tales. |
| `expose_function(name, callable)` | Makes a function available to tales. |
| `shut_down()` | Frees every crew member. |

`expose()` and `expose_function()` forward to the director, so call them after `start()` has run. A later `Story.start()` creates a new director, which forgets earlier exposures.

Build a config in code when you need one:

```gdscript
func _ready() -> void:
	var config := StoryConfig.new()
	config.tales_folder = "res://dialogue"
	config.start_tale = "intro"
	config.exposed_names = PackedStringArray(["inventory"])
	Story.start(config)
	Story.expose("inventory", $Inventory, ["has_item", "add_item"], ["gold"])
```

The Story tab and the tale importer read the project's config resource, not a config built at runtime. Keep `exposed_names` in the resource as well, so the checker knows your exposed names.

The settings you will touch most:

| Property | Use |
|---|---|
| `crew` | Scripts of the crew members to create, in order. |
| `tales_folder`, `cast_folder`, `backdrop_folder`, `prop_folder`, `cg_folder`, `audio_folder`, `choice_picture_folder` | Where assets are found. |
| `exposed_names` | Names game code exposes, for the checker and suggestions. |
| `theme` | A `Theme` for dialogue boxes, choice menus, and menus. |
| `dialogue_box_scene`, `dialogue_styles` | Replace or add dialogue box styles. |
| `choice_menu_scene`, `choice_styles` | Replace or add choice menu styles. |
| `transition_folder`, `transitions` | Extra transitions for backdrops and CGs. |
| `text_styles` | Names such as `[whisper]` that expand to BBCode. |

## Crew members

Crew members are nodes that extend `StoryCrew` (`core/story_crew.gd`). Audio, saves, rewind, the stage, and the dialogue box all run as crew members. The built-in ones:

| Name | Class |
|---|---|
| `TaleDirector` | `TaleDirector` |
| `Stage` | `StoryStage` |
| `Audio` | `StoryAudio` |
| `Effects` | `StoryEffects` |
| `Collection` | `StoryCollection` |
| `Saves` | `StorySaves` |
| `Settings` | `StorySettings` |
| `Rewind` | `StoryRewind` |
| `History` | `StoryHistory` |
| `Dialogue` | `StoryDialogue` |
| `Menus` | `StoryMenus` |
| `Console` | `StoryConsole` |

Fetch one with a cast to its class:

```gdscript
var audio := Story.get_crew(&"Audio") as StoryAudio
audio.play_sound("click")
```

### Writing your own

Override the lifecycle methods you need. `StoryCrew` defines all of them as empty:

| Method | Called |
|---|---|
| `get_crew_name()` | To find the member's key. Returns the script's `class_name` by default. A member with neither a `class_name` nor an override is rejected. |
| `setup(config)` | Once, after the member joins the tree. |
| `clear()` | When a new game begins, through `Story.clear_all()`. |
| `capture()` | When saves and rewind snapshots are made. Returns a `Dictionary`. |
| `restore(data)` | When a save is loaded or the player rewinds. |
| `teardown()` | Before the member is removed. |

```gdscript
class_name Journal
extends StoryCrew
## Notes the player has found. Saved with each slot and with rewind.

signal note_added(text: String)

var _notes: Array[String] = []


func add_note(text: String) -> void:
	if text in _notes:
		return
	_notes.append(text)
	note_added.emit(text)


func has_note(text: String) -> bool:
	return text in _notes


func clear() -> void:
	_notes.clear()


func capture() -> Dictionary:
	return {"notes": _notes.duplicate()}


func restore(data: Dictionary) -> void:
	_notes.clear()
	for text in data.get("notes", []):
		_notes.append(str(text))
```

Add it to the crew in the config resource (`Crew` array in the inspector), or in code:

```gdscript
config.crew.append(preload("res://journal.gd"))
Story.start(config)
```

```gdscript
# Or add it to a running Story:
Story.add_crew(Journal.new())
```

Members are created in the order of the `crew` array, and `setup()` runs as each one is added. A member cannot count on the members after it existing yet. The built-in members reach the director with `call_deferred()` in `setup()`, and yours can do the same.

### Replacing a built-in member

Subclass the built-in class and swap the script in the array. Every built-in member except the director overrides `get_crew_name()` with a fixed name, so a subclass keeps that name and the rest of StoryTeller still finds it:

```gdscript
class_name MyStage
extends StoryStage
```

```gdscript
var config := StoryConfig.new()
var crew := config.crew.duplicate()
crew[crew.find(preload("res://addons/storyteller/stage/story_stage.gd"))] = preload("res://my_stage.gd")
config.crew = crew
```

A subclass of `TaleDirector` must override `get_crew_name()` to return `&"TaleDirector"`, because the director uses the default `class_name` lookup. Leave a script out of the array to leave the member out. `StoryConfig.dialogue_only()` does this for you (see [Embedding in your own game](#embedding-in-your-own-game)).

### Letting tales use a crew member

The director asks every crew member that has a `resolve_tale_name()` method whether it knows a name. The stage uses this for cast members and `camera`. A member of yours can do the same, which keeps its state under `capture()` and `restore()`. Three methods make it work:

```gdscript
## Names tales may use, so the checker accepts them while the game runs.
func get_tale_names() -> PackedStringArray:
	return PackedStringArray(["journal"])


## Returns [found, value] for a name used in a tale.
func resolve_tale_name(tale_name: String) -> Array:
	return [true, self] if tale_name == "journal" else [false, null]


## The methods and properties tales may use on the returned object.
func get_tale_api() -> Dictionary:
	return {"methods": PackedStringArray(["add_note", "has_note"]), "properties": PackedStringArray()}
```

Add these to `Journal`. A tale then writes `journal.add_note("found key")` and `if journal.has_note("found key"):`. Positional and named arguments both work for these methods. List `journal` in `StoryConfig.exposed_names` as well, because the Story tab does not run your crew members.

## Custom actions

Actions extend `TaleAction` (`director/tale_action.gd`). Override `get_action_name()` and define a `run()` method. Its first parameter is always the `TaleContext`. The remaining parameters become the action's arguments, with names and defaults taken from the signature:

```gdscript
class_name ActionLightning
extends TaleAction
## lightning(time = 0.3): flashes the screen and plays thunder.


func get_action_name() -> String:
	return "lightning"


func run(ctx: TaleContext, time: float = 0.3) -> void:
	var audio := ctx.get_crew(&"Audio") as StoryAudio
	if audio != null:
		audio.play_sound("thunder")
	var effects := ctx.get_crew(&"Effects") as StoryEffects
	if effects == null:
		ctx.fail("lightning() needs the Effects crew member.")
		return
	await effects.flash(Color.WHITE, time)
```

Tales call it as `lightning()`, `lightning(time = 0.5)`, or `await lightning()` to wait for it to finish.

`TaleContext` gives actions what they need:

| Member | Use |
|---|---|
| `director` | The `TaleDirector`. |
| `get_crew(name)` | Another crew member. |
| `wait(seconds)` | Waits, and returns at once while the player skips. |
| `is_skipping()` | True while the player skips. Finish effects instantly. |
| `fail(message)` | Reports a problem to the tale through `TaleDirector.runtime_error`. The tale continues. |

A value returned from `run()` reaches the tale when it awaits the action, as with `ask_text`.

### Registering an action

List the action's script in `StoryConfig.actions` (the **Actions** property of your config resource). The director registers one instance of each when the story starts, and the Story tab knows them too, so tales that call them check cleanly, get autocomplete, and get an Action card with a form.

You can also register an instance in code after `Story.start()`:

```gdscript
func _ready() -> void:
	var director := Story.get_crew(&"TaleDirector") as TaleDirector
	director.add_action(ActionLightning.new())
```

An action registered under the name of a built-in replaces it. A new `Story.start()` creates a new director, which registers the config's actions again but not ones added in code. Actions added only in code are unknown to the Story tab, so tales that call them show "Unknown action or beat" there. They still import and run.

## Cast looks

A look (`stage/cast_look.gd`) draws a character. It extends `Resource` and has three methods:

| Method | Returns |
|---|---|
| `create_visual()` | A `Node2D` whose origin is the bottom center of the character. |
| `apply_mood(visual, mood)` | `true` when the mood is known, `false` otherwise. |
| `get_moods()` | The mood names, for the checker. An empty list accepts any name. |

The built-in looks are `SpriteSetLook` (one image per mood, from a `moods` dictionary or a `folder`), `LayeredLook` (layer groups with moods such as `"face=smile, outfit=coat"`), and `SceneLook`.

A custom look:

```gdscript
@tool
class_name BlobLook
extends CastLook
## Draws a character as a colored block. Each mood picks a color.

@export var colors: Dictionary[String, Color] = {"neutral": Color.SKY_BLUE, "angry": Color.CRIMSON}
@export var size := Vector2(160, 320)


func create_visual() -> Node2D:
	var block := Polygon2D.new()
	block.polygon = PackedVector2Array([
		Vector2(-size.x / 2.0, 0.0), Vector2(size.x / 2.0, 0.0),
		Vector2(size.x / 2.0, -size.y), Vector2(-size.x / 2.0, -size.y),
	])
	return block


func apply_mood(visual: Node2D, mood: String) -> bool:
	if not colors.has(mood):
		return false
	(visual as Polygon2D).color = colors[mood]
	return true


func get_moods() -> PackedStringArray:
	return PackedStringArray(colors.keys())
```

Mark look scripts `@tool`. The editor then runs them, which it needs to list their moods for the checker.

### Profiles

A `CastProfile` ties a look to a character: `id`, `display_name`, `name_color`, `look`, `default_mood`, `scale`, and `fields`. Save one as `<id>.tres` in `StoryConfig.cast_folder`, and the Story tab, the checker, and the game all find it. To add one at run time:

```gdscript
var profile := CastProfile.new()
profile.id = "blob"
profile.display_name = "Blob"
profile.look = BlobLook.new()
profile.default_mood = "neutral"
profile.fields = {"friendship": 0}
(Story.get_crew(&"Stage") as StoryStage).add_profile(profile)
```

Profiles added this way work while the game runs. The Story tab does not know them and reports the cast member as unknown.

`fields` holds per-character data with starting values. Tales use a field like a property (`blob.friendship += 1`), and it is saved with the story. Game code reads and writes fields through `CastMember.get_field(name)` and `set_field(name, value)`, with the member from `StoryStage.get_cast(id)`.

### Scene looks

A `SceneLook` draws a character with any `PackedScene` whose root is a `Node2D` with its origin at the character's bottom center. Set `mood_names` so the checker knows the moods. A mood change calls the root's `set_mood(mood)` method when it has one, and the method returns `false` for an unknown mood. Without that method, the look plays the `AnimationPlayer` animation named after the mood.

The tale call `mira.animate("wave")` calls the root's `play_animation(name)` method when it has one. The method may await, and returns `false` for an unknown animation. Otherwise the look plays that animation from its `AnimationPlayer`.

```gdscript
extends Node2D
## Root script of a scene used by a SceneLook.

@onready var _player: AnimationPlayer = $AnimationPlayer


func set_mood(mood: String) -> bool:
	if not _player.has_animation(mood):
		return false
	_player.play(mood)
	return true


func play_animation(animation_name: String) -> bool:
	if not _player.has_animation(animation_name):
		return false
	_player.play(animation_name)
	await _player.animation_finished
	return true
```

## Dialogue styles

A dialogue style extends `DialogueBox` (`ui/dialogue_box.gd`), a `Control` that shows one line at a time. The base class handles typing, the `[pause]`, `[speed]`, `[instant]`, `[act]`, and `[sound]` tags, auto mode, skipping, and continue input. Your subclass builds its controls and implements `show_line()`:

| Member | Use |
|---|---|
| `show_line(line)` | Override. Show the line and return when the player continues. |
| `begin_line()` | Awaitable. Shows the box with its transition. Returns `false` if the line was cancelled meanwhile, in which case `show_line()` should stop. |
| `reveal(label, text, indicator = null)` | Awaitable. Types `text` into a `RichTextLabel`, then waits for the player. |
| `hide_box()`, `clear_page()`, `get_quick_menu_corner()` | Override when the style needs different behavior. |
| `continue_pressed`, `line_revealed` | Signals. |

`line` is a dictionary with `speaker_id`, `speaker_name`, `speaker_color`, `mood`, `text`, `id`, `voice`, `tale`, `beat`, `source_line`, and `read`.

```gdscript
class_name SubtitleBox
extends DialogueBox
## A bar of text along the bottom of the screen, with the speaker's name in front.

var _label: RichTextLabel
var _indicator: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_label.offset_top = -140
	_label.offset_left = 40
	_label.offset_right = -40
	add_child(_label)
	_indicator = Label.new()
	_indicator.text = "▼"
	_indicator.visible = false
	_indicator.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	add_child(_indicator)
	hide()


func show_line(line: Dictionary) -> void:
	_label.text = ""
	if not await begin_line():
		return
	var text: String = line["text"]
	if not line["speaker_name"].is_empty():
		text = "[b]%s[/b]  %s" % [line["speaker_name"], text]
	await reveal(_label, text, _indicator)
```

Save a scene whose root node uses the script, then register it in `StoryConfig.dialogue_styles`, either in the config resource or in code:

```gdscript
config.dialogue_styles["subtitle"] = preload("res://styles/subtitle.tscn")
```

Tales switch with `dialogue_style("subtitle")`. A style named `"classic"` or `"page"` replaces the built-in one. `StoryConfig.dialogue_box_scene` replaces the classic box only. Game code can switch too with `StoryDialogue.set_style(name)`, which returns `false` for an unknown name. The `Theme` from `StoryConfig.theme` is applied to every style.

## Choice styles

A choice style extends `ChoiceMenu` (`ui/choice_menu.gd`). Implement `choose(options, settings) -> int` and return the index of the picked option, or `-1` when time runs out. Each option is a dictionary with `text`, `id`, `enabled`, and `picture` (a `Texture2D`, or `null`). `settings` holds the arguments of the `choose` block, such as `style`, `timeout`, and `columns`.

| Member | Use |
|---|---|
| `pick(index)` | Call from a button. Ends the wait with that option. |
| `wait_for_pick(timeout, bar = null)` | Awaitable. Shows the menu, waits for `pick()`, `cancel()`, or the timeout (0 waits forever), hides the menu, and returns the index. |
| `ChoiceMenu.make_timer_bar(settings)` | A countdown `ProgressBar`, or `null` when there is no timeout. |
| `cancel()` | Ends the wait as a timeout. The dialogue crew calls it when the director stops waiting, for example when a save loads. |

```gdscript
class_name RowChoiceMenu
extends ChoiceMenu
## "row": the options side by side near the top of the screen.

var _column: VBoxContainer
var _row: HBoxContainer
var _timer_bar: ProgressBar


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column = VBoxContainer.new()
	_column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_column.offset_top = 40
	add_child(_column)
	_row = HBoxContainer.new()
	_column.add_child(_row)
	hide()


func choose(options: Array[Dictionary], settings: Dictionary) -> int:
	for child in _row.get_children():
		child.queue_free()
	if _timer_bar != null:
		_timer_bar.queue_free()
	for i in options.size():
		var button := Button.new()
		button.text = options[i]["text"]
		button.disabled = not options[i]["enabled"]
		button.pressed.connect(pick.bind(i))
		_row.add_child(button)
	_timer_bar = ChoiceMenu.make_timer_bar(settings)
	if _timer_bar != null:
		_column.add_child(_timer_bar)
	return await wait_for_pick(float(settings.get("timeout", 0.0)), _timer_bar)
```

Register the scene in `StoryConfig.choice_styles`, then pick it in a tale with `choose(style = "row"):`:

```gdscript
config.choice_styles["row"] = preload("res://styles/row_choice.tscn")
```

The names `"list"` and `"pictures"` are built in. A scene registered as `"pictures"` replaces the built-in cards, and `StoryConfig.choice_menu_scene` replaces `"list"`. An unknown style name is reported and the list is used.

### Choices inside your scene

`StoryDialogue.add_choice_style(style_name, menu)` registers any object that has an awaitable `choose(options, settings) -> int` and, optionally, `cancel()`. StoryTeller uses the object as given and leaves it out of the dialogue layer, so a node in your own scene can offer the choices. Pin option ids with `@id` so the node can tell options apart:

```gdscript
extends Node3D
## Lets the player choose by clicking markers in the scene.

signal picked(index: int)

var _markers: Dictionary = {}


func choose(options: Array[Dictionary], _settings: Dictionary) -> int:
	for i in options.size():
		var marker := get_node_or_null(NodePath(options[i]["id"])) as Node3D
		if marker != null and options[i]["enabled"]:
			marker.show()
			_markers[i] = marker
	var index: int = await picked
	for marker in _markers.values():
		marker.hide()
	_markers.clear()
	return index


func cancel() -> void:
	picked.emit(-1)


func on_marker_clicked(index: int) -> void:
	picked.emit(index)
```

```gdscript
var dialogue := Story.get_crew(&"Dialogue") as StoryDialogue
dialogue.add_choice_style("doors", $DoorPicker)
```

```gdscript
beat hall:
	choose(style = "doors"):
		@id("red") "The red door": jump red_room
		@id("blue") "The blue door": jump blue_room

beat red_room:
	"Red paint, still wet."

beat blue_room:
	"Blue light under the floor."
```

`remove_choice_style(name)`, `get_choice_style_names()`, and `get_choice_menu(name)` complete the registry.

## Transitions

Backdrops and CGs share one registry of named transitions. A `StoryTransition` resource (`stage/story_transition.gd`) describes one. Without a `shader`, it reuses the built-in shader with its own settings:

| Property | Use |
|---|---|
| `mode` | `StoryTransition.Mode.CUT`, `FADE`, `DISSOLVE`, `WIPE`, or `SLIDE`. |
| `direction` | For wipes and slides, in screen space (y points down). |
| `mask` | A grayscale texture for dissolves and wipes. Darker areas change first. |
| `softness` | Width of the soft edge, 0 to 0.5. |
| `shader`, `parameters` | A canvas item shader that draws the whole transition, and extra uniform values for it. |

A shader receives the uniforms `from_tex`, `to_tex`, `from_has_tex`, `to_has_tex`, `from_color`, `to_color`, `from_size`, `to_size`, `screen_size`, `progress` (0 to 1), `mask_tex`, and `has_mask`. Uniforms the shader does not declare are skipped.

Register a transition in one of three ways:

- Save a `.tres` in `StoryConfig.transition_folder`. The file name is the transition's name.
- Add it to `StoryConfig.transitions`.
- Call `StoryStage.add_transition(name, transition)` at run time.

```gdscript
var swirl := StoryTransition.new()
swirl.mode = StoryTransition.Mode.DISSOLVE
swirl.mask = preload("res://story/masks/swirl.png")
swirl.softness = 0.15
(Story.get_crew(&"Stage") as StoryStage).add_transition("swirl", swirl)
```

```gdscript
beat night:
	backdrop("library_night", transition = "swirl", time = 1.5)
```

An unknown transition name falls back to `fade` with a warning.

## Menus and theme

`StoryConfig.theme` takes a Godot `Theme` for the dialogue boxes, the choice menus, and the menu screens. Without one, `StoryTheme.build_default()` supplies the default look. It returns a `Theme` you can adjust:

```gdscript
var theme := StoryTheme.build_default()
theme.set_color("font_color", "Label", Color.WHITE)
config.theme = theme
```

The default theme also sets `code_color` for the `DialogueBox` type, which tints `[code]` spans in dialogue.

The `Menus` crew member (`menus/story_menus.gd`) shows the title screen, pause menu, save and load screens, settings, history, Extras, and the quick menu. These config options shape it: `game_title`, `start_tale`, `start_beat`, `return_to_title`, `title_background`, `title_music`, `show_quick_menu`, `show_route_chart`, `save_slot_count`, and `save_pages`.

Your code can drive the menus:

```gdscript
var menus := Story.get_crew(&"Menus") as StoryMenus
menus.open("settings")
if await menus.confirm("Quit to the title screen?"):
	Story.show_title()
menus.show_notice("Chapter 2 unlocked")
```

`open()` takes `"title"`, `"pause"`, `"save"`, `"load"`, `"settings"`, or `"history"`. `ask_text(prompt, default_text, max_length)` is awaitable as well. The signals `new_game_started` and `title_shown` report what the player did.

The menu screens come from a fixed table, `StoryMenus.SCREENS`, so the config cannot add screens. To build your own menus, leave `story_menus.gd` out of `StoryConfig.crew` and call the `Saves` crew member (`StorySaves`) directly: `save_slot(slot)` and `load_slot(slot)` return an `Error`, and `has_slot()`, `list_slots()`, `latest_slot()`, `get_slot_info()`, and `delete_slot()` describe what exists. For a new game, call `Story.clear_all()` and then `Story.play()`. Without the Menus crew, `Story.show_title()` reports an error.

## Embedding in your own game

`StoryConfig.dialogue_only()` returns a config with only what conversations need: the director, audio, saves, settings, history, and the dialogue box. There is no stage, effects, collection, rewind, or menus, so the dialogue box draws over your 2D or 3D scene. Tales in this setup use a `const` for speaker names and cannot call actions that need the missing members, such as `backdrop()`. Those report an error and the tale continues.

The `Story` autoload starts itself with the project's config before your scene loads, and calling `Story.start()` again replaces that crew. `demo/embedded/` shows the pattern in a 3D scene. The same steps in a 2D game:

```gdscript
extends Node2D

var _talking := false


func _ready() -> void:
	var config := StoryConfig.dialogue_only()
	config.tales_folder = "res://dialogue"
	Story.start(config)
	Story.expose("shop", $Shop, ["buy", "price_of"], ["gold"])
	var director := Story.get_crew(&"TaleDirector") as TaleDirector
	director.story_signal.connect(_on_story_signal)


func talk_to_shopkeeper() -> void:
	_talking = true
	await Story.play("shopkeeper")
	_talking = false


func _on_story_signal(signal_name: String, value: Variant) -> void:
	if signal_name == "quest_started":
		print("Quest: ", value)
```

```gdscript
const keeper := "Shopkeeper"

beat start:
	keeper: "Welcome. A sword costs {shop.price_of('sword')} gold."
	choose:
		"Buy the sword" if shop.gold >= shop.price_of("sword"):
			await shop.buy("sword")
			emit("quest_started", "sword_trial")
		"Just looking":
			keeper: "Take your time."
```

The three ways game code and tales talk to each other:

- **Game to tale:** `Story.expose()` and `Story.expose_function()`. Tales read and write the listed properties and call the listed methods. A method that awaits makes the tale wait.
- **Tale to game:** `emit("name", value)` in the tale emits `TaleDirector.story_signal(signal_name, value)`.
- **The whole conversation:** `Story.play()` returns when the story ends, so you know when to give control back to the player. Use a flag like `_talking` to ignore your own input while it runs.

Game code can also read and write story variables with `director.get_var(tale_name, var_name)` and `director.set_tale_var(tale_name, var_name, value)`. The second returns an error message, or an empty string on success.

The director emits these signals:

| Signal | When |
|---|---|
| `story_started(tale_name, beat)`, `story_finished` | A story starts or ends. |
| `beat_entered(tale_name, beat)` | A beat starts, including jumps and beat calls. |
| `line_started(line)`, `line_finished(line)` | A line is shown or the player continues. |
| `choice_started(options)`, `choice_made(option)` | A choice menu opens or closes. |
| `story_signal(signal_name, value)` | A tale ran `emit()`. |
| `runtime_error(message, tale_name, line)` | A tale did something invalid. |
| `rewind_barrier` | A line marked `@no_rewind` ran. |
| `tale_reloaded(tale_name)`, `reload_failed(tale_name, message)` | Live reload swapped in a tale or failed. |

### Your own presenter

The dialogue crew member is the director's default presenter. To show lines and choices with your own UI, set `TaleDirector.presenter` to an object with the same methods as `TalePresenter`:

```gdscript
extends TalePresenter

@onready var _label: RichTextLabel = $Label
@onready var _button: Button = $Button


func show_line(line: Dictionary) -> void:
	_label.text = "%s: %s" % [line["speaker_name"], DialogueBox.plain_text(line["text"])]
	await _button.pressed


func choose(options: Array[Dictionary], _settings: Dictionary) -> int:
	return 0
```

`show_line()` returns when the player continues. `choose()` returns the picked index, or `-1` for a timeout. The text still carries typing tags such as `[pause]`, and `DialogueBox.plain_text()` strips them. If the presenter has a `cancel()` method, the director calls it when it needs to release a waiting line or choice, for example when a save loads.

## Saving custom state

`Story.capture()` collects `capture()` from every crew member into one dictionary, under each member's name. `StorySaves` writes it to the slot file, and `StoryRewind` keeps one per line and choice. Loading a slot or rewinding calls `restore()` on each member with its own part.

Rules for `capture()` and `restore()`:

- Return only values that survive JSON, such as numbers, strings, booleans, arrays, and dictionaries with string keys. Convert a `Vector2` or `Color` yourself, or use `JSON.from_native()` in `capture()` and `JSON.to_native()` in `restore()`, as the director does.
- Let `restore()` replace your state completely instead of merging into it.
- Keep `capture()` cheap. It runs for every line and choice.
- Reset to starting values in `clear()`.

The `Journal` above follows these rules, so its notes are saved with each slot and rewind brings back older notes. Exposed objects have no such path: `Story.expose()` gives a tale access, and StoryTeller does not save the object's state.

### Data that outlives a playthrough

A crew member with both `capture_globals()` and `restore_globals()` is saved in the global save file, shared by all playthroughs, along with global variables and read lines:

```gdscript
class_name Achievements
extends StoryCrew
## Achievements that survive new games.

signal globals_changed

var _earned: Dictionary = {}


func earn(id: String) -> void:
	if _earned.has(id):
		return
	_earned[id] = true
	globals_changed.emit()


func capture_globals() -> Dictionary:
	return {"earned": _earned.keys()}


func restore_globals(data: Dictionary) -> void:
	_earned.clear()
	for id in data.get("earned", []):
		_earned[str(id)] = true
```

`StorySaves` finds such members by those two method names. It loads the file when the crew starts, and writes it when a slot is saved, when a story finishes, when the player quits from the menu or closes the window, and a few seconds after lines are shown. A member with a `globals_changed` signal marks the file as changed when it emits, which covers changes made between lines.

## Story tab hooks for editor add-ons

The Story tab in the editor comes from the `TaleEditorPanel` class (`editor/tale_editor_panel.gd`). An editor plugin of your own can add controls to it:

| Member | Use |
|---|---|
| `TaleEditorPanel.get_instance()` | The tab, or `null` before StoryTeller's plugin has made it. |
| `add_toolbar_control(control)`, `remove_toolbar_control(control)` | Place a control in the toolbar, before the view buttons. |
| `add_side_panel(control, title)`, `remove_side_panel(control)` | Add a tab to a column on the right of the editor. The column shows while it has tabs. |
| `line_selected(path, line)` | Signal. The caret line in the text view, or the first line of the card being edited. Lines count from 1. |
| `tale_saved(path)` | Signal. A tale was saved. |
| `get_selected_line()`, `get_current_path()` | The current line and file. |

Because the plugin creates the tab in its own `_enter_tree()`, wait a frame before asking for it:

```gdscript
@tool
extends EditorPlugin

var _story_tab: TaleEditorPanel
var _panel: Label
var _button: Button


func _enter_tree() -> void:
	# StoryTeller's own plugin creates the Story tab, so wait a frame.
	await get_tree().process_frame
	_story_tab = TaleEditorPanel.get_instance()
	if _story_tab == null:
		return
	_button = Button.new()
	_button.text = "Where am I?"
	_button.pressed.connect(func() -> void: print(_story_tab.get_current_path(), ":", _story_tab.get_selected_line()))
	_story_tab.add_toolbar_control(_button)
	_panel = Label.new()
	_story_tab.add_side_panel(_panel, "Line")
	_story_tab.line_selected.connect(_on_line_selected)


func _exit_tree() -> void:
	if _story_tab == null or not is_instance_valid(_story_tab):
		return
	_story_tab.line_selected.disconnect(_on_line_selected)
	_story_tab.remove_toolbar_control(_button)
	_story_tab.remove_side_panel(_panel)
	_button.queue_free()
	_panel.queue_free()


func _on_line_selected(path: String, line: int) -> void:
	_panel.text = "%s, line %d" % [path.get_file(), line]
```

The remove methods take the control out of the tab without freeing it, so free it yourself.
