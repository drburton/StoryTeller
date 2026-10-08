class_name TaleTask
extends RefCounted
## A running action or function call that may finish later.
##
## Starting a task calls the function at once. If the function awaits
## something, the task finishes later and emits [signal finished].

signal finished

var is_done := false
## Value returned by the function once it finishes.
var result: Variant


func _init(callable: Callable, args: Array) -> void:
	_run(callable, args)


## Waits until the task finishes and returns its result.
func wait() -> Variant:
	if not is_done:
		await finished
	return result


func _run(callable: Callable, args: Array) -> void:
	result = await callable.callv(args)
	is_done = true
	finished.emit()
