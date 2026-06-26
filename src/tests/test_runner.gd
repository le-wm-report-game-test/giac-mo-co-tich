# res://src/tests/test_runner.gd
extends SceneTree

# Headless E2E Test Runner utilizing reflection for method discovery
# Technical comments in English, Vietnamese for runner logic.

const TEST_DIR := "res://src/tests/cases/"

var _tests_run: int = 0
var _tests_failed: int = 0

func _initialize() -> void:
	# Khởi tạo bộ chạy test suite E2E
	print("[E2E Test Runner] Initializing test suite...")
	await _run_suite()

func _run_suite() -> void:
	# Quét thư mục TEST_DIR để tìm tất cả các file kiểm thử .gd
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
	# Nạp script kiểm thử từ đường dẫn chỉ định
	var script := load(path) as GDScript
	if not script:
		print("[E2E Test Runner] FAIL: Failed to load script: ", path)
		_tests_failed += 1
		return
		
	var temp_instance = script.new() as RefCounted
	if not temp_instance:
		print("[E2E Test Runner] FAIL: Failed to instantiate: ", path)
		_tests_failed += 1
		return
		
	# Tìm các hàm bắt đầu bằng "test_" hoặc "scenario_"
	var test_methods: Array[String] = []
	for method_info in temp_instance.get_method_list():
		var method_name: String = method_info["name"]
		if method_name.begins_with("test_") or method_name.begins_with("scenario_"):
			test_methods.append(method_name)
	test_methods.sort()
	
	print("[E2E Test Runner] Running script: %s (%d tests)" % [path, test_methods.size()])
	
	for method_name in test_methods:
		_tests_run += 1
		print("  -> Running test: %s" % method_name)
		var success := await _run_single_test(script, method_name)
		if not success:
			_tests_failed += 1
		# Chờ 5 frames để dọn dẹp bộ nhớ vật lý
		for i in range(5):
			await process_frame

func _run_single_test(script: GDScript, method_name: String) -> bool:
	# Chạy một hàm kiểm thử cụ thể trên một thực thể mới (isolation)
	var test_instance = script.new() as RefCounted
	if not test_instance:
		print("    [FAIL] Failed to instantiate for: ", method_name)
		return false
		
	test_instance.set("tree", self)
	
	# 1. Thực thi Setup
	if test_instance.has_method("setup"):
		await test_instance.call("setup")
			
	if test_instance.get("failed") as bool:
		print("    [FAIL] Setup failed: ", test_instance.get("fail_reason"))
		return false
		
	# 2. Thực thi Hàm Kiểm Thử
	await test_instance.call(method_name)
		
	var failed: bool = test_instance.get("failed") as bool
	if failed:
		print("    [FAIL] Reason: ", test_instance.get("fail_reason"))
		
	# 3. Thực thi Teardown để dọn dẹp môi trường
	if test_instance.has_method("teardown"):
		await test_instance.call("teardown")
			
	if failed or (test_instance.get("failed") as bool):
		return false
		
	print("    [PASS]")
	return true
