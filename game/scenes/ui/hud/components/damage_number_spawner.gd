class_name DamageNumberSpawner
extends Node
## Pooled spawner for damage numbers.

@export var damage_number_scene: PackedScene
@export var pool_size: int = 20

var _pool: Array[DamageNumber] = []
var _pool_index: int = 0


func _ready() -> void:
	for i in range(pool_size):
		var dn: DamageNumber = damage_number_scene.instantiate()
		dn.visible = false
		add_child(dn)
		_pool.append(dn)


func spawn(world_position: Vector2, amount: int, is_critical: bool = false) -> void:
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * world_position

	var dn := _pool[_pool_index % pool_size]
	_pool_index += 1

	dn.position = screen_pos
	dn.visible = true
	dn.show_damage(amount, is_critical)