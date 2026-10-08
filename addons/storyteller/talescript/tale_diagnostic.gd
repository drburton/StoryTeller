class_name TaleDiagnostic
extends RefCounted
## An error or warning found in a tale, with its location.

enum Severity { ERROR, WARNING }

var severity: Severity
var message: String
## 1-based line number.
var line: int
## 1-based column number, counted in characters.
var column: int


func _init(p_severity: Severity, p_message: String, p_line: int, p_column: int) -> void:
	severity = p_severity
	message = p_message
	line = p_line
	column = p_column


func is_error() -> bool:
	return severity == Severity.ERROR


func _to_string() -> String:
	var label := "error" if is_error() else "warning"
	return "%d:%d: %s: %s" % [line, column, label, message]
