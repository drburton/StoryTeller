extends "res://tests/framework/story_test.gd"
## Tests for background loads started by the look-ahead: each one must be
## collected, or Godot reports it as a leaked object when the game quits.

const StoryScript := preload("res://addons/storyteller/core/story.gd")
const ROOT := "user://test_preloads"


func before_each() -> void:
	super()
	StoryAssets.finish_preloads()
	DirAccess.make_dir_recursive_absolute(ROOT)


func after_each() -> void:
	StoryAssets.finish_preloads()
	for file_name in DirAccess.get_files_at(ROOT):
		DirAccess.remove_absolute(ROOT.path_join(file_name))
	super()


## A resource file nothing has loaded yet, with a new name each time so it
## is never in Godot's cache.
func _new_resource() -> String:
	var path := ROOT.path_join("gradient_%d.tres" % Time.get_ticks_usec())
	ResourceSaver.save(Gradient.new(), path)
	return path


func test_using_a_preloaded_asset_collects_its_load() -> void:
	var path := _new_resource()
	StoryAssets.preload_path(path)
	assert_eq(StoryAssets.pending_preloads(), 1)
	assert_true(StoryAssets.load_path(path) is Gradient)
	assert_eq(StoryAssets.pending_preloads(), 0)


func test_preloading_twice_starts_one_load() -> void:
	var path := _new_resource()
	StoryAssets.preload_path(path)
	StoryAssets.preload_path(path)
	assert_eq(StoryAssets.pending_preloads(), 1)


func test_unused_preloads_are_collected_when_the_story_shuts_down() -> void:
	var config := StoryConfig.new()
	config.crew = [TaleDirector]
	var story: Node = track(StoryScript.new())
	story.start(config)
	tree.root.add_child(story)
	StoryAssets.preload_path(_new_resource())
	StoryAssets.preload_path(_new_resource())
	assert_eq(StoryAssets.pending_preloads(), 2)
	story.shut_down()
	assert_eq(StoryAssets.pending_preloads(), 0)


func test_unused_preloads_are_collected_when_the_story_leaves_the_tree() -> void:
	var story: Node = track(StoryScript.new())
	story.start(StoryConfig.new())
	tree.root.add_child(story)
	StoryAssets.preload_path(_new_resource())
	tree.root.remove_child(story)
	assert_eq(StoryAssets.pending_preloads(), 0)
