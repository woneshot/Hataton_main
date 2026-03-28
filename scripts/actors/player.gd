extends CharacterBody3D

# ==========================================
# НАСТРОЙКИ
# ==========================================
@export_group("Stats")
@export var max_health: int = 5
@export var run_speed: float = 5.0
@export var death_restart_delay: float = 2.0

@export_group("Combat")
@export var invulnerability_time: float = 0.25
@export var attack_range: float = 1.8
@export var attack_angle: float = 0.8
@export var dash_attack_range: float = 2.2
@export var dash_attack_angle: float = 1.0
@export var attack_move_speed_mult: float = 0.35
@export var damage_point: float = 0.4

@export_group("Dash")
@export var dash_speed: float = 20.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 1.0
@export var dash_unlock_flag: String = ""

@export_group("Audio")
@export var sfx_attack: AudioStream
@export var sfx_hurt: AudioStream
@export var sfx_dash: AudioStream

# ==========================================
# ВИЗУАЛ: АТЛАС-НОРМАЛИ (Раздел 4)
# ==========================================
@export_group("Normal Maps (Sprite Sheets)")
@export var norm_idle: Texture2D
@export var norm_run: Texture2D
@export var norm_attack: Texture2D
@export var norm_dash: Texture2D
@export var norm_hurt: Texture2D
@export var norm_death: Texture2D

var current_normal_sheet: Texture2D
var normal_atlas_texture: AtlasTexture = AtlasTexture.new()

# ==========================================
# ВНУТРЕННИЕ
# ==========================================
var health: int = 0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera_rig: Node3D
var is_attacking: bool = false
var is_dashing: bool = false
var is_dead: bool = false
var can_dash: bool = true
var is_invulnerable: bool = false
var current_facing: String = "down"
var dash_direction: Vector3 = Vector3.ZERO
var damage_dealt_this_attack: bool = false
var attack_direction_cache: Vector3 = Vector3.ZERO
var last_move_dir: Vector3 = Vector3.BACK

# Антифликер
var facing_change_timer: float = 0.0
const FACING_CHANGE_COOLDOWN: float = 0.1
const FACING_HYSTERESIS: float = 1.5
var last_anim_name: String = ""

@onready var visuals = $Visuals
@onready var sprite: AnimatedSprite3D = $Visuals/Sprite
@onready var item_above_head = $Visuals/ItemAboveHead
@onready var interact_ray = $InteractRay
@onready var sfx_player = $SfxPlayer
@onready var dash_vfx = $DashReadyVFX

func _ready() -> void:
	health = max_health
	_init_visuals()
	camera_rig = get_tree().get_first_node_in_group("camera_rig")
	_update_item_visual()
	Events.item_picked_up.connect(func(_id): _update_item_visual())
	Events.item_used.connect(func(_id): _update_item_visual())
	Events.world_flag_changed.connect(_on_world_flag_changed)

func _process(_delta: float) -> void:
	_update_sprite_normals()
	_check_player_damage_point()
	if is_dead:
		dash_vfx.emitting = false
	else:
		dash_vfx.emitting = can_dash and _is_dash_unlocked()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if facing_change_timer > 0.0:
		facing_change_timer -= delta

	if Events.is_paused:
		_set_anim_and_normal("idle_" + current_facing, norm_idle)
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	# --- ЛОГИКА ДИАЛОГОВ И МОНОЛОГОВ ---
	if Events.is_in_dialogue:
		var dialog_ui = get_tree().get_first_node_in_group("dialog_ui")
		var is_monologue = (dialog_ui != null and dialog_ui.dialog_source == null)
		
		if is_monologue:
			# МОНОЛОГ: Стоим на месте, не реагируем на WASD
			velocity.x = 0
			velocity.z = 0
			_update_idle_facing() # Разрешаем только крутить камеру и видеть спину
			_set_anim_and_normal("idle_" + current_facing, norm_idle)
			move_and_slide()
			return
		else:
			# РАЗГОВОР С NPC: Двигаться можно
			_handle_movement()
			# Если остановились - смотрим на NPC
			if velocity.length() < 0.1:
				_face_dialog_source_or_camera()
	else:
		# Обычная игра
		if is_dashing:
			velocity.x = dash_direction.x * dash_speed
			velocity.z = dash_direction.z * dash_speed
		else:
			_handle_movement()

	move_and_slide()
	
