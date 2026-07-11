# terrain_heightmap.gd
# Generates a continuous heightmap-based ground that the player can climb.
# Replaces the old 1m x 1m modular tile grid that created vertical step walls
# the player capsule (radius 0.4m) could not ascend.
#
# Architecture decisions:
# - Visual ground is a single dense ArrayMesh for smooth shading.
# - Collision is split: one BoxShape3D covering the whole map at Y=0 (the
#   player can never fall through the world on flat terrain) plus one
#   ConcavePolygonShape3D per hill, built from a small localised fan mesh.
#   This avoids the Jolt Physics cost of a single 10k+ triangle trimesh and
#   keeps each hill's compile time in the millisecond range.
# - Heights are sampled from a single formula reused by player visuals,
#   tests and the collision meshes so the surface is consistent everywhere.
class_name TerrainHeightmap
extends Node3D

const VISUAL_DIVISIONS_PER_METER: int = 2  # 0.5m per cell: smooth shading
const MAP_HALF: float = 50.0
const FLAT_HEIGHT: float = 0.0

# Public sampling reused by other systems (player snap, animation, tests).
static func sample_height(x: float, z: float, hill_zones: Array) -> float:
	var p := Vector2(x, z)
	var max_h: float = FLAT_HEIGHT
	for zone_data in hill_zones:
		var c: Vector2 = zone_data["center"]
		var r: float = zone_data["radius"]
		var h: float = zone_data["height"]
		var dist: float = p.distance_to(c)
		if dist < r:
			var t: float = 1.0 - (dist / r)
			var hill_h: float = h * t * t
			if hill_h > max_h:
				max_h = hill_h
				
	# Áp dụng lòng hồ nước (giảm độ cao xuống tạo lòng chảo thoải tự nhiên)
	var c := Vector2(24.0, -24.0)
	var dist_to_lake := p.distance_to(c)
	var angle := atan2(p.y - c.y, p.x - c.x)
	var perturbed_radius := 8.0 + 2.0 * sin(angle * 3.0) + 1.2 * cos(angle * 5.0)
	if dist_to_lake < perturbed_radius:
		var t := dist_to_lake / perturbed_radius
		max_h += -1.8 * (1.0 - t * t) # Độ sâu tối đa 1.8m ở tâm hồ
		
	return max_h

# Returns a Dictionary with:
#   - mesh: ArrayMesh for the visual ground (dense, smooth-shaded)
#   - flat_collision_shape: BoxShape3D covering the whole map at Y≈0
#   - hill_collision_meshes: Array[ArrayMesh], one per hill. Each is small
#       enough to convert into a ConcavePolygonShape3D quickly.
#   - hill_collision_centers: Array[Vector3], matching index to hill mesh
#   - subdivisions / size_meters: grid info for callers that need it
func build(hill_zones: Array, zone_sampler: Callable) -> Dictionary:
	var size_meters: float = MAP_HALF * 2.0
	var visual_subdivisions: int = int(size_meters * VISUAL_DIVISIONS_PER_METER)
	var visual_step: float = size_meters / visual_subdivisions

	# Sample the visual-resolution height field once.
	var visual_heights := PackedFloat32Array()
	visual_heights.resize(visual_subdivisions * visual_subdivisions)
	for j in range(visual_subdivisions):
		for i in range(visual_subdivisions):
			var x: float = -MAP_HALF + (float(i) + 0.5) * visual_step
			var z: float = MAP_HALF - (float(j) + 0.5) * visual_step
			visual_heights[j * visual_subdivisions + i] = sample_height(x, z, hill_zones)

	# Visual mesh: dense, smooth-shaded, with analytic normals.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(visual_subdivisions - 1):
		for i in range(visual_subdivisions - 1):
			_emit_vert(st, i, j, visual_subdivisions, hill_zones, visual_heights, zone_sampler)
			_emit_vert(st, i + 1, j + 1, visual_subdivisions, hill_zones, visual_heights, zone_sampler)
			_emit_vert(st, i + 1, j, visual_subdivisions, hill_zones, visual_heights, zone_sampler)
			_emit_vert(st, i, j, visual_subdivisions, hill_zones, visual_heights, zone_sampler)
			_emit_vert(st, i, j + 1, visual_subdivisions, hill_zones, visual_heights, zone_sampler)
			_emit_vert(st, i + 1, j + 1, visual_subdivisions, hill_zones, visual_heights, zone_sampler)
	var ground_mesh: ArrayMesh = st.commit()

	# Flat collision: keeps the player from falling through the world on the
	# 99% of the map that is genuinely flat. The box top sits at Y=0 so flat
	# terrain reads as Y=0 (matches the heightmap baseline) and the player
	# capsule rests at Y = capsule radius (0.4).
	var flat_box := BoxShape3D.new()
	flat_box.size = Vector3(size_meters, 1.0, size_meters)

	# Per-hill collision meshes. Each one is a fan + skirt around the hill's
	# disc so the player capsule can climb onto the slope from any direction.
	var hill_meshes: Array[ArrayMesh] = []
	var hill_centers: Array[Vector3] = []
	for zone_data in hill_zones:
		var center_v2: Vector2 = zone_data["center"]
		var radius: float = zone_data["radius"]
		hill_meshes.append(_build_hill_collision_mesh(
			Vector3(center_v2.x, 0.0, center_v2.y),
			radius,
			hill_zones,
			8  # 8 radial segments per hill → ~32 triangles, instant compile
		))
		hill_centers.append(Vector3(center_v2.x, 0.0, center_v2.y))

	return {
		"mesh": ground_mesh,
		"flat_collision_shape": flat_box,
		"hill_collision_meshes": hill_meshes,
		"hill_collision_centers": hill_centers,
		"subdivisions": visual_subdivisions,
		"size_meters": size_meters,
	}

