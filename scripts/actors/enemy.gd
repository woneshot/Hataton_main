extends CharacterBody3D

enum MobType { CHASER, SHOOTER }

@export_group("Type")
@export var type: MobType = MobType.CHASER

@export_group("Stats")
@export var speed: float = 3.0
@export var health: int = 3
@export var detection_range: float = 15.0
@export var attack_range: float = 1.0
@export var attack_damage: int = 1
@export var attack_cooldown: float = 1.5
@export var separation_radius: float = 1.0

@export var damage_point: float = 0.4  # Доля анимации для удара/выстрела

@export_group("Shooter Only")
@export var projectile_scene: PackedScene

@export_group("Audio")
@export var sfx_attack: AudioStream
@export var sfx_hurt: AudioStream
@export var sfx_death: AudioStream

@export_group("Normal Maps (Sprite Sheets)")
@export var norm_idle: Texture2D
@export var norm_walk: Texture2D
@export var norm_attack: Texture2D
@export var norm_death: Texture2D

var current_normal_sheet: Texture2D
var normal_atlas_texture: AtlasTexture = AtlasTexture.new()

var player: Node3D = null
var camera_rig: Node3D = null
var can_attack: bool = true
var is_dead: bool = false
var is_attacking: bool = false
var is_hurt: bool = false
var damage_dealt_this_attack: bool = false
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Переменные для Шутера
var shooter_move_dir: Vector3 = Vector3.ZERO
var shooter_move_timer: float = 0.0
var attack_facing_dir: Vector3 = Vector3.ZERO  # Направление в момент начала атаки

# Антифликер
var current_facing: String = "down"
var facing_change_timer: float = 0.0
const FACING_CHANGE_COOLDOWN: float = 0.1
const FACING_HYSTERESIS: float = 1.5
var last_anim_name: String = ""
var last_move_dir: Vector3 = Vector3.BACK

@onready var visuals = $Visuals
@onready var sprite: AnimatedSprite3D = $Visuals/Sprite
@onready var sfx_player = $SfxPlayer

func _ready() -> void:
	_init_visuals()
	player = get_tree().get_first_node_in_group("player")
	camera_rig = get_tree().get_first_node_in_group("camera_rig")
	sprite.animation_finished.connect(_on_sprite_animation_finished)

func _process(_delta: float) -> void:
	_update_sprite_normals()
	_check_damage_point()

func _physics_process(delta: float) -> void:
	if is_dead or Events.is_paused: return

	if facing_change_timer > 0.0:
		facing_change_timer -= delta

	if not is_on_floor():
		velocity.y -= gravity * delta

	# Во время получения урона стоим
	if is_hurt:
		move_and_slide()
		return

	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if not player: return

	# Во время атаки — стоим
	if is_attacking:
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return

	var dist = global_position.distance_to(player.global_position)

	if dist < detection_range:
		match type:
			MobType.CHASER: _logic_chaser(dist)
			MobType.SHOOTER: _logic_shooter(dist, delta)
	else:
		# Вне зоны видимости - стоим
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		_update_sprite_direction(Vector3.ZERO)

	_apply_separation()
	move_and_slide()

# ==========================================
# ОТТАЛКИВАНИЕ (SEPARATION)
# ==========================================
func _apply_separation() -> void:
	var separation_vector = Vector3.ZERO
	var enemies = get_tree().get_nodes_in_group("enemy")
	var count = 0
	for other in enemies:
		if other == self or not is_instance_valid(other) or other.is_dead:
			continue
		var dist = global_position.distance_to(other.global_position)
		if dist < separation_radius and dist > 0.01:
			var push_dir = other.global_position.direction_to(global_position)
			push_dir.y = 0 
			var force = (separation_radius - dist) / separation_radius
			separation_vector += push_dir.normalized() * force * speed * 0.8
			count += 1
	if count > 0:
		separation_vector /= count
		velocity.x += separation_vector.x
		velocity.z += separation_vector.z

