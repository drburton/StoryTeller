@tool
class_name StoryConfig
extends Resource
## Project-wide settings for StoryTeller.
##
## A project keeps one of these at the path stored in the
## [code]storyteller/config_path[/code] project setting. When no file exists,
## StoryTeller runs with the defaults defined here.

## A config with only what conversations need: the director, audio, saves,
## settings, history, and the dialogue box. For games that add dialogue to
## their own 2D or 3D scenes without StoryTeller's stage and menus.
## [codeblock]
## var config := StoryConfig.dialogue_only()
## config.tales_folder = "res://dialogue"
## Story.start(config)
## [/codeblock]
static func dialogue_only() -> StoryConfig:
	var config := StoryConfig.new()
	config.crew = [
		preload("res://addons/storyteller/director/tale_director.gd"),
		preload("res://addons/storyteller/audio/story_audio.gd"),
		preload("res://addons/storyteller/saves/story_saves.gd"),
		preload("res://addons/storyteller/saves/story_settings.gd"),
		preload("res://addons/storyteller/rewind/story_history.gd"),
		preload("res://addons/storyteller/ui/story_dialogue.gd"),
	]
	config.autosave_on_choice = false
	config.show_quick_menu = false
	return config


## One instance of each script in [param scripts] that extends
## [TaleAction], as listed in [member actions]. Others are skipped with a
## warning.
static func make_actions(scripts: Array[Script]) -> Array[TaleAction]:
	var made: Array[TaleAction] = []
	for script in scripts:
		var action: Variant = script.new() if script != null and script.can_instantiate() else null
		if action is TaleAction and not action.get_action_name().is_empty():
			made.append(action)
		else:
			push_warning("StoryTeller: %s is not a TaleAction with a name." % (script.resource_path if script != null else "An empty entry in StoryConfig.actions"))
	return made


## The scripts in [member actions], then every script in
## [member action_folder] that extends [TaleAction] and is not listed.
func get_action_scripts() -> Array[Script]:
	var scripts: Array[Script] = actions.duplicate()
	if action_folder.is_empty() or not DirAccess.dir_exists_absolute(action_folder):
		return scripts
	var names := Array(ResourceLoader.list_directory(action_folder))
	names.sort()
	for file_name in names:
		if file_name.get_extension() != "gd":
			continue
		var script := load(action_folder.path_join(file_name)) as Script
		if script == null or script in scripts or not script.can_instantiate():
			continue
		var base := script
		while base != null and base != TaleAction:
			base = base.get_base_script()
		if base == TaleAction:
			scripts.append(script)
	return scripts


## Default location of the project's config resource.
const DEFAULT_PATH := "res://story/story_config.tres"

## Scripts of custom actions (each extends [TaleAction]) that tales can
## call, in addition to the built-in ones. The Story tab knows them too, so
## tales that use them check cleanly and get card forms.
@export var actions: Array[Script] = []
## Folder of custom action scripts. Each script in it that extends
## [TaleAction] is added like those in [member actions], so new actions
## only need to be saved there.
@export_dir var action_folder := "res://story/actions"
## Crew member scripts to create when the story starts, in order.
## Each script must extend [StoryCrew].
@export var crew: Array[Script] = [
	preload("res://addons/storyteller/director/tale_director.gd"),
	preload("res://addons/storyteller/stage/story_stage.gd"),
	preload("res://addons/storyteller/audio/story_audio.gd"),
	preload("res://addons/storyteller/effects/story_effects.gd"),
	preload("res://addons/storyteller/collection/story_collection.gd"),
	preload("res://addons/storyteller/saves/story_saves.gd"),
	preload("res://addons/storyteller/saves/story_settings.gd"),
	preload("res://addons/storyteller/rewind/story_rewind.gd"),
	preload("res://addons/storyteller/rewind/story_history.gd"),
	preload("res://addons/storyteller/ui/story_dialogue.gd"),
	preload("res://addons/storyteller/menus/story_menus.gd"),
	preload("res://addons/storyteller/debug/story_console.gd"),
]

## Folder that holds the project's tales.
@export_dir var tales_folder := "res://story/tales"
## Names that game code makes available with [code]Story.expose()[/code]
## or [code]Story.expose_function()[/code]. Listing them here lets tales
## that use them import without errors, and the Story editor suggest them.
@export var exposed_names: PackedStringArray = []

@export_group("Game")
## Title shown on the title screen. Empty uses the project name.
@export var game_title := ""
## Tale that New Game plays.
@export var start_tale := ""
## Beat that New Game starts at.
@export var start_beat := "start"
## Show the title screen again when the story ends.
@export var return_to_title := true
## Theme for dialogue boxes and menus. Empty uses StoryTeller's default look.
@export var theme: Theme
## Picture behind the title screen, covering the window. Empty uses a plain
## dark background.
@export var title_background: Texture2D
## Music track (a name from the music folder) that plays on the title
## screen. It fades out when a game starts.
@export var title_music := ""

