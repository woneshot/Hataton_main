extends Node3D

var object_scene = preload("res://scenes/objects/Enviroment/Grass.tscn")

func _ready():
	for i in range(200
	):
		spawn_object()

func spawn_object():
	var new_object = object_scene.instantiate()
	
	var x = randf_range(-50, 50)
	var z = randf_range(-25, 100)
	var y = 0
	
	new_object.position = Vector3(x, y, z)
	new_object.rotation = Vector3(
		randf_range(-0.5, 0.5),
		randf_range(-0.5, 0.5),
		randf_range(-0.5, 0.5)
	)
	new_object.scale = Vector3(7, 7, 7)
	
	add_child(new_object)
	_remove_collision_recursive(new_object)

func _remove_collision_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is CollisionShape3D or child is CollisionPolygon3D or child is StaticBody3D:
			child.queue_free()
		else:
			_remove_collision_recursive(child)
