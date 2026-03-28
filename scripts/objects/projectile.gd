extends Area3D

@export var speed: float = 10.0
@export var damage: int = 1
@export var lifetime: float = 5.0

var direction: Vector3 = Vector3.ZERO
var launched: bool = false
var owner_body: Node3D = null  # Кто выстрелил

func launch(target_pos: Vector3, shooter: Node3D = null) -> void:
	owner_body = shooter
	direction = global_position.direction_to(target_pos)
	direction.y = 0  # Убираем вертикальную составляющую
	direction = direction.normalized()
	launched = true
	
	if direction.length() > 0.01:
		var angle = atan2(direction.x, direction.z)
		rotation.y = angle
	
	get_tree().create_timer(lifetime).timeout.connect(func():
		if is_instance_valid(self): queue_free()
	)

func _process(delta: float) -> void:
	if launched:
		global_position += direction * speed * delta

func _on_body_entered(body: Node3D) -> void:
	# Игнорируем того кто выстрелил
	if body == owner_body: return
	
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