# ==========================================
# ЛОГИКА ТИПОВ
# ==========================================
func _logic_chaser(dist: float) -> void:
	var stop_range = attack_range + 0.5
	if can_attack:
		if dist > stop_range:
			var dir = global_position.direction_to(player.global_position)
			dir.y = 0
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			_update_sprite_direction(dir)
		else:
			velocity.x = 0
			velocity.z = 0
			_update_sprite_direction(global_position.direction_to(player.global_position))
			_start_attack_sequence()
	else:
		var dir_to_player = global_position.direction_to(player.global_position)
		dir_to_player.y = 0
		var strafe_dir = Vector3(-dir_to_player.z, 0, dir_to_player.x).normalized()
		var move_dir: Vector3
		if dist < stop_range:
			move_dir = (-dir_to_player + strafe_dir).normalized()
		elif dist > stop_range + 1.5:
			move_dir = (dir_to_player + strafe_dir).normalized()
		else:
			move_dir = strafe_dir
		velocity.x = move_dir.x * speed * 0.7
		velocity.z = move_dir.z * speed * 0.7
		_update_sprite_direction(move_dir)

func _logic_shooter(dist: float, delta: float) -> void:
	if can_attack and dist <= attack_range:
		# Может стрелять и в радиусе — останавливаемся и стреляем
		velocity.x = 0
		velocity.z = 0
		_update_sprite_direction(global_position.direction_to(player.global_position))
		_start_attack_sequence()
	else:
		# Если КД или вне радиуса — мы ДОЛЖНЫ бежать
		var move_dir: Vector3 = Vector3.ZERO
		
		if not can_attack and shooter_move_timer > 0:
			# КД идёт, бежим в случайную сторону
			shooter_move_timer -= delta
			move_dir = shooter_move_dir
		else:
			# Вне радиуса (или таймер случайного бега вышел, а КД еще есть) -> бежим к игроку
			move_dir = global_position.direction_to(player.global_position)
			move_dir.y = 0
			move_dir = move_dir.normalized()
			
		velocity.x = move_dir.x * speed
		velocity.z = move_dir.z * speed
		
		# Всегда обновляем направление
		_update_sprite_direction(move_dir)

# ==========================================
# АТАКА
# ==========================================
func _start_attack_sequence() -> void:
	if is_dead or is_attacking or not can_attack: return
	is_attacking = true
	can_attack = false
	damage_dealt_this_attack = false

	if is_instance_valid(player):
		var dir = global_position.direction_to(player.global_position)
		dir.y = 0
		attack_facing_dir = dir.normalized()
		facing_change_timer = 0.0
		_update_facing_from_dir(dir)

	var anim_base = "shoot_" if type == MobType.SHOOTER else "attack_"
	
	last_anim_name = ""
	_set_anim_and_normal(anim_base + current_facing, norm_attack)

	if sfx_attack:
		sfx_player.stream = sfx_attack
		sfx_player.play()

func _check_damage_point() -> void:
	if not is_attacking or damage_dealt_this_attack or is_dead: return
	if not sprite.sprite_frames: return

	var anim_name = sprite.animation
	if not (anim_name.begins_with("attack_") or anim_name.begins_with("shoot_")): return

	var frame_count = sprite.sprite_frames.get_frame_count(anim_name)
	if frame_count <= 0: return

	var progress = float(sprite.frame) / float(frame_count)
	if progress >= damage_point:
		damage_dealt_this_attack = true
		_deal_damage()

