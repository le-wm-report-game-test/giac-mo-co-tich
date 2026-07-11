# res://src/tests/test_runner.gd
extends SceneTree

# Headless E2E Test Runner utilizing reflection for method discovery.

const TEST_DIR := "res://src/tests/cases/"
const TEST_FILTER_ENV := "E2E_TEST_FILTER"
const TEST_METHOD_FILTER_ENV := "E2E_TEST_METHOD_FILTER"
const TestErrorLoggerScript := preload("res://src/tests/test_error_logger.gd")

var _tests_run: int = 0
var _tests_failed: int = 0
var _error_logger: TestErrorLogger = null


func _initialize() -> void:
	_error_logger = TestErrorLoggerScript.new() as TestErrorLogger
	OS.add_logger(_error_logger)
	print("[E2E Test Runner] Initializing test suite...")
	await _run_suite()


func _run_suite() -> void:
	var dir := DirAccess.open(TEST_DIR)
	if dir == null:
		print("[E2E Test Runner] ERROR: Cannot open tests directory: ", TEST_DIR)
		quit(1)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	var test_scripts: Array[String] = []
	var test_filter := OS.get_environment(TEST_FILTER_ENV).strip_edges().to_lower()
	while file_name != "":
		if (
			not dir.current_is_dir()
			and file_name.ends_with(".gd")
			and (test_filter.is_empty() or test_filter in file_name.to_lower())
		):
			test_scripts.append(TEST_DIR + file_name)
		file_name = dir.get_next()
	test_scripts.sort()

	for script_path in test_scripts:
		await _run_test_file(script_path)

	print("==================================================")
	print("[E2E Test Runner] Results: %d run, %d failed" % [_tests_run, _tests_failed])
	print("==================================================")
	quit(1 if _tests_failed > 0 else 0)


func _run_test_file(path: String) -> void:
	var script := load(path) as GDScript
	if script == null:
		print("[E2E Test Runner] FAIL: Failed to load script: ", path)
		_tests_failed += 1
		return

	var temp_instance := script.new() as RefCounted
	if temp_instance == null:
		print("[E2E Test Runner] FAIL: Failed to instantiate: ", path)
		_tests_failed += 1
		return

	var test_methods: Array[String] = []
	var method_filter := OS.get_environment(TEST_METHOD_FILTER_ENV).strip_edges().to_lower()
	for method_info in temp_instance.get_method_list():
		var method_name: String = method_info["name"]
		if (
			(method_name.begins_with("test_") or method_name.begins_with("scenario_"))
			and (method_filter.is_empty() or method_filter in method_name.to_lower())
		):
			test_methods.append(method_name)
	test_methods.sort()

	print("[E2E Test Runner] Running script: %s (%d tests)" % [path, test_methods.size()])
	for method_name in test_methods:
		_tests_run += 1
		print("  -> Running test: %s" % method_name)
		if not await _run_single_test(script, method_name):
			_tests_failed += 1
		for _frame in range(5):
			await process_frame


func _run_single_test(script: GDScript, method_name: String) -> bool:
	var test_instance := script.new() as RefCounted
	if test_instance == null:
		print("    [FAIL] Failed to instantiate for: ", method_name)
		return false

	test_instance.set("tree", self)
	var error_cursor := _error_logger.get_cursor()
	if test_instance.has_method("setup"):
		await test_instance.call("setup")

	var setup_failed := test_instance.get("failed") as bool
	var setup_errors := _error_logger.get_errors_since(error_cursor)
	if not setup_failed and setup_errors.is_empty():
		await test_instance.call(method_name)

	if test_instance.has_method("teardown"):
		await test_instance.call("teardown")

	var errors := _error_logger.get_errors_since(error_cursor)
	var failed := test_instance.get("failed") as bool
	if failed:
		print("    [FAIL] Reason: ", test_instance.get("fail_reason"))
	if not errors.is_empty():
		_print_runtime_error(errors[0])
	if failed or not errors.is_empty():
		return false

	print("    [PASS]")
	return true


func _print_runtime_error(error: Dictionary) -> void:
	var message := str(error.get("message", "")).strip_edges()
	if message.is_empty():
		message = str(error.get("code", "Unknown error"))
	print(
		"    [FAIL] Runtime error: %s (%s:%d)" % [
			message,
			str(error.get("file", "unknown")),
			int(error.get("line", 0)),
		]
	)
