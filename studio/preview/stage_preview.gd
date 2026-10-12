class_name StudioStagePreview
extends Control
## The stage as it looks at the chosen block (docs/studio-design.md §7). The
## preview runs its own small story, a director, stage, effects, and
## dialogue box, inside a SubViewport drawn at the game's size and shown
## scaled down. Each time a block is chosen it plays the setup on the way to
## that block and then the block itself (see [StudioFromHere]). It makes no
## sound and takes no input.

## Crew of the preview's story: no audio, saves, menus, or history.
const CREW: Array[Script] = [
	preload("res://addons/storyteller/director/tale_director.gd"),
	preload("res://addons/storyteller/stage/story_stage.gd"),
	preload("res://addons/storyteller/effects/story_effects.gd"),
	preload("res://addons/storyteller/ui/story_dialogue.gd"),
]

## The preview's own story, a [code]Story[/code] node apart from the game's.
var story: Node
var viewport: SubViewport
var picture: TextureRect
var _generation := 0


func _init() -> void:
	custom_minimum_size = Vector2(320, 180)
	viewport = SubViewport.new()
	viewport.size = Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width", 1152),
		ProjectSettings.get_setting("display/window/size/viewport_height", 648))
	viewport.gui_disable_input = true
	viewport.audio_listener_enable_2d = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var frame := ColorRect.new()
	frame.color = Color.BLACK
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(frame)
	picture = TextureRect.new()
	picture.texture = viewport.get_texture()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(picture)


## Starts the preview's story with the characters, backgrounds, and dialogue
## box of [param config], again for each story opened.
func setup(config: StoryConfig) -> void:
	var preview_config := config.duplicate() as StoryConfig
	preview_config.crew = CREW
	preview_config.show_quick_menu = false
	# The block's line shows at once while the setup's fades finish.
	preview_config.wait_for_actions = false
	preview_config.mod_folder = ""
	if story == null:
		story = preload("res://addons/storyteller/core/story.gd").new()
		story.name = "PreviewStory"
		# Its own _ready would start the project's config; this one is started here.
		story.is_ready = true
		viewport.add_child(story)
	story.start(preview_config)


## Shows the stage as it is at [param target] in [param doc] (parsed from
## [param source]), the tale [param tale_name]. An empty stage when the
## target is null.
func show_at(source: String, doc: TaleDocument, tale_name: String, target: TaleNode, context: TaleCheckContext = null) -> void:
	_generation += 1
	var generation := _generation
	var director := get_director()
	if director == null:
		return
	director.stop()
	story.clear_all()
	if target == null:
		return
	var tale := StudioFromHere.compile_story(StudioFromHere.preview_source(source, doc, target), tale_name, context)
	if tale == null or generation != _generation:
		return
	director.add_tale(tale)
	await director.play(tale_name, StudioFromHere.PREVIEW_BEAT)


func get_director() -> TaleDirector:
	return story.get_crew(&"TaleDirector") as TaleDirector if story != null else null


## Stops the preview while the story plays full screen, and starts it again.
func set_paused(paused: bool) -> void:
	if paused:
		var director := get_director()
		if director != null:
			director.stop()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if paused else SubViewport.UPDATE_ALWAYS
	if story != null:
		story.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
