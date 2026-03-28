extends Node3D

@export_group("Rotation")
@export var rotation_sensitivity: float = 0.3

@export_group("Camera")
@export var camera_offset: Vector3 = Vector3(0, 7, 7)
@export var camera_angle: float = -45.0
@export var base_fov: float = 50.0
@export var run_fov: float = 55.0
@export var fov_lerp_speed: float = 5.0

@export_group("Shake")
@export var default_shake_intensity: float = 0.15
@export var default_shake_duration: float = 0.15

var target: Node3D = null
var is_rotating: bool = false
var shake_offset: Vector3 = Vector3.ZERO

@onready var camera: Camera3D = $Camera3D

func _ready():
	target = get_tree().get_first_node_in_group("player")
	camera.position = camera_offset
	camera.rotation_degrees.x = camera_angle
	camera.fov = base_fov
	
	Events.camera_shake_requested.connect(shake)
	
	if target:
		global_position = target.global_position

func _process(delta: float) -> void:
	_follow_target()
	_update_fov(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_rotating = event.pressed
			
	if event is InputEventMouseMotion and is_rotating:
		rotate_y(deg_to_rad(-event.relative.x * rotation_sensitivity))

func _follow_target() -> void:
	if not target or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player")
		
	if not target: 
		return
		
	global_position = target.global_position
	camera.position = camera_offset + shake_offset

func _update_fov(delta: float) -> void:
	if not target or not is_instance_valid(target): 
		return
		
	var target_fov = base_fov
	
	if target is CharacterBody3D and target.velocity.length() > 0.1:
		target_fov = run_fov
		
	camera.fov = lerp(camera.fov, target_fov, fov_lerp_speed * delta)

func shake(intensity: float = -1.0, duration: float = -1.0) -> void:
	if intensity < 0: intensity = default_shake_intensity
	if duration < 0: duration = default_shake_duration
	var elapsed = 0.0
	while elapsed < duration:
		if not is_instance_valid(self) or not is_inside_tree():
			return
		shake_offset = Vector3(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity),
			0
		)
		elapsed += get_process_delta_time()
		await get_tree().process_frame
	shake_offset = Vector3.ZERO
