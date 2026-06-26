# proposed_test_runner.gd
extends SceneTree

# Bộ chạy thử nghiệm E2E không giao diện (headless)
# Technical comments in English, Vietnamese for game logic/runner explanations.

const TEST_DIR := "res://src/tests/cases/"

var _tests_run: int = 0
var _tests_failed: int = 0

func _initialize() -> void:
	# Khởi tạo bộ chạy kiểm thử E2E
	print("[E2E Test Runner] Initializing test suite...")
	_run_suite()

func _run_suite() -> void:
	# Quét và chạy tất cả các test cases tìm thấy trong thư mục TEST_DIR
	var dir := DirAccess.open(TEST_DIR)
	if not dir:
		print("[E2E Test Runner] ERROR: Cannot open tests directory: ", TEST_DIR)
		quit(1)
		return
		
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var test_scripts: Array[String] = []
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".gd"):
			test_scripts.append(TEST_DIR + file_name)
		file_name = dir.get_next()
		
	test_scripts.sort()
	
	for script_path in test_scripts:
		await _run_test_file(script_path)
		
	print("==================================================")
	print("[E2E Test Runner] Results: %d run, %d failed" % [_tests_run, _tests_failed])
	print("==================================================")
	
	if _tests_failed > 0:
		quit(1)
	else:
		quit(0)

func _run_test_file(path: String) -> void:
	# Tải và chạy một file kiểm thử cụ thể
	var script := load(path) as GDScript
	if not script:
		print("[E2E Test Runner] FAIL: Failed to load script: ", path)
		_tests_failed += 1
		return
		
	var test_instance = script.new() as RefCounted
	if not test_instance:
		print("[E2E Test Runner] FAIL: Failed to instantiate: ", path)
		_tests_failed += 1
		return
		
	test_instance.set("tree", self)
	_tests_run += 1
	
	print("[E2E Test Runner] Running test: ", path)
	if test_instance.has_method("setup"):
		var setup_result = test_instance.call("setup")
		if setup_result is Signal:
			await setup_result
			
	if test_instance.has_method("run"):
		var run_result = test_instance.call("run")
		if run_result is Signal:
			await run_result
			
	if test_instance.has_method("teardown"):
		var teardown_result = test_instance.call("teardown")
		if teardown_result is Signal:
			await teardown_result
			
	var failed: bool = test_instance.get("failed") as bool
	if failed:
		var reason: String = test_instance.get("fail_reason") as String
		print("  [FAIL] Reason: ", reason)
		_tests_failed += 1
	else:
		print("  [PASS]")
