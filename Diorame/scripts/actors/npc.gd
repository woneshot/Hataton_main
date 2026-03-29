extends CharacterBody3D

@export_group("Dialog Settings")
@export_multiline var dialog_lines: Array[String] = [
	"Привет, путник...",
	"Лес сегодня особенно темный.",
	"Не отходи далеко от костра."
]

@export_group("Movement Settings")
@export var wander_radius: float = 3.0 
@export var speed: float = 1.5

@export_group("Name Label Visibility")
# Дистанция, на которой текст ТОЛЬКО начинает появляться (Alpha = 0.0)
@export var appearance_start_dist: float = 7.0  
# Дистанция, на которой текст уже виден полностью (Alpha = 1.0)
@export var full_visibility_dist: float = 4.0   

@onready var name_label: Label3D = $NameLabel
@onready var anim_sprite: AnimatedSprite3D = $AnimatedSprite3D

enum State { IDLE, WANDER, TALKING }
var current_state = State.IDLE

var start_pos: Vector3
var target_pos: Vector3
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var current_facing_dir: Vector3 = Vector3(0, 0, 1)

func _ready() -> void:
	# Полная прозрачность при старте
	name_label.modulate.a = 0.0
	name_label.outline_modulate.a = 0.0
	
	start_pos = global_position
	if DialogManager:
		DialogManager.dialog_finished.connect(_on_dialog_finished)
	pick_new_target()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Логика перемещения NPC
	match current_state:
		State.TALKING:
			velocity.x = move_toward(velocity.x, 0, speed * 5 * delta)
			velocity.z = move_toward(velocity.z, 0, speed * 5 * delta)
		State.WANDER:
			var dir = global_position.direction_to(target_pos)
			dir.y = 0
			dir = dir.normalized()
			current_facing_dir = dir
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			if global_position.distance_to(target_pos) < 0.2:
				start_idle_timer()
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0, speed * 5 * delta)
			velocity.z = move_toward(velocity.z, 0, speed * 5 * delta)

	move_and_slide()

	# Обновление визуала
	var anim_prefix = "walk_" if current_state == State.WANDER else "idle_"
	update_animation(anim_prefix, current_facing_dir)
	
	# Обновление прозрачности имени
	update_name_label_visibility(delta)

func update_name_label_visibility(delta: float) -> void:
	var cam = get_viewport().get_camera_3d()
	if not cam: return

	var dist = global_position.distance_to(cam.global_position)
	var target_alpha: float = 0.0

	if current_state == State.TALKING:
		target_alpha = 0.0
	else:
		# Теперь remap работает от 7.0 (0% видимости) до 4.0 (100% видимости)
		target_alpha = remap(dist, appearance_start_dist, full_visibility_dist, 0.0, 1.0)
		target_alpha = clamp(target_alpha, 0.0, 1.0)

	# Плавное затухание/появление через lerp
	var final_alpha = lerp(name_label.modulate.a, target_alpha, 8.0 * delta)
	
	name_label.modulate.a = final_alpha
	name_label.outline_modulate.a = final_alpha

func pick_new_target() -> void:
	var random_x = randf_range(-wander_radius, wander_radius)
	var random_z = randf_range(-wander_radius, wander_radius)
	target_pos = start_pos + Vector3(random_x, 0, random_z)
	current_state = State.WANDER

func start_idle_timer() -> void:
	current_state = State.IDLE
	await get_tree().create_timer(randf_range(1.0, 4.0)).timeout
	if current_state != State.TALKING:
		pick_new_target()

func interact(player: Node3D) -> void:
	if current_state == State.TALKING: return 
	current_state = State.TALKING
	
	var dir_to_player = global_position.direction_to(player.global_position)
	dir_to_player.y = 0
	current_facing_dir = dir_to_player.normalized()
	
	if DialogManager:
		DialogManager.start_dialog(dialog_lines, player, self)

func _on_dialog_finished() -> void:
	if current_state == State.TALKING:
		start_idle_timer()

func update_animation(prefix: String, dir: Vector3) -> void:
	var cam = get_viewport().get_camera_3d()
	var local_dir = dir
	if cam:
		var cam_parent = cam.get_parent()
		if cam_parent is Node3D:
			local_dir = cam_parent.global_transform.basis.inverse() * dir
		else:
			local_dir = cam.global_transform.basis.inverse() * dir

	if abs(local_dir.x) > abs(local_dir.z):
		anim_sprite.play(prefix + "side")
		anim_sprite.flip_h = local_dir.x < 0
	else:
		anim_sprite.flip_h = false
		if local_dir.z > 0: anim_sprite.play(prefix + "down")
		else: anim_sprite.play(prefix + "up")