func _input(event: InputEvent) -> void:
	if Events.is_paused or is_dead: return

	if event.is_action_pressed("attack") and not Events.is_in_dialogue and not is_attacking and not is_dashing:
		_attack()

	if event.is_action_pressed("interact") and not Events.is_in_dialogue:
		_interact()

	if event.is_action_pressed("dash") and can_dash and not is_dashing and not Events.is_in_dialogue and _is_dash_unlocked():
		_dash()

# ==========================================
# ДВИЖЕНИЕ
# ==========================================
func _handle_movement() -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()

	if direction != Vector3.ZERO and camera_rig:
		direction = direction.rotated(Vector3.UP, camera_rig.global_rotation.y)

	if direction.length() > 0.01:
		var current_speed = run_speed
		if is_attacking:
			current_speed = run_speed * attack_move_speed_mult

		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		var look_target = global_position + direction
		interact_ray.look_at(look_target, Vector3.UP)
		if not is_attacking:
			last_move_dir = direction
			_update_facing_direction(direction)
	else:
		velocity.x = move_toward(velocity.x, 0, run_speed)
		velocity.z = move_toward(velocity.z, 0, run_speed)

	if not is_attacking and not is_dashing:
		if velocity.length() > 0.1:
			_set_anim_and_normal("run_" + current_facing, norm_run)
		else:
			# Стоим — пересчитываем facing по камере
			_update_idle_facing()
			_set_anim_and_normal("idle_" + current_facing, norm_idle)

func _update_facing_direction(dir: Vector3) -> void:
	if facing_change_timer > 0.0:
		return

	var local_dir = dir
	if camera_rig:
		local_dir = dir.rotated(Vector3.UP, -camera_rig.global_rotation.y)

	var abs_x = abs(local_dir.x)
	var abs_z = abs(local_dir.z)

	var current_is_vertical = (current_facing == "up" or current_facing == "down")
	var use_vertical: bool

	if current_is_vertical:
		use_vertical = abs_x < abs_z * FACING_HYSTERESIS
	else:
		use_vertical = abs_z > abs_x * FACING_HYSTERESIS

	var new_facing: String
	if use_vertical:
		new_facing = "down" if local_dir.z > 0 else "up"
	else:
		new_facing = "right" if local_dir.x > 0 else "left"

	if new_facing != current_facing:
		current_facing = new_facing
		facing_change_timer = FACING_CHANGE_COOLDOWN

func _update_idle_facing() -> void:
	if not camera_rig: return

	# Берём запомненное мировое направление и пересчитываем через текущий угол камеры
	var local_dir = last_move_dir.rotated(Vector3.UP, -camera_rig.global_rotation.y)

	var abs_x = abs(local_dir.x)
	var abs_z = abs(local_dir.z)

	if abs_z > abs_x:
		current_facing = "down" if local_dir.z > 0 else "up"
	else:
		current_facing = "right" if local_dir.x > 0 else "left"

	last_anim_name = ""

func _face_dialog_source_or_camera() -> void:
	var dialog_ui = get_tree().get_first_node_in_group("dialog_ui")
	
	if dialog_ui and dialog_ui.dialog_source and is_instance_valid(dialog_ui.dialog_source):
		var dir_to_npc = global_position.direction_to(dialog_ui.dialog_source.global_position)
		dir_to_npc.y = 0
		if dir_to_npc.length() > 0.01:
			last_move_dir = dir_to_npc
			facing_change_timer = 0.0
			_update_facing_direction(dir_to_npc)
	else:
		_update_idle_facing()
		
	_set_anim_and_normal("idle_" + current_facing, norm_idle)

