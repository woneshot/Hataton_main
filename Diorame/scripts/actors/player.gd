extends CharacterBody3D

# === НАСТРОЙКИ ИГРОКА ===
@export var speed: float = 6.0
@export var attack_duration: float = 0.25 
@export var camera_sens: float = 1.0 

# === НАСТРОЙКИ АФК ===
@export var afk_time_trigger: float = 15.0 
var afk_timer: float = 0.0
var is_afk_mode: bool = false
var original_camera_rotation_y: float = 0.0 
var shake_intensity: float = 0.0

# === ССЫЛКИ НА УЗЛЫ ===
@onready var anim_sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var weapon_pivot: Node3D = $WeaponPivot
@onready var hitbox_col: CollisionShape3D = $WeaponPivot/Hitbox/CollisionShape3D
@onready var interact_ray: ShapeCast3D = $InteractRay # Ящик для диалогов

# === НОРМАЛКИ (Твои пути) ===
var norm_idle = preload("res://assets/hero/Idle_normal.png")
var norm_walk = preload("res://assets/hero/Run_normal.png")
var norm_attack = preload("res://assets/hero/Run_Attack_normal.png")

# Буферная текстура для идеальной нарезки нормалей
var current_normal_sheet: Texture2D
var normal_atlas_texture: AtlasTexture = AtlasTexture.new()

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var last_facing_dir: Vector3 = Vector3(0, 0, 1)

var is_attacking: bool = false
var is_dead: bool = false
var is_hurt: bool = false
var attack_timer: float = 0.0
var current_playing_anim: String = ""

func _ready() -> void:
	hitbox_col.disabled = true
	current_normal_sheet = norm_idle

# === СБРОС АФК ===
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventKey or event is InputEventMouseButton:
		if is_afk_mode:
			is_afk_mode = false
			original_camera_rotation_y = camera_rig.rotation.y
		afk_timer = 0.0

# === ВРАЩЕНИЕ КАМЕРЫ ===
# === ВРАЩЕНИЕ КАМЕРЫ ===
func _input(event: InputEvent) -> void:
	if Input.is_action_pressed("rotate_camera") and event is InputEventMouseMotion:
		camera_rig.rotation.y -= event.relative.x * (camera_sens / 100.0)
		
		# Выключаем АФК-режим принудительно при вращении
		if is_afk_mode:
			is_afk_mode = false
			original_camera_rotation_y = camera_rig.rotation.y
			
		afk_timer = 0.0

# === ВИЗУАЛ И СИНХРОНИЗАЦИЯ НОРМАЛОК ===
func _process(delta: float) -> void:
	if anim_sprite.material_override and anim_sprite.sprite_frames:
		var current_anim = anim_sprite.animation
		var current_frame = anim_sprite.frame
		
		if anim_sprite.sprite_frames.get_frame_count(current_anim) > current_frame:
			# Берем цветной кадр
			var visual_tex = anim_sprite.sprite_frames.get_frame_texture(current_anim, current_frame) as AtlasTexture
			
			if visual_tex:
				# 1. Передаем цвет
				anim_sprite.material_override.albedo_texture = visual_tex
				
				# 2. ИДЕАЛЬНО вырезаем такой же кусок из фиолетовой нормалки!
				if current_normal_sheet:
					normal_atlas_texture.atlas = current_normal_sheet
					normal_atlas_texture.region = visual_tex.region
					anim_sprite.material_override.normal_texture = normal_atlas_texture

	# АФК Таймер и Камера
	afk_timer += delta
	if afk_timer >= afk_time_trigger and not is_afk_mode:
		is_afk_mode = true

	var current_speed = Vector2(velocity.x, velocity.z).length()
	var target_fov = 60.0 
	
	if is_afk_mode:
		camera_rig.rotation.y += 0.2 * delta 
		target_fov = 75.0 
	else:
		if current_speed > 1.0: target_fov = 75.0

	camera.fov = lerp(camera.fov, target_fov, 1.5 * delta)
	
	# Тряска экрана
	if shake_intensity > 0.01:
		camera_rig.position.x = randf_range(-shake_intensity, shake_intensity)
		camera_rig.position.z = randf_range(-shake_intensity, shake_intensity)
		shake_intensity = lerp(shake_intensity, 0.0, 25.0 * delta)
	else:
		camera_rig.position = Vector3.ZERO


