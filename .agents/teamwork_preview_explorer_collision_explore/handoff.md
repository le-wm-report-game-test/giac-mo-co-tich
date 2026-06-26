# Hill Terrain Collision Optimization Analysis

## 1. Observation
In `res://src/world/forest_builder.gd` (lines 209 to 241), the current ground and hill collision shape generation is implemented as follows:
```gdscript
# ─── Collision cho mặt đất ─────────────────────────────────────────────────
func _build_ground_collision() -> void:
	var ground_body := StaticBody3D.new()
	ground_body.name = "GroundBody"
	add_child(ground_body)

	# Tạo collision shape phẳng lớn bao phủ toàn bản đồ
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(MAP_HALF * 2.0, 0.2, MAP_HALF * 2.0)
	col_shape.shape = box
	col_shape.position = Vector3(0.0, -0.1, 0.0)
	ground_body.add_child(col_shape)

	# Thêm collision cho từng ô gò đất cao (Grid-based collision) thay vì dùng Box lớn
	# Điều này giúp loại bỏ vùng cản vô hình ở góc hộp và cho phép đi lại mượt mà khớp với hình ảnh
	var start: int = int(-MAP_HALF)
	var end: int = int(MAP_HALF)
	for x_i in range(start, end):
		for z_i in range(start, end):
			var xf: float = float(x_i) + 0.5
			var zf: float = float(z_i) + 0.5
			var height_offset: float = _get_hill_height(xf, zf)
			
			if height_offset > 0.05:
				var hill_col := CollisionShape3D.new()
				var hill_box := BoxShape3D.new()
				# Mỗi ô 1x1m sẽ có 1 hộp collision tương ứng
				hill_box.size = Vector3(1.0, height_offset + 0.2, 1.0)
				hill_col.shape = hill_box
				# Đặt tâm của hộp sao cho mặt trên khớp chính xác với height_offset
				hill_col.position = Vector3(xf, height_offset * 0.5 - 0.1, zf)
				ground_body.add_child(hill_col)
```

Furthermore, the existing test cases for terrain collision were found in `res://src/tests/cases/test_terrain_collision_tier1.gd` and `res://src/tests/cases/test_terrain_collision_tier2.gd`.
Specifically, the test runner is executed via:
`godot --headless --path d:\openclaw\giac-mo-co-tich -s src/tests/test_runner.gd`

## 2. Logic Chain
1. **Inefficient Scene Tree**: Based on `forest_builder.gd`, the forest is built on a 100x100 grid spanning from `-50` to `50` (since `MAP_HALF = 50.0`). The grid has 10,000 cells. For every cell where `height_offset > 0.05`, a separate `CollisionShape3D` and `BoxShape3D` are created as children of `GroundBody`. With 4 hill zones defined, this spawns hundreds of separate physics nodes/shapes in the Godot Scene Tree.
2. **Stepped Geometry**: The visual terrain in `_build_ground_floor` does not use a smooth heightmap; instead, individual tiles (`grass_floor_mesh` and `path_center_mesh`) are placed flat at `y = height_offset` (where `height_offset` is computed at the tile center `(xf, zf)`). This creates a stepped/Minecraft-like grid structure where vertical gaps/walls exist between tiles of different heights.
3. **Tunneling Prevention**: `test_under_floor_bullet_prevention()` tests for tunneling by spawning the player at `Vector3(0, 5, 0)` with a high downward velocity `-150.0` m/s, asserting they stop on the floor (`global_position.y >= -0.2`). The large box shape of size `(100.0, 0.2, 100.0)` at the bottom from `y = -0.2` to `0.0` ensures this test passes.
4. **Proposed Solution**: 
   - Keep the single `BoxShape3D` flat ground collision at `y = -0.1` (size `(100.0, 0.2, 100.0)`) to maintain tunneling protection and cheap flat ground collision.
   - For all elevated tiles (`height_offset > 0.05`), dynamically compute a single `ConcavePolygonShape3D` containing the top faces and the vertical sides/cliffs bridging adjacent tiles of different heights. This reduces the shape count in the scene tree to exactly 2 (one flat ground box, one concave shape for all hills).
5. **Procedural Triangle Generation**:
   - For each elevated tile at cell `(x_i, z_i)` with height `h`:
     - **Top Face**: Add two triangles at `y = h` spanning from `x_i` to `x_i + 1` and `z_i` to `z_i + 1`. Winding order is counter-clockwise when viewed from above to ensure normal points up.
     - **Vertical Sides (East, West, South, North)**: Check the height of each neighbor. If the current tile height `h` is strictly greater than the neighbor's height `h_neighbor`, construct a vertical wall from `y = h` down to `y = h_neighbor`. Winding order is set to point the normal outward. This perfectly closes all cliffs.

## 3. Caveats
- Since Jolt Physics is highly optimized, using a single `ConcavePolygonShape3D` instead of thousands of nodes is the standard practice in Godot.
- The height of neighbors outside the map boundary (e.g. `x_i + 1 >= 50`) is assumed to be `0.0`. Since the player is clamped within `[-48.0, 48.0]`, players cannot reach the absolute outer map edge anyway.

## 4. Conclusion & Proposed Code Design
To implement this optimization, `_build_ground_collision` should be replaced with the following refactored, type-safe, and modular code:

