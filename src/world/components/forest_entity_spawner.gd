extends Node

const MAP_HALF: float = 50.0
const SPAWN_CENTER := Vector2.ZERO
const ZONE_HILL: int = 3

var _owner: Node = null
var _rng: RandomNumberGenerator = null


func setup(owner: Node, rng: RandomNumberGenerator) -> void:
	_owner = owner
	_rng = rng


func spawn_animals() -> void:
	var species: Array[Dictionary] = [
		{"type": AnimalBot.AnimalType.CAT, "count": 4, "name": "Cat"},
		{"type": AnimalBot.AnimalType.RABBIT, "count": 4, "name": "Rabbit"},
		{"type": AnimalBot.AnimalType.PARROT, "count": 4, "name": "Parrot"},
	]
	for definition in species:
		for index in range(int(definition["count"])):
			_spawn_animal(definition, index)


func spawn_orcs() -> void:
	for index in range(int(_owner.get("num_orcs"))):
		for _attempt in range(100):
			var position := _random_position()
			if position.distance_to(SPAWN_CENTER) < 8.0:
				continue
			if int(_owner.call("_get_zone", position.x, position.y)) == ZONE_HILL:
				continue
			if bool(_owner.call("_is_under_large_tree_canopy", position.x, position.y)):
				continue
			var orc := OrcMob.new()
			orc.position = Vector3(position.x, 0.2, position.y)
			orc.name = "OrcMob_%d" % index
			_owner.add_child(orc)
			break


func _spawn_animal(definition: Dictionary, index: int) -> void:
	for _attempt in range(100):
		var position := _random_position()
		if position.distance_to(SPAWN_CENTER) < 6.0:
			continue
		if int(_owner.call("_get_zone", position.x, position.y)) == ZONE_HILL:
			continue
		var animal := AnimalBot.new()
		animal.animal_type = definition["type"] as AnimalBot.AnimalType
		animal.speed = _rng.randf_range(1.0, 1.8)
		animal.position = Vector3(position.x, 0.2, position.y)
		animal.name = "%sBot_%d" % [str(definition["name"]), index]
		animal.collision_layer = 16
		animal.collision_mask = 1
		_owner.add_child(animal)
		break


func _random_position() -> Vector2:
	return Vector2(
		_rng.randf_range(-MAP_HALF + 5.0, MAP_HALF - 5.0),
		_rng.randf_range(-MAP_HALF + 5.0, MAP_HALF - 5.0)
	)
