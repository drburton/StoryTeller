@tool
class_name StoryConfig
extends Resource
## Project-wide settings for StoryTeller.
##
## A project keeps one of these at the path stored in the
## [code]storyteller/config_path[/code] project setting. When no file exists,
## StoryTeller runs with the defaults defined here.

## Default location of the project's config resource.
const DEFAULT_PATH := "res://story/story_config.tres"

## Crew member scripts to create when the story starts, in order.
## Each script must extend [StoryCrew].
@export var crew: Array[Script] = [
	preload("res://addons/storyteller/director/tale_director.gd"),
	preload("res://addons/storyteller/stage/story_stage.gd"),
	preload("res://addons/storyteller/audio/story_audio.gd"),
	preload("res://addons/storyteller/saves/story_saves.gd"),
	preload("res://addons/storyteller/saves/story_settings.gd"),
	preload("res://addons/storyteller/rewind/story_rewind.gd"),
	preload("res://addons/storyteller/rewind/story_history.gd"),
	preload("res://addons/storyteller/ui/story_dialogue.gd"),
	preload("res://addons/storyteller/menus/story_menus.gd"),
]

## Folder that holds the project's tales.
@export_dir var tales_folder := "res://story/tales"

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

@export_group("Stage")
## Folder with cast members: "<id>.tres" profiles or "<id>/" image folders.
@export_dir var cast_folder := "res://story/cast"
## Dim cast members who are not speaking.
@export var highlight_speaker := true
## Folder with backdrop images, used by backdrop("name").
@export_dir var backdrop_folder := "res://story/backdrops"
## Folder with prop images and scenes, used by prop("name").
@export_dir var prop_folder := "res://story/props"

@export_group("Audio")
## Folder with "music", "sounds", "ambience", and "voice" subfolders.
@export_dir var audio_folder := "res://story/audio"

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
## Numbered slots on the save and load screens.
@export_range(1, 60) var save_slot_count := 9

@export_group("Dialogue")
## Scene for the dialogue box (its root must extend [DialogueBox]).
## Empty uses the built-in classic box.
@export var dialogue_box_scene: PackedScene
## Scene for the choice menu (its root must extend [ChoiceMenu]).
## Empty uses the built-in list menu.
@export var choice_menu_scene: PackedScene
## Typing speed in characters per second. 0 shows text instantly.
@export_range(0, 200, 1) var text_speed := 40.0
## Extra dialogue styles by name, or replacements for "classic" and "page".
## Each scene's root must extend [DialogueBox].
@export var dialogue_styles: Dictionary[String, PackedScene] = {}
## Show the row of buttons (History, Skip, Auto, Save, ...) above the
## dialogue box.
@export var show_quick_menu := true