# === ФИЗИКА И ДВИЖЕНИЕ ===
func _physics_process(delta: float) -> void:
	if is_dead or is_hurt: return
	if not is_on_floor(): velocity.y -= gravity * delta

	# Взаимодействие (Диалоги с NPC)
	if Input.is_action_just_pressed("interact") and not is_attacking:
		if interact_ray.is_colliding():
			var target = interact_ray.get_collider(0)
			if target.has_method("interact"):
				target.interact(self)

	# Логика Атаки
	if Input.is_action_just_pressed("attack") and not is_attacking:
		start_attack()

	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0.0: end_attack()

	# Передвижение относительно камеры
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_basis = camera_rig.global_transform.basis
	var move_dir = (cam_basis.x * input_dir.x + cam_basis.z * input_dir.y).normalized()

	if move_dir:
		velocity.x = move_dir.x * speed
		velocity.z = move_dir.z * speed
		last_facing_dir = move_dir
	else:
		velocity.x = move_toward(velocity.x, 0, speed * 15 * delta)
		velocity.z = move_toward(velocity.z, 0, speed * 15 * delta)
		
	# Анимации и Направление
	if not is_attacking:
		var is_moving = move_dir.length() > 0
		update_movement_animation(last_facing_dir, is_moving)
		
		# Поворачиваем ящик диалогов туда, куда смотрим
		if last_facing_dir != Vector3.ZERO:
			interact_ray.look_at(global_position + last_facing_dir, Vector3.UP)
			
		if is_moving: current_normal_sheet = norm_walk
		else: current_normal_sheet = norm_idle

	move_and_slide()

# === БОЕВАЯ СИСТЕМА ===
func start_attack() -> void:
	is_attacking = true
	attack_timer = attack_duration
	afk_timer = 0.0 
	
	var aim_dir = get_mouse_direction()
	weapon_pivot.look_at(global_position + aim_dir, Vector3.UP)
	hitbox_col.disabled = false 
	
	current_normal_sheet = norm_attack
	play_directional_anim("attack_", aim_dir)
	
	await get_tree().create_timer(0.24).timeout 
	shake_intensity = 0.1 

func end_attack() -> void:
	is_attacking = false
	hitbox_col.disabled = true


# === ЖЕЛЕЗОБЕТОННЫЙ АНИМАТОР НА 4 СТОРОНЫ ===
func update_movement_animation(facing_dir: Vector3, is_moving: bool) -> void:
	if is_moving: play_directional_anim("walk_", facing_dir)
	else: play_directional_anim("idle_", facing_dir)


func play_directional_anim(prefix: String, dir: Vector3) -> void:
	var local_dir = camera_rig.global_transform.basis.inverse() * dir
	var target_anim = ""
	
	# Защита от спама на диагоналях (мертвая зона 0.05)
	if abs(local_dir.x) > abs(local_dir.z) + 0.05:
		if local_dir.x < 0: target_anim = prefix + "left"
		else: target_anim = prefix + "right"
	elif abs(local_dir.z) > abs(local_dir.x) + 0.05:
		if local_dir.z > 0: target_anim = prefix + "down"
		else: target_anim = prefix + "up"
	else:
		# Если мы ровно на диагонали - просто оставляем старое направление
		if current_playing_anim != "":
			target_anim = prefix + current_playing_anim.split("_")[1]
		else:
			target_anim = prefix + "down"

	if current_playing_anim != target_anim:
		anim_sprite.play(target_anim)
		current_playing_anim = target_anim
# === МАТЕМАТИКА КУРСОРА МЫШИ ===
func get_mouse_direction() -> Vector3:
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	
	var plane = Plane(Vector3.UP, global_position.y)
	var intersection = plane.intersects_ray(ray_origin, ray_dir)
	
	if intersection != null:
		var dir = global_position.direction_to(intersection)
		dir.y = 0
		return dir.normalized()
	return last_facing_dir
