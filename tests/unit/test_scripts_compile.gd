extends "res://tests/framework/story_test.gd"
## Loads every GDScript in the addon and the test folders, so a syntax error
## fails the run even when no test uses the broken file.

const ROOTS := ["res://addons/storyteller", "res://tests"]


func test_all_scripts_compile() -> void:
	var paths: PackedStringArray = []
	for root in ROOTS:
		_collect(root, paths)
	assert_true(paths.size() > 0, "found scripts to check")
	for path in paths:
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			fail("%s does not compile" % path)


func _collect(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_collect(dir_path.path_join(sub), out)
	for file in dir.get_files():
		if file.ends_with(".gd"):
			out.append(dir_path.path_join(file))
