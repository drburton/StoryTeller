extends Logger
## Records script errors (crashes inside GDScript) so the test runner can fail
## the test that caused them. Errors raised on purpose with push_error() are
## ignored. Logger methods can run on any thread, hence the mutex.

var _mutex := Mutex.new()
var _errors: PackedStringArray = []


func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type != ERROR_TYPE_SCRIPT:
		return
	var message := rationale if not rationale.is_empty() else code
	_mutex.lock()
	_errors.append("script error: %s (%s:%d)" % [message, file, line])
	_mutex.unlock()


## Returns the errors recorded since the last call and forgets them.
func take() -> PackedStringArray:
	_mutex.lock()
	var errors := _errors
	_errors = PackedStringArray()
	_mutex.unlock()
	return errors