# Emits one vertex at grid (i, j) with analytic normal computed from the
# neighbouring heightmap samples. Y matches the collision surface exactly.
func _emit_vert(
	st: SurfaceTool,
	i: int,
	j: int,
	subdivisions: int,
	hill_zones: Array,
	heights: PackedFloat32Array,
	zone_sampler: Callable
) -> void:
	var size_meters: float = MAP_HALF * 2.0
	var cell: float = size_meters / subdivisions
	var x: float = -MAP_HALF + (float(i) + 0.5) * cell
	var z: float = MAP_HALF - (float(j) + 0.5) * cell
	var y: float = sample_height(x, z, hill_zones)

	# Central differences on the heightmap for a smooth normal.
	var hL: float = _safe_height(heights, i - 1, j, subdivisions)
	var hR: float = _safe_height(heights, i + 1, j, subdivisions)
	var hD: float = _safe_height(heights, i, j - 1, subdivisions)
	var hU: float = _safe_height(heights, i, j + 1, subdivisions)
	var slope_x: float = (hR - hL) / (2.0 * cell)
	var slope_z: float = (hU - hD) / (2.0 * cell)
	var normal: Vector3 = Vector3(-slope_x, 1.0, -slope_z).normalized()

	st.set_uv(Vector2(float(i) / (subdivisions - 1), float(j) / (subdivisions - 1)))
	
	# Thiết lập màu đỉnh (Vertex Color) để trộn chất liệu
	var color := Color(0.0, 0.0, 0.0, 1.0)
	var zone: int = int(zone_sampler.call(x, z))
	
	# PATH = 2 (Đỏ)
	if zone == 2:
		color.r = 1.0
	# CLEARING = 1 (Xanh lá)
	elif zone == 1:
		color.g = 1.0
		
	# Độ sâu lòng hồ nước -> nạp vào kênh Blue (COLOR.b)
	var dist_to_lake := Vector2(x, z).distance_to(Vector2(24.0, -24.0))
	if dist_to_lake < 8.0:
		color.b = 1.0 - (dist_to_lake / 8.0)

	st.set_color(color)
	st.set_normal(normal)
	st.add_vertex(Vector3(x, y, z))

func _safe_height(heights: PackedFloat32Array, i: int, j: int, subdivisions: int) -> float:
	var ci: int = clampi(i, 0, subdivisions - 1)
	var cj: int = clampi(j, 0, subdivisions - 1)
	return heights[cj * subdivisions + ci] if cj * subdivisions + ci < heights.size() else 0.0

# Builds a small fan-shaped mesh covering only the disc around `center` with
# the given `radius`. The fan is suitable for converting into a
# ConcavePolygonShape3D — ~30 triangles per hill instead of thousands.
func _build_hill_collision_mesh(
	center: Vector3,
	radius: float,
	hill_zones: Array,
	radial_segments: int
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var peak_y: float = sample_height(center.x, center.z, hill_zones)
	var peak: Vector3 = Vector3(center.x, peak_y, center.z)

	# Ring of vertices at the hill's outer radius, each at the heightmap height.
	var ring: Array[Vector3] = []
	for k in range(radial_segments):
		var angle: float = TAU * float(k) / float(radial_segments)
		var rx: float = center.x + cos(angle) * radius
		var rz: float = center.z + sin(angle) * radius
		var ry: float = sample_height(rx, rz, hill_zones)
		ring.append(Vector3(rx, ry, rz))

	# Top fan: peak → ring[k] → ring[k+1]. This is the climbable slope.
	for k in range(radial_segments):
		var a: Vector3 = ring[k]
		var b: Vector3 = ring[(k + 1) % radial_segments]
		st.add_vertex(peak)
		st.add_vertex(a)
		st.add_vertex(b)

	# Outer skirt: ring vertex at height → Y=0 → neighbour at Y=0 → neighbour
	# at height. Without this the capsule could squeeze under the hill rim
	# when standing just outside the radius.
	for k in range(radial_segments):
		var a: Vector3 = ring[k]
		var b: Vector3 = ring[(k + 1) % radial_segments]
		var a_base: Vector3 = Vector3(a.x, FLAT_HEIGHT, a.z)
		var b_base: Vector3 = Vector3(b.x, FLAT_HEIGHT, b.z)
		st.add_vertex(a_base)
		st.add_vertex(b)
		st.add_vertex(a)
		st.add_vertex(a_base)
		st.add_vertex(b_base)
		st.add_vertex(b)

	return st.commit()