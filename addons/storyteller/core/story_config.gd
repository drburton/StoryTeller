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
@export var crew: Array[Script] = []

## Folder that holds the project's tales.
@export_dir var tales_folder := "res://story/tales"
