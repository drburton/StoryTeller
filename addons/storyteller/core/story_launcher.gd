class_name StoryLauncher
extends Node
## Starts a story with its own [StoryConfig] when its scene runs, so a
## project can hold more than one story. Put it in a scene, set
## [member config], and press F6 (Run Current Scene) to play that story.
## [b]Open a Studio story[/b] makes a scene like this for each story it adds.

## The story's config. Empty uses the project's config.
@export var config: StoryConfig
## Opens the title screen; otherwise the story starts at once.
@export var show_title := true


func _ready() -> void:
	var story := get_node("/root/Story")
	var chosen: StoryConfig = config if config != null else story.load_config()
	story.start(chosen)
	if show_title:
		story.show_title()
	else:
		story.play(chosen.start_tale)