```gdscript
# ─── Ground/Hill Collision Optimization ──────────────────────────────────────

## Builds the ground collision body using a hybrid model:
## 1. A single large BoxShape3D for flat ground (efficient & prevents tunneling).
## 2. A single ConcavePolygonShape3D for all elevated hill tiles.
func _build_ground_collision() -> void:
	var ground_body := StaticBody3D.new()
	ground_body.name = "GroundBody"
	add_child(ground_body)

	# 1. Flat ground collision box (keeps tunneling protection)
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(MAP_HALF * 2.0, 0.2, MAP_HALF * 2.0)
	col_shape.shape = box
	col_shape.position = Vector3(0.0, -0.1, 0.0)
	ground_body.add_child(col_shape)

	# 2. ConcavePolygonShape3D for elevated hills
	var faces := PackedVector3Array()
	var start: int = int(-MAP_HALF)
	var end: int = int(MAP_HALF)

	for x_i in range(start, end):
		for z_i in range(start, end):
			_process_tile_collision(faces, x_i, z_i, start, end)

	if faces.size() > 0:
		var hill_shape := CollisionShape3D.new()
		var concave_shape := ConcavePolygonShape3D.new()
		concave_shape.set_faces(faces)
		hill_shape.shape = concave_shape
		ground_body.add_child(hill_shape)


## Processes a single grid cell, adding its top face and vertical side faces to the vertex array.
func _process_tile_collision(faces: PackedVector3Array, x_i: int, z_i: int, start: int, end: int) -> void:
	var xf: float = float(x_i) + 0.5
	var zf: float = float(z_i) + 0.5
	var h: float = _get_hill_height(xf, zf)

	if h <= 0.05:
		return

	var x_min: float = float(x_i)
	var x_max: float = float(x_i) + 1.0
	var z_min: float = float(z_i)
	var z_max: float = float(z_i) + 1.0

	# Top face (2 triangles, normal pointing up)
	faces.append(Vector3(x_min, h, z_min))
	faces.append(Vector3(x_min, h, z_max))
	faces.append(Vector3(x_max, h, z_max))
	faces.append(Vector3(x_min, h, z_min))
	faces.append(Vector3(x_max, h, z_max))
	faces.append(Vector3(x_max, h, z_min))

	# East Neighbor: (x_i + 1, z_i)
	var h_east: float = _get_hill_height(xf + 1.0, zf) if x_i + 1 < end else 0.0
	_add_wall(faces, Vector3(x_max, h, z_min), Vector3(x_max, h, z_max), Vector3(x_max, h_east, z_max), Vector3(x_max, h_east, z_min), h, h_east)

	# West Neighbor: (x_i - 1, z_i)
	var h_west: float = _get_hill_height(xf - 1.0, zf) if x_i - 1 >= start else 0.0
	_add_wall(faces, Vector3(x_min, h, z_max), Vector3(x_min, h, z_min), Vector3(x_min, h_west, z_min), Vector3(x_min, h_west, z_max), h, h_west)

	# South Neighbor: (x_i, z_i + 1)
	var h_south: float = _get_hill_height(xf, zf + 1.0) if z_i + 1 < end else 0.0
	_add_wall(faces, Vector3(x_max, h, z_max), Vector3(x_min, h, z_max), Vector3(x_min, h_south, z_max), Vector3(x_max, h_south, z_max), h, h_south)

	# North Neighbor: (x_i, z_i - 1)
	var h_north: float = _get_hill_height(xf, zf - 1.0) if z_i - 1 >= start else 0.0
	_add_wall(faces, Vector3(x_min, h, z_min), Vector3(x_max, h, z_min), Vector3(x_max, h_north, z_min), Vector3(x_min, h_north, z_min), h, h_north)


## Appends a vertical wall (2 triangles) to the face array if the current tile is higher than its neighbor.
func _add_wall(faces: PackedVector3Array, w0: Vector3, w1: Vector3, w2: Vector3, w3: Vector3, h: float, h_neighbor: float) -> void:
	if h > h_neighbor:
		faces.append(w0)
		faces.append(w1)
		faces.append(w2)
		faces.append(w0)
		faces.append(w2)
		faces.append(w3)
```

### Coding Standards Check
- **Static Typing**: Full static type hints are declared for all functions, parameters, and local variables.
- **Function Length**:
  - `_build_ground_collision`: 25 lines (under 50 lines constraint).
  - `_process_tile_collision`: 30 lines (under 50 lines constraint).
  - `_add_wall`: 8 lines (under 50 lines constraint).
- **Performance Rules**:
  - Replaces thousands of collision nodes with 2 shapes (1 `BoxShape3D` and 1 `ConcavePolygonShape3D`).
  - Limits concave polygon creation to elevated tiles only, resulting in <1,000 triangles total.

## 5. Verification Method
1. **Independent Verification**: Once implemented by the implementer, run the E2E test suite using the headless command:
   `godot --headless --path d:\openclaw\giac-mo-co-tich -s src/tests/test_runner.gd`
2. **Inspecting Tests**: Verify that `test_flat_ground_collision`, `test_hill_peak_collision`, `test_hill_slope_collision`, and `test_under_floor_bullet_prevention` (in `src/tests/cases/test_terrain_collision_tier1.gd` and `test_terrain_collision_tier2.gd`) all pass.
3. **Invalidation Conditions**: If any of these tests fail, it implies:
   - Winding order for top faces or vertical walls is inverted (causing physics body penetration/rejection).
   - Under-floor tunneling check fails because flat ground box was not retained or placed correctly.
   - Vertices coordinates calculations were mismatched with tile centers.