# ==========================================
# АТАКА
# ==========================================
func _attack() -> void:
	if is_attacking: return
	is_attacking = true
	damage_dealt_this_attack = false

	var mouse_world_pos = _get_mouse_world_pos()
	var dir_to_mouse = global_position.direction_to(mouse_world_pos)
	dir_to_mouse.y = 0
	dir_to_mouse = dir_to_mouse.normalized()
	attack_direction_cache = dir_to_mouse

	facing_change_timer = 0.0
	_update_facing_direction(dir_to_mouse)

	var attack_variant = str(randi_range(1, 2))
	var anim_name = "attack_" + current_facing + "_" + attack_variant

	last_anim_name = ""
	_set_anim_and_normal(anim_name, norm_attack)

	if sfx_attack:
		sfx_player.stream = sfx_attack
		sfx_player.play()

	await sprite.animation_finished
	if is_instance_valid(self):
		is_attacking = false
		last_anim_name = ""

func _check_player_damage_point() -> void:
	if not is_attacking or damage_dealt_this_attack or is_dead: return
	if not sprite.sprite_frames: return

	var anim_name = sprite.animation
	if not anim_name.begins_with("attack_"): return

	var frame_count = sprite.sprite_frames.get_frame_count(anim_name)
	if frame_count <= 0: return

	var progress = float(sprite.frame) / float(frame_count)
	if progress >= damage_point:
		damage_dealt_this_attack = true
		_hit_enemies_in_arc(attack_direction_cache, attack_range, attack_angle)

# ==========================================
# ДЭШ
# ==========================================
func _is_dash_unlocked() -> bool:
	if dash_unlock_flag == "":
		return true
	return Events.get_flag(dash_unlock_flag)

func _dash() -> void:
	is_dashing = true
	can_dash = false
	is_invulnerable = true

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var move_dir = Vector3(input_dir.x, 0, input_dir.y).normalized()

	if camera_rig and move_dir != Vector3.ZERO:
		move_dir = move_dir.rotated(Vector3.UP, camera_rig.global_rotation.y)

	if move_dir == Vector3.ZERO:
		move_dir = _facing_to_vector()

	dash_direction = move_dir.normalized()

	facing_change_timer = 0.0
	_update_facing_direction(dash_direction)
	last_anim_name = ""
	_set_anim_and_normal("dash_" + current_facing, norm_dash)

	if sfx_dash:
		sfx_player.stream = sfx_dash
		sfx_player.play()

	_hit_enemies_in_arc(dash_direction, dash_attack_range, dash_attack_angle)

	await get_tree().create_timer(dash_duration).timeout
	is_dashing = false
	is_invulnerable = false
	last_anim_name = ""

	await get_tree().create_timer(dash_cooldown).timeout
	if is_instance_valid(self):
		can_dash = true

func _facing_to_vector() -> Vector3:
	var local_dir: Vector3
	match current_facing:
		"up": local_dir = Vector3.FORWARD
		"down": local_dir = Vector3.BACK
		"left": local_dir = Vector3.LEFT
		"right": local_dir = Vector3.RIGHT
		_: local_dir = Vector3.BACK

	if camera_rig:
		local_dir = local_dir.rotated(Vector3.UP, camera_rig.global_rotation.y)
	return local_dir

# ==========================================
# НАНЕСЕНИЕ УРОНА
# ==========================================
func _hit_enemies_in_arc(direction: Vector3, hit_range: float, hit_angle: float) -> void:
	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist > hit_range: continue
		var dir_to_enemy = global_position.direction_to(enemy.global_position)
		dir_to_enemy.y = 0
		var angle = direction.angle_to(dir_to_enemy.normalized())
		if angle < hit_angle and enemy.has_method("take_damage"):
			enemy.take_damage(1)
			Events.camera_shake_requested.emit(0.1, 0.1)

	var npcs = get_tree().get_nodes_in_group("interactable")
	for npc in npcs:
		if not is_instance_valid(npc): continue
		if not npc.has_method("take_damage"): continue
		if not ("npc_type" in npc and npc.npc_type == 4): continue
		var dist = global_position.distance_to(npc.global_position)
		if dist > hit_range: continue
		var dir_to_npc = global_position.direction_to(npc.global_position)
		dir_to_npc.y = 0
		var angle = direction.angle_to(dir_to_npc.normalized())
		if angle < hit_angle:
			npc.take_damage(1)
			Events.camera_shake_requested.emit(0.1, 0.1)