func _deal_damage() -> void:
	if not is_instance_valid(player): return

	if type == MobType.SHOOTER and projectile_scene:
		var dir_to_player = global_position.direction_to(player.global_position)
		dir_to_player.y = 0
		dir_to_player = dir_to_player.normalized()
		
		# Угол между направлением начала атаки и текущим положением игрока
		var angle_to_player = attack_facing_dir.angle_to(dir_to_player)
		
		if angle_to_player > deg_to_rad(45): 
			# Игрок убежал из конуса 90 градусов - стреляем прямо
			var p = projectile_scene.instantiate()
			get_parent().add_child(p)
			p.global_position = global_position + Vector3(0, 0.8, 0)
			if p.has_method("launch"):
				var target = global_position + attack_facing_dir * 10.0 + Vector3(0, 0.8, 0)
				p.launch(target, self)
		else:
			# Игрок в конусе - стреляем в него
			var p = projectile_scene.instantiate()
			get_parent().add_child(p)
			p.global_position = global_position + Vector3(0, 0.8, 0)
			if p.has_method("launch"):
				p.launch(player.global_position + Vector3(0, 0.5, 0), self)
	else:
		var dist = global_position.distance_to(player.global_position)
		if dist <= attack_range + 0.8 and player.has_method("take_damage"):
			player.take_damage(attack_damage)

func _on_sprite_animation_finished() -> void:
	if is_dead: return
	var anim_name = sprite.animation
	if not (anim_name.begins_with("attack_") or anim_name.begins_with("shoot_")): return
	if not is_attacking: return

	is_attacking = false
	last_anim_name = ""

	if type == MobType.SHOOTER:
		var angle = randf_range(0, TAU)
		shooter_move_dir = Vector3(cos(angle), 0, sin(angle)).normalized()
		# Бежит весь кулдаун
		shooter_move_timer = attack_cooldown

	await get_tree().create_timer(attack_cooldown).timeout
	if is_instance_valid(self) and not is_dead:
		can_attack = true

# ==========================================
# ЗДОРОВЬЕ И ВСПЫШКА
# ==========================================
func take_damage(amount: int) -> void:
	if is_dead: return
	health -= amount

	if sfx_hurt:
		sfx_player.stream = sfx_hurt
		sfx_player.play()
		
	_flash_red()

	if health <= 0:
		_die()
		return

	is_attacking = false
	can_attack = true
	is_hurt = true
	damage_dealt_this_attack = false
	velocity = Vector3.ZERO
	last_anim_name = ""
	

	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(self):
		is_hurt = false
		last_anim_name = ""

func _flash_red() -> void:
	if not sprite: return
	sprite.modulate = Color(1.0, 0.3, 0.3)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)

func _die() -> void:
	is_dead = true
	is_attacking = false
	velocity = Vector3.ZERO

	if sfx_death:
		sfx_player.stream = sfx_death
		sfx_player.play()

	last_anim_name = ""
	_set_anim_and_normal("death", norm_death)
	
	var pixel_offset = 4.0 * sprite.pixel_size
	var tween = create_tween()
	tween.tween_property(sprite, "position:y", sprite.position.y - pixel_offset, 0.15)
	
	await sprite.animation_finished
	queue_free()

# ==========================================
# СПРАЙТ НАПРАВЛЕНИЕ
# ==========================================
func _update_sprite_direction(dir: Vector3) -> void:
	if not camera_rig: return
	if is_attacking or is_hurt: return 

	if dir == Vector3.ZERO:
		# Стоим — используем последнее направление
		_update_facing_from_dir(last_move_dir)
	else:
		last_move_dir = dir  # Запоминаем
		_update_facing_from_dir(dir)

	var is_moving = velocity.length() > 0.1
	var prefix = "run_" if is_moving else "idle_"
	
	if not sprite.sprite_frames.has_animation(prefix + current_facing):
		prefix = "run_"
		
	var norm_sheet = norm_walk if is_moving else norm_idle
	_set_anim_and_normal(prefix + current_facing, norm_sheet)

func _update_facing_from_dir(dir: Vector3) -> void:
	if facing_change_timer > 0.0:
		return
	if not camera_rig: return

	var local_dir = dir.rotated(Vector3.UP, -camera_rig.global_rotation.y)
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
	if is_dead and anim_name != "death": return
	if anim_name == last_anim_name: return
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