@export_group("Stage")
## Folder with cast members: "<id>.tres" profiles or "<id>/" image folders.
@export_dir var cast_folder := "res://story/cast"
## Dim cast members who are not speaking.
@export var highlight_speaker := true
## Folder with backdrop images, used by backdrop("name").
@export_dir var backdrop_folder := "res://story/backdrops"
## Folder with prop images and scenes, used by prop("name").
@export_dir var prop_folder := "res://story/props"
## Folder with CGs, the full-screen event pictures shown by cg("name"):
## "<name>.png", or a "<name>/" folder with one image per variant.
@export_dir var cg_folder := "res://story/cgs"
## Folder with transition masks (grayscale images for
## [code]backdrop(..., mask = "name")[/code]) and [StoryTransition] files,
## which tales use by file name as transitions.
@export_dir var transition_folder := "res://story/transitions"
## Extra transitions by name, added to the built-in ones and those in
## [member transition_folder].
@export var transitions: Dictionary[String, StoryTransition] = {}

@export_group("Audio")
## Folder with "music", "sounds", "ambience", and "voice" subfolders.
@export_dir var audio_folder := "res://story/audio"

@export_group("Effects")
## Folder with movies (Ogg Theora .ogv files), used by play_movie("name").
@export_dir var movie_folder := "res://story/movies"

@export_group("Extras")
## Folder with [CollectionItem] files: gallery pictures, music room tracks,
## and codex entries unlocked with collect().
@export_dir var collection_folder := "res://story/collection"
## Show the route chart in Extras: the beats the player has reached and the
## choices they met there, with options they have not seen left out.
@export var show_route_chart := true

@export_group("Localization")
## Language the tales are written in, such as "en".
@export var source_language := "en"
## CSV file that "Export Strings" writes for translators. Godot imports it
## as one translation per language.
@export_file("*.csv") var translation_file := "res://story/translations/story.csv"
## Languages to add as columns when exporting strings, such as ["es", "fr"].
@export var languages: PackedStringArray = []

@export_group("Saves")
## Folder for save slots and the global data file.
@export var save_folder := "user://saves"
## File for player settings.
@export var settings_path := "user://settings.cfg"
## Save to the "auto" slot before every choice.
@export var autosave_on_choice := true
## How many lines and choices the player can rewind.
@export_range(0, 500) var rewind_depth := 50
## How many lines the history screen keeps.
@export_range(10, 2000) var history_size := 200
## Numbered slots on each page of the save and load screens.
@export_range(1, 60) var save_slot_count := 6
## Pages of numbered slots. 0 gives players a new page whenever they fill
## the last one.
@export_range(0, 100) var save_pages := 0
## Minutes of play between saves to the "auto" slot, made at the next line.
## 0 turns timed autosaves off.
@export_range(0, 120, 0.5, "suffix:min") var autosave_minutes := 0.0

@export_group("Dialogue")
## Scene for the dialogue box (its root must extend [DialogueBox]).
## Empty uses the built-in classic box.
@export var dialogue_box_scene: PackedScene
## Scene for the default "list" choice menu (its root must extend
## [ChoiceMenu]). Empty uses the built-in list menu.
@export var choice_menu_scene: PackedScene
## Extra choice styles by name, picked with [code]choose(style = "name")[/code],
## or a replacement for "pictures". Each scene's root must extend [ChoiceMenu].
@export var choice_styles: Dictionary[String, PackedScene] = {}
## Folder with the pictures that [code]@picture("name")[/code] names on
## choice options.
@export_dir var choice_picture_folder := "res://story/choices"
## Typing speed in characters per second. 0 shows text instantly.
@export_range(0, 200, 1) var text_speed := 40.0
## How typed text appears: letter by letter ("type"), a whole word at a
## time ("word"), or letters fading in as they type ("fade").
@export_enum("type", "word", "fade") var text_reveal := "type"
## Sound from the sounds folder played as lines type, by name, or "" for
## none. A cast profile's [member CastProfile.typing_sound] overrides it for
## that character. Lines with a voice clip stay silent.
@export var typing_sound := ""
## Characters typed between two typing sounds.
@export_range(1, 10, 1) var typing_sound_every := 3
## Extra dialogue styles by name, or replacements for "classic" and "page".
## Each scene's root must extend [DialogueBox].
@export var dialogue_styles: Dictionary[String, PackedScene] = {}
## Show the row of buttons (History, Skip, Auto, Save, ...) above the
## dialogue box.
@export var show_quick_menu := true
## How the dialogue box appears and hides: "fade", "slide" (rises from
## below while fading), or "none".
@export_enum("fade", "slide", "none") var dialogue_box_transition := "fade"
## Seconds the dialogue box takes to appear or hide.
@export_range(0.0, 2.0, 0.05) var dialogue_box_transition_time := 0.2
## Named text styles: [code][whisper]...[/whisper][/code] in a line expands
## to the BBCode given for "whisper", and its closing tags. Add your own or
## change these.
@export var text_styles: Dictionary[String, String] = {
	"whisper": "[i][color=#b4b9c8]",
	"shout": "[b][font_size=26]",
	"thought": "[i][color=#9fc4e8]",
}
