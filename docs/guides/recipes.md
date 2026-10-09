# Recipes

Short worked examples for common story mechanics. Each one shows the TaleScript, and the GDScript where game code takes part. Cast ids, backdrops, and pictures come from the demo project. For the language rules see the [TaleScript specification](../talescript-spec.md). For the GDScript side see the [developer guide](developer-guide.md).

- [Relationship meter](#relationship-meter)
- [Checking an inventory held by game code](#checking-an-inventory-held-by-game-code)
- [Handing off to a mini-game](#handing-off-to-a-mini-game)
- [Timed choice](#timed-choice)
- [Picture choice](#picture-choice)
- [Flashback](#flashback)
- [Branching on a visited beat](#branching-on-a-visited-beat)

## Relationship meter

Each cast member can keep its own data, declared in the cast profile. The demo gives Mira a `friendship` field. Open `mira.tres` in the inspector and add the key `friendship` with the value `0` to the `fields` dictionary:

```ini
[resource]
script = ExtResource("1_profile")
id = "mira"
display_name = "Mira"
; other properties unchanged
fields = {
"friendship": 0
}
```

Tales read and change a field like a property. It is saved with the story and starts over in a new game:

```gdscript
beat share_lunch:
	mira: "Want half of my sandwich?"
	choose:
		"Sure, thanks.":
			mira.friendship = clamp(mira.friendship + 1, 0, 5)
			mira (smile): "Good. I made too much."
		"I'm fine.":
			mira.friendship = clamp(mira.friendship - 1, 0, 5)
			mira (soft): "Okay."
	"Friendship with Mira: {mira.friendship} of 5."
	if mira.friendship >= 3:
		jump close_friends
	jump acquaintances

beat close_friends:
	mira: "Same table tomorrow?"

beat acquaintances:
	match mira.friendship:
		0:
			mira: "See you around."
		_:
			mira: "Bye for now."
```

Field names must be identifiers and cannot reuse a cast member's own members such as `mood` or `position`. The checker reports a misspelled field, and the Story tab suggests the real ones.

Game code reads the same value through the stage:

```gdscript
var stage := Story.get_crew(&"Stage") as StoryStage
var mira := stage.get_cast("mira")
print(mira.get_field("friendship"))
mira.set_field("friendship", 3)
```

To add fields in code, set `CastProfile.fields` before you call `StoryStage.add_profile()`. See [cast looks and profiles](developer-guide.md#cast-looks).

## Checking an inventory held by game code

Keep the inventory in a GDScript node, and let the tale ask it questions. The tale sees only the methods and properties you list.

```gdscript
class_name Inventory
extends Node

var gold := 0
var _items: Dictionary = {}


func has_item(item: String) -> bool:
	return _items.has(item)


func add_item(item: String) -> void:
	_items[item] = true


func remove_item(item: String) -> void:
	_items.erase(item)
```

Expose it once Story has started, for example in your main scene's `_ready()`:

```gdscript
Story.expose("inventory", $Inventory, ["has_item", "add_item", "remove_item"], ["gold"])
```

Add `inventory` to `StoryConfig.exposed_names` in your project's config resource. Without that, the checker and the Story tab report the name as unknown. Then use it in a tale:

```gdscript
beat locked_door:
	if inventory.has_item("brass_key"):
		"The brass key turns with a click."
		inventory.remove_item("brass_key")
		jump inside
	elif inventory.gold >= 10:
		"A guard waves you through for ten gold."
		inventory.gold -= 10
		jump inside
	else:
		"The door is locked."

beat inside:
	"The room smells of dust."
	inventory.add_item("old_map")
```

StoryTeller does not save exposed objects, and rewinding or loading a save does not undo what a tale did to them. Keep calls like `add_item` safe to repeat. To have saves and rewind include the inventory, make it a crew member instead. See [saving custom crew state](developer-guide.md#saving-custom-state).

## Handing off to a mini-game

### Await an exposed method

A method that awaits something makes the tale wait too. The tale continues with the method's return value.

```gdscript
extends Node

@export var game_scene: PackedScene


func play(difficulty: int = 1) -> int:
	var game := game_scene.instantiate()
	add_child(game)
	game.start(difficulty)
	var score: int = await game.finished
	game.queue_free()
	return score
```

```gdscript
Story.expose("fishing", $Minigames, ["play"])
```

```gdscript
var fish_score := 0

beat pier:
	ada: "Think you can beat my record?"
	hide_dialogue()
	var result := await fishing.play(2)
	fish_score = result
	if fish_score >= 5:
		ada (smile): "Not bad. {fish_score} fish."
	else:
		ada: "Only {fish_score}? Try again."
```

`hide_dialogue()` clears the dialogue box while the mini-game runs. The next line shows it again. List `fishing` in `StoryConfig.exposed_names` too.

### Emit a signal and play again afterward

When a tale cannot wait, for example in a game that uses the dialogue-only crew, end the tale with `emit()` and let game code take over. Story variables survive between `Story.play()` calls, so the game can pass the result back before it plays the next beat:

```gdscript
var minigame_score := 0

beat start:
	ada: "Ready?"
	emit("minigame", "fishing")

beat after_minigame:
	if minigame_score >= 5:
		ada: "You win."
	else:
		ada: "Better luck next time."
```

```gdscript
var _minigame := ""


func _ready() -> void:
	var director := Story.get_crew(&"TaleDirector") as TaleDirector
	director.story_signal.connect(_on_story_signal)


func _on_story_signal(signal_name: String, value: Variant) -> void:
	if signal_name == "minigame":
		_minigame = str(value)


func talk_at_pier() -> void:
	await Story.play("pier")
	if _minigame.is_empty():
		return
	var score: int = await run_minigame(_minigame)
	_minigame = ""
	var director := Story.get_crew(&"TaleDirector") as TaleDirector
	director.set_tale_var("pier", "minigame_score", score)
	await Story.play("pier", "after_minigame")
```

In a game with the Menus crew and a `start_tale`, a story that ends brings back the title screen. Use the await approach there.

## Timed choice

Give `choose` a `timeout` in seconds, and add a `timeout:` branch. The list and picture styles show a countdown bar.

```gdscript
var fell := false

beat bridge:
	"The rope bridge sways. Something rattles below."
	choose(timeout = 5.0):
		"Run across.":
			"You make it, breathless."
		"Hold the rope.":
			"The bridge steadies, slowly."
		timeout:
			fell = true
			"You hesitate too long. A plank gives way."
```

Without a `timeout:` branch, an expired timer continues after the `choose` block. A `choose` block can have only one `timeout:` branch.

## Picture choice

Add `style = "pictures"` and give each option a `@picture`. The names refer to images in `StoryConfig.choice_picture_folder`, which is `res://story/choices` by default. The demo uses `umbrella.png`, `armchair.png`, and `door.png`.

```gdscript
beat rain:
	mira (curious): "Is that rain? I didn't bring an umbrella."
	choose(style = "pictures", columns = 3):
		@picture("umbrella") "Share mine.":
			mira.friendship += 2
		@picture("armchair") "Wait it out here.":
			mira.friendship += 1
		@picture("door") "Run for it.":
			"You dash out into the rain."
```

`columns` sets how many cards fit in a row before wrapping (four by default). An option without a picture shows its text alone. `timeout` works here as well.

## Flashback

Write the flashback as its own beat and call it. When the beat ends, the story continues after the call, so one flashback can serve several scenes. A beat in another tale is called as `tale.beat()`.

```gdscript
beat start:
	backdrop("library")
	"Mira stares at the old photograph."
	flashback()
	"She puts the photograph away."
	memories.first_day()

beat flashback:
	filter("sepia", strength = 0.8, time = 1.0)
	backdrop("classroom_morning", transition = "dissolve", time = 1.5)
	mira.enter("smile", at = LEFT)
	mira: "Sit by me. The window seat is free."
	mira.exit()
	filter("none", time = 1.0)
	backdrop("library", transition = "dissolve", time = 1.5)
```

```gdscript
## memories.tale
## Flashbacks shared by several tales.
beat first_day:
	filter("sepia", strength = 0.8, time = 1.0)
	"The first day of school."
	filter("none", time = 1.0)
```

The flashback has to restore what it changed. Tales cannot read the current backdrop, so the last line of `flashback` shows the library again. Mark a recap beat with `@skip_safe` so skipping passes its lines even when the player skips only lines they have read.

## Branching on a visited beat

`visited("tale.beat")` is true once the player has entered that beat in the current playthrough. Write the tale name and the beat name, joined by a dot:

```gdscript
beat library_again:
	if visited("chapter_1.results"):
		mira: "Back for more? Last time you did well."
	elif visited("chapter_1.quiz"):
		mira: "You left before the end last time."
	else:
		mira: "First time here?"
```

Save slots keep the visited beats, and a new game clears them. Entering a beat marks it visited before its first line runs, so `visited()` on the beat you are in always returns true. For a first-visit greeting, test a different beat or keep a story variable.
