# proposed_base_test_case.gd
extends RefCounted
class_name BaseTestCase

# Lớp cơ sở cho các test cases E2E trong Giac Mo Co Tich
# Technical comments in English, Vietnamese for game logic explanations.

var tree: SceneTree = null
var failed: bool = false
var fail_reason: String = ""
var world_instance: Node3D = null

func setup() -> void:
	# Khởi tạo game world cho mỗi test case độc lập
	var world_scene := load("res://src/world/world.tscn") as PackedScene
	if not world_scene:
		fail("Cannot load world.tscn")
		return
	world_instance = world_scene.instantiate() as Node3D
	tree.root.add_child(world_instance)
	
	# Đợi 2 frame để đảm bảo các node con _ready() hoàn tất
	await tree.process_frame
	await tree.process_frame

func teardown() -> void:
	# Dọn dẹp game world sau khi test xong để đảm bảo tính cô lập
	if is_instance_valid(world_instance):
		world_instance.queue_free()
		world_instance = null
	await tree.process_frame
	await tree.process_frame

func fail(reason: String) -> void:
	failed = true
	fail_reason = reason

func assert_true(condition: bool, msg: String) -> void:
	if not condition:
		fail("Assertion failed: %s (Expected true, got false)" % msg)

func assert_false(condition: bool, msg: String) -> void:
	if condition:
		fail("Assertion failed: %s (Expected false, got true)" % msg)

func assert_eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual != expected:
		fail("Assertion failed: %s (Expected %s, got %s)" % [msg, str(expected), str(actual)])

func assert_not_null(val: Variant, msg: String) -> void:
	if val == null:
		fail("Assertion failed: %s (Expected non-null value)" % msg)
