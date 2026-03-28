extends CharacterBody3D

# ==========================================
# НАСТРОЙКИ
# ==========================================
@export_group("Stats")
@export var max_health: int = 30
@export var shield_down_duration: float = 10.0  # Сколько секунд бить бабку после убийства мобов
@export var detection_range: float = 8.0

@export_group("Phases")
@export var has_third_phase: bool = false  # TODO: потом привяжем к флагу Events.get_flag("...")
@export var phase2_fireball_delay: float = 10.0  # Через сколько сек после начала фазы бросает фаерболы
@export var fireball_count: int = 8  # Сколько фаерболов по кругу
@export var fireball_scene: PackedScene  # Сцена проджектайла фаербола

@export_group("Cast Animation")
@export var cast_damage_point: float = 0.5  # На какой доле анимации каста спавнятся мобы

@export_group("Spawn Points")
@export var spawn_points: Array[Marker3D] = []  # Точки спавна мобов (расставить в сцене)

@export_group("Spawn Scenes")
@export var skeleton_scene: PackedScene
@export var faun_scene: PackedScene

@export_group("Audio")
@export var sfx_cast: AudioStream
@export var sfx_hurt: AudioStream
@export var sfx_death: AudioStream
@export var sfx_explosion: AudioStream

@export_group("Normal Maps (Sprite Sheets)")
@export var norm_idle: Texture2D
@export var norm_cast: Texture2D
@export var norm_death: Texture2D

var current_normal_sheet: Texture2D
var normal_atlas_texture: AtlasTexture = AtlasTexture.new()

# ==========================================
# ВНУТРЕННИЕ
# ==========================================
var health: int = 0
var is_dead: bool = false
var is_shielded: bool = false
var is_casting: bool = false
var is_vulnerable: bool = false  # Щит снят, можно бить
var fight_started: bool = false
var current_phase: int = 0  # 0 = не начали, 1 = фаза 1, 2 = фаза 2, 3 = фаза 3
var max_phases: int = 2
var spawned_enemies: Array[Node] = []
var cast_spawned_this_anim: bool = false

var player: Node3D = null
var camera_rig: Node3D = null
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Антифликер
var current_facing: String = "down"
var facing_change_timer: float = 0.0
const FACING_CHANGE_COOLDOWN: float = 0.1
const FACING_HYSTERESIS: float = 1.5
var last_anim_name: String = ""

# Партиклы щита
@onready var shield_particles: GPUParticles3D = $ShieldParticles

@onready var visuals = $Visuals
@onready var sprite: AnimatedSprite3D = $Visuals/Sprite
@onready var sfx_player = $SfxPlayer

func _ready() -> void:
	health = max_health
	_init_visuals()
	player = get_tree().get_first_node_in_group("player")
	camera_rig = get_tree().get_first_node_in_group("camera_rig")
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	
	if has_third_phase:
		max_phases = 3
	
	if shield_particles:
		shield_particles.emitting = false

func _process(_delta: float) -> void:
	_update_sprite_normals()
	_check_cast_spawn_point()
	
	# Проверяем живы ли заспавненные мобы
	if is_shielded and fight_started and not is_casting:
		_check_spawned_enemies()

func _physics_process(delta: float) -> void:
	if is_dead or Events.is_paused: return

	if facing_change_timer > 0.0:
		facing_change_timer -= delta

	if not is_on_floor():
		velocity.y -= gravity * delta

	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if not player: return

	# Бабка всегда стоит на месте
	velocity.x = 0
	velocity.z = 0

	# Смотрим на игрока
	if not is_casting:
		var dir_to_player = global_position.direction_to(player.global_position)
		dir_to_player.y = 0
		if dir_to_player.length() > 0.01:
			_update_facing_from_dir(dir_to_player)

	# Детект игрока — начало боя
	if not fight_started:
		var dist = global_position.distance_to(player.global_position)
		if dist < detection_range:
			_start_fight()

	# Idle анимация если не кастуем и не мертвы
	if not is_casting and not is_dead:
		_set_anim_and_normal("idle_" + current_facing, norm_idle)

	move_and_slide()

# ==========================================
# НАЧАЛО БОЯ
# ==========================================
func _start_fight() -> void:
	fight_started = true
	_start_next_phase()

func _start_next_phase() -> void:
	current_phase += 1
	
	if current_phase > max_phases:
		# Все фазы пройдены, бабка не побеждена — ВЗРЫВ
		_explode()
		return
	
	# Начинаем каст
	_start_cast()

# ==========================================
# КАСТ (ЩИТ + СПАВН)
# ==========================================
func _start_cast() -> void:
	is_casting = true
	is_shielded = true
	is_vulnerable = false
	cast_spawned_this_anim = false
	
	# Включаем партиклы щита
	if shield_particles:
		shield_particles.emitting = true
	
	if sfx_cast:
		sfx_player.stream = sfx_cast
		sfx_player.play()
	
	last_anim_name = ""
	_set_anim_and_normal("cast_" + current_facing, norm_cast)

func _check_cast_spawn_point() -> void:
	if not is_casting or cast_spawned_this_anim or is_dead: return
	if not sprite.sprite_frames: return
	
	var anim_name = sprite.animation
	if not anim_name.begins_with("cast_"): return
	
	var frame_count = sprite.sprite_frames.get_frame_count(anim_name)
	if frame_count <= 0: return
	
	var progress = float(sprite.frame) / float(frame_count)
	if progress >= cast_damage_point:
		cast_spawned_this_anim = true
		_spawn_phase_enemies()

