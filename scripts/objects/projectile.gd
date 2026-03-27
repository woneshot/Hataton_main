extends Area3D

@export var speed: float = 10.0
@export var damage: int = 1
@export var lifetime: float = 5.0

var direction: Vector3 = Vector3.ZERO
var launched: bool = false

@onready var sprite = $Sprite3D

func launch(target_pos: Vector3) -> void:
	direction = global_position.direction_to(target_pos).normalized()
	launched = true
	
	# Поворачиваем спрайт в сторону полёта (вокруг Y)
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
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
