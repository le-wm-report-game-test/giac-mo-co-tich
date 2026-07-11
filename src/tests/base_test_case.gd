# res://src/tests/base_test_case.gd
extends RefCounted
class_name BaseTestCase

# Base class for E2E test cases managing scene isolation and assertions
# Technical comments in English, Vietnamese for game logic explanations.

const WORLD_SCENE_PATH: String = "res://src/world/world.tscn"

var tree: SceneTree = null
var failed: bool = false
var fail_reason: String = ""
var world_instance: Node3D = null

func setup() -> void:
	_reset_global_test_state()
	_free_stale_worlds()
	var world_scene := load(WORLD_SCENE_PATH) as PackedScene
	if not world_scene:
		fail("Cannot load world.tscn")
		return
	world_instance = world_scene.instantiate() as Node3D
	world_instance.add_to_group("e2e_test_world")
	tree.root.add_child(world_instance)
	await wait_physics_frames(2)

func teardown() -> void:
	# Synchronous removal prevents stale group lookups in the next test.
	if is_instance_valid(world_instance):
		world_instance.free()
	world_instance = null
	_free_stale_worlds()
	_reset_global_test_state()
	await wait_physics_frames(2)

func _free_stale_worlds() -> void:
	if tree == null:
		return
	for child: Node in tree.root.get_children():
		if not is_instance_valid(child):
			continue
		if child.is_in_group("e2e_test_world") or child.scene_file_path == WORLD_SCENE_PATH:
			child.free()

func _reset_global_test_state() -> void:
	if tree != null:
		tree.paused = false
	Engine.time_scale = 1.0

func fail(reason: String) -> void:
	if failed: return
	failed = true
	fail_reason = reason

func wait_physics_frames(frames: int) -> void:
	# Chờ một số lượng khung hình vật lý để Jolt Physics xử lý va chạm
	for i in range(frames):
		await tree.process_frame

func assert_true(condition: bool, msg: String) -> void:
	if not condition:
		fail("Assertion failed: %s (Expected true, got false)" % msg)

func assert_false(condition: bool, msg: String) -> void:
	if condition:
		fail("Assertion failed: %s (Expected false, got true)" % msg)

func assert_eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual != expected:
		fail("Assertion failed: %s (Expected %s, got %s)" % [msg, str(expected), str(actual)])

func assert_ne(actual: Variant, expected: Variant, msg: String) -> void:
	if actual == expected:
		fail("Assertion failed: %s (Expected different, both are %s)" % [msg, str(actual)])

func assert_not_null(val: Variant, msg: String) -> void:
	if val == null:
		fail("Assertion failed: %s (Expected non-null value)" % msg)

func assert_null(val: Variant, msg: String) -> void:
	if val != null:
		fail("Assertion failed: %s (Expected null value, got %s)" % [msg, str(val)])

func assert_almost_eq(actual: float, expected: float, tolerance: float, msg: String) -> void:
	# Rất quan trọng khi kiểm tra tọa độ vật lý có sai số nhỏ
	if absf(actual - expected) > tolerance:
		fail("Assertion failed: %s (Expected %f within %f, got %f)" % [msg, expected, tolerance, actual])