func _spawn_phase_enemies() -> void:
	spawned_enemies.clear()
	
	var to_spawn: Array = []
	
	match current_phase:
		1:
			# Фаза 1: 1 фавн + 2 скелетона
			to_spawn = [faun_scene, skeleton_scene, skeleton_scene]
		2:
			# Фаза 2: 3 фавна + 2 скелетона
			to_spawn = [faun_scene, faun_scene, faun_scene, skeleton_scene, skeleton_scene]
		3:
			# Фаза 3: то же что фаза 2
			to_spawn = [faun_scene, faun_scene, faun_scene, skeleton_scene, skeleton_scene]
	
	for i in to_spawn.size():
		var scene = to_spawn[i]
		if scene == null: continue
		
		var enemy = scene.instantiate()
		get_parent().add_child(enemy)
		
		# Размещаем на точках спавна (если есть), иначе вокруг бабки
		if i < spawn_points.size() and spawn_points[i] != null:
			enemy.global_position = spawn_points[i].global_position
		else:
			var angle = TAU * float(i) / float(to_spawn.size())
			var offset = Vector3(cos(angle) * 3.0, 0, sin(angle) * 3.0)
			enemy.global_position = global_position + offset
		
		spawned_enemies.append(enemy)
	
	# Фаза 2 и 3: через N секунд бросаем фаерболы
	if current_phase >= 2:
		_schedule_fireballs()

func _on_sprite_animation_finished() -> void:
	if is_dead: return
	
	if sprite.animation.begins_with("cast_"):
		is_casting = false
		# После каста остаёмся в idle с щитом

# ==========================================
# ПРОВЕРКА МОБОВ
# ==========================================
func _check_spawned_enemies() -> void:
	var alive: Array[Node] = []
	for enemy in spawned_enemies:
		if is_instance_valid(enemy) and not enemy.is_dead:
			alive.append(enemy)
	spawned_enemies = alive
	
	if spawned_enemies.size() == 0:
		_shield_down()

func _shield_down() -> void:
	is_shielded = false
	is_vulnerable = true
	
	if shield_particles:
		shield_particles.emitting = false
	
	# Через N секунд щит поднимается обратно (следующая фаза)
	await get_tree().create_timer(shield_down_duration).timeout
	if is_instance_valid(self) and not is_dead:
		is_vulnerable = false
		_start_next_phase()

# ==========================================
# ФАЕРБОЛЫ
# ==========================================
func _schedule_fireballs() -> void:
	await get_tree().create_timer(phase2_fireball_delay).timeout
	if is_instance_valid(self) and not is_dead and is_shielded:
		_cast_fireballs()

func _cast_fireballs() -> void:
	if fireball_scene == null: return
	
	for i in fireball_count:
		var angle = TAU * float(i) / float(fireball_count)
		var dir = Vector3(cos(angle), 0, sin(angle))
		
		var fireball = fireball_scene.instantiate()
		get_parent().add_child(fireball)
		fireball.global_position = global_position + Vector3(0, 0.8, 0)
		
		if fireball.has_method("launch"):
			var target = global_position + dir * 15.0 + Vector3(0, 0.8, 0)
			fireball.launch(target, self)

# ==========================================
# ВЗРЫВ (ВСЕ ФАЗЫ ПРОЙДЕНЫ — ИГРОК УМИРАЕТ)
# ==========================================
func _explode() -> void:
	is_shielded = true
	is_vulnerable = false
	
	if sfx_explosion:
		sfx_player.stream = sfx_explosion
		sfx_player.play()
	
	# TODO: можно добавить анимацию каста для взрыва
	# Тряска камеры
	Events.camera_shake_requested.emit(0.5, 1.0)
	
	await get_tree().create_timer(1.0).timeout
	
	# Убиваем игрока
	if is_instance_valid(player) and player.has_method("take_damage"):
		player.take_damage(999)

# ==========================================
# ЗДОРОВЬЕ
# ==========================================
func take_damage(amount: int) -> void:
	if is_dead: return
	
	# Щит активен — урон не проходит
	if is_shielded or not is_vulnerable:
		# TODO: можно добавить звук "щит заблокировал" или партикл
		return
	
	health -= amount
	_flash_red()
	
	if sfx_hurt:
		sfx_player.stream = sfx_hurt
		sfx_player.play()
	
	if health <= 0:
		_die()

func _flash_red() -> void:
	if not sprite: return
	sprite.modulate = Color(1.0, 0.3, 0.3)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)

func _die() -> void:
	is_dead = true
	is_shielded = false
	is_vulnerable = false
	is_casting = false
	velocity = Vector3.ZERO
	
	if shield_particles:
		shield_particles.emitting = false
	
	# Убиваем всех оставшихся мобов
	for enemy in spawned_enemies:
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			enemy.take_damage(999)
	spawned_enemies.clear()
	
	if sfx_death:
		sfx_player.stream = sfx_death
		sfx_player.play()
	
	last_anim_name = ""
	_set_anim_and_normal("death", norm_death)
	
	var pixel_offset = 4.0 * sprite.pixel_size
	var tween = create_tween()
	tween.tween_property(sprite, "position:y", sprite.position.y - pixel_offset, 0.15)
	
	# TODO: поставить флаг Events.set_flag("boss_killed")
	
	await sprite.animation_finished
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(self):
		queue_free()

# ==========================================
# СПРАЙТ НАПРАВЛЕНИЕ
# ==========================================
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
