extends RefCounted
## Base class for StoryTeller test suites.
##
## A suite is a script under [code]res://tests/unit/[/code] whose file name
## starts with [code]test_[/code]. Every method whose name starts with
## [code]test_[/code] runs on a fresh instance of the suite. Test methods may
## use [code]await[/code].

## The running SceneTree, for tests that need nodes inside the tree.
var tree: SceneTree

var _failures: PackedStringArray = []
var _tracked: Array[Object] = []


## Runs before each test method.
func before_each() -> void:
	pass


## Runs after each test method.
func after_each() -> void:
	pass


## Frees [param object] automatically after the current test and returns it.
func track(object: Object) -> Variant:
	_tracked.append(object)
	return object


func fail(message: String) -> void:
	_failures.append(message)


func assert_true(condition: bool, message := "") -> void:
	if not condition:
		fail(_format_failure("expected true", message))


func assert_false(condition: bool, message := "") -> void:
	if condition:
		fail(_format_failure("expected false", message))


func assert_eq(actual: Variant, expected: Variant, message := "") -> void:
	if not _values_equal(actual, expected):
		fail(_format_failure("expected %s, got %s" % [_format_value(expected), _format_value(actual)], message))


func assert_ne(actual: Variant, unexpected: Variant, message := "") -> void:
	if _values_equal(actual, unexpected):
		fail(_format_failure("expected a value other than %s" % _format_value(unexpected), message))


func assert_null(value: Variant, message := "") -> void:
	if value != null:
		fail(_format_failure("expected null, got %s" % _format_value(value), message))


func assert_not_null(value: Variant, message := "") -> void:
	if value == null:
		fail(_format_failure("expected a value, got null", message))


func assert_has(container: Variant, value: Variant, message := "") -> void:
	if not value in container:
		fail(_format_failure("expected %s to contain %s" % [_format_value(container), _format_value(value)], message))


## Called by the runner. Returns the failures recorded by the last test.
func _finish() -> PackedStringArray:
	for object in _tracked:
		if is_instance_valid(object) and not object is RefCounted:
			if object is Node:
				# queue_free is safe even if the node is emitting a signal
				# that resumed this test.
				if object.is_inside_tree():
					object.get_parent().remove_child(object)
				object.queue_free()
			else:
				object.free()
	_tracked.clear()
	return _failures


func _values_equal(a: Variant, b: Variant) -> bool:
	var numeric := [TYPE_INT, TYPE_FLOAT]
	if typeof(a) in numeric and typeof(b) in numeric:
		return a == b
	var stringy := [TYPE_STRING, TYPE_STRING_NAME]
	if typeof(a) in stringy and typeof(b) in stringy:
		return String(a) == String(b)
	if typeof(a) != typeof(b):
		return false
	return a == b


func _format_value(value: Variant) -> String:
	if value is String:
		return '"%s"' % value
	if value is StringName:
		return '&"%s"' % value
	return str(value)


func _format_failure(problem: String, message: String) -> String:
	return problem if message.is_empty() else "%s (%s)" % [message, problem]
