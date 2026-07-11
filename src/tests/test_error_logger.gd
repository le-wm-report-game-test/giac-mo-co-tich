class_name TestErrorLogger
extends Logger

var _entries: Array[Dictionary] = []
var _mutex := Mutex.new()
var _sequence: int = 0


func _log_error(
	function: String,
	file: String,
	line: int,
	code: String,
	rationale: String,
	_editor_notify: bool,
	error_type: int,
	_script_backtraces: Array[ScriptBacktrace]
) -> void:
	if error_type == Logger.ERROR_TYPE_WARNING:
		return
	_mutex.lock()
	_sequence += 1
	_entries.append({
		"sequence": _sequence,
		"function": function,
		"file": file,
		"line": line,
		"code": code,
		"message": rationale,
	})
	_mutex.unlock()


func get_cursor() -> int:
	_mutex.lock()
	var cursor := _sequence
	_mutex.unlock()
	return cursor


func get_errors_since(cursor: int) -> Array[Dictionary]:
	_mutex.lock()
	var result: Array[Dictionary] = []
	for entry in _entries:
		if int(entry.get("sequence", 0)) > cursor:
			result.append(entry.duplicate())
	_mutex.unlock()
	return result
