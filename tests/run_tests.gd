extends SceneTree
## Headless test runner for StoryTeller.
##
## Usage:
##   godot --headless --path . -s res://tests/run_tests.gd
##   godot --headless --path . -s res://tests/run_tests.gd -- --filter=crew
##
## [code]--filter[/code] runs only suites or tests whose name contains the
## given text. Exits with code 0 when every test passes and 1 otherwise.

const TEST_ROOT := "res://tests/unit"
const StoryTest := preload("res://tests/framework/story_test.gd")
const ErrorWatcher := preload("res://tests/framework/error_watcher.gd")

var _watcher := ErrorWatcher.new()


func _initialize() -> void:
	OS.add_logger(_watcher)
	_run.call_deferred()


func _run() -> void:
	var filter := _read_filter()
	var paths: PackedStringArray = []
	_collect(TEST_ROOT, paths)
	paths.sort()

	var passed := 0
	var failed := 0
	var started := Time.get_ticks_msec()

	for path in paths:
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			print("FAIL  %s (could not load script)" % path)
			failed += 1
			continue
		var suite_name := path.get_file().get_basename()
		for method in _test_methods(script):
			if not filter.is_empty() and not (filter in suite_name or filter in method):
				continue
			_watcher.take()
			var suite: StoryTest = script.new()
			suite.tree = self
			await suite.before_each()
			await suite.call(method)
			await suite.after_each()
			var failures := suite._finish()
			failures.append_array(_watcher.take())
			if failures.is_empty():
				passed += 1
				print("ok    %s.%s" % [suite_name, method])
			else:
				failed += 1
				print("FAIL  %s.%s" % [suite_name, method])
				for failure in failures:
					print("      - %s" % failure)

	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	print("\n%d passed, %d failed (%.2fs)" % [passed, failed, seconds])
	if passed + failed == 0:
		print("No tests found.")
		failed = 1
	OS.remove_logger(_watcher)
	quit(0 if failed == 0 else 1)


func _read_filter() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			return arg.trim_prefix("--filter=")
	return ""


func _collect(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("Test folder not found: %s" % dir_path)
		return
	for sub in dir.get_directories():
		_collect(dir_path.path_join(sub), out)
	for file in dir.get_files():
		if file.begins_with("test_") and file.ends_with(".gd"):
			out.append(dir_path.path_join(file))


func _test_methods(script: GDScript) -> PackedStringArray:
	var names: PackedStringArray = []
	for info in script.get_script_method_list():
		var method_name: String = info["name"]
		if method_name.begins_with("test_") and not method_name in names:
			names.append(method_name)
	return names