# ==========================================
# УТИЛИТЫ
# ==========================================
func _get_mouse_world_pos() -> Vector3:
	var cam = get_viewport().get_camera_3d()
	var mouse_pos = get_viewport().get_mouse_position()
	var origin = cam.project_ray_origin(mouse_pos)
	var normal = cam.project_ray_normal(mouse_pos)
	if normal.y == 0: return global_position
	var t = (global_position.y - origin.y) / normal.y
	return origin + normal * t

# ==========================================
# ВЗАИМОДЕЙСТВИЕ
# ==========================================
func _interact() -> void:
	if interact_ray.is_colliding():
		for i in interact_ray.get_collision_count():
			var target = interact_ray.get_collider(i)
			if target.has_method("interact"):
				target.interact()
				return

# ==========================================
# ЗДОРОВЬЕ
# ==========================================
func take_damage(amount: int) -> void:
	if health <= 0 or is_invulnerable: return
	health -= amount
	Events.player_damaged.emit(health)
	Events.camera_shake_requested.emit(0.2, 0.15)

	if sfx_hurt:
		sfx_player.stream = sfx_hurt
		sfx_player.play()

	_flash_red()

	if health <= 0:
		is_dead = true
		is_attacking = false
		is_dashing = false
		velocity = Vector3.ZERO
		dash_vfx.emitting = false
		last_anim_name = ""
		_set_anim_and_normal("death", norm_death)

		var pixel_offset = 1.5 * sprite.pixel_size
		var tween = create_tween()
		tween.tween_property(sprite, "position:y", sprite.position.y - pixel_offset, 0.15)

		await get_tree().create_timer(death_restart_delay).timeout
		Events.handle_player_death()
		return

	is_invulnerable = true

	await get_tree().create_timer(invulnerability_time).timeout
	if is_instance_valid(self):
		is_invulnerable = false

func _flash_red() -> void:
	if not sprite: return
	sprite.modulate = Color(1.0, 0.3, 0.3)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)

func heal(amount: int) -> void:
	health = min(health + amount, max_health)
	Events.player_damaged.emit(health)

# ==========================================
# ПРЕДМЕТ НАД ГОЛОВОЙ
# ==========================================
func _update_item_visual() -> void:
	if Events.current_item == "":
		item_above_head.hide()
	else:
		var tex_path = "res://assets/sprites/items/" + Events.current_item + ".png"
		if ResourceLoader.exists(tex_path):
			item_above_head.texture = load(tex_path)
			item_above_head.show()

# ==========================================
# ВИЗУАЛ
# ==========================================
func _init_visuals() -> void:
	if not sprite: return
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.fixed_size = false
	mat.normal_enabled = true
	mat.vertex_color_use_as_albedo = true
	sprite.material_override = mat
	current_normal_sheet = norm_idle

func _set_anim_and_normal(anim_name: String, normal_sheet: Texture2D) -> void:
	if anim_name == last_anim_name:
		return
	last_anim_name = anim_name

	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)

	if normal_sheet:
		current_normal_sheet = normal_sheet

func _update_sprite_normals() -> void:
	if not sprite or not sprite.material_override or not sprite.sprite_frames: return
	var current_anim = sprite.animation
	var current_frame = sprite.frame
	if sprite.sprite_frames.get_frame_count(current_anim) <= current_frame: return
	var visual_tex = sprite.sprite_frames.get_frame_texture(current_anim, current_frame) as AtlasTexture
	if visual_tex:
		sprite.material_override.albedo_texture = visual_tex
		if current_normal_sheet:
			normal_atlas_texture.atlas = current_normal_sheet
			normal_atlas_texture.region = visual_tex.region
			sprite.material_override.normal_texture = normal_atlas_texture
			
			
func _on_world_flag_changed(flag_name: String, value) -> void:
	if value == true:
		if flag_name == "level_completed1" or flag_name == "level_completed2":
			heal(max_health) # Восстанавливаем полное ХП
			
			# Если есть звук хила или партиклы - можно добавить сюда
			if sfx_dash: # Временная затычка звуком дэша (или добавь sfx_heal)
				pass
