extends CharacterBody3D

enum NPCType { GUARD, AMBIENT, KING, RAT, WOLF }

@export_group("Type")
@export var npc_type: NPCType = NPCType.GUARD

@export_group("Identity")
@export var actor_name: String = ""

@export_group("Dialogue")
@export var dialogue_entries: Array[DialogueEntry] = []

@export_group("Wander")
@export var can_wander: bool = false
@export var wander_speed: float = 1.5
@export var wander_radius: float = 3.0
@export var wander_wait_min: float = 2.0
@export var wander_wait_max: float = 5.0

@export_group("Disappear")
@export var disappear_on_flag: String = ""
@export var disappear_is_death: bool = false

@export_group("Damage")
@export var can_take_damage_from_enemies: bool = false  # AMBIENT, WOLF
@export var can_take_damage_from_player: bool = false    # WOLF only

@export_group("RAT Specific")
@export var dig_chance: float = 0.3  # Шанс начать копать вместо idle
@export var dig_duration_min: float = 2.0
@export var dig_duration_max: float = 5.0

@export_group("WOLF Specific")
@export var cast_after_flag: String = ""  # После какого флага играть cast_ анимацию
@export var force_dialogue_flag: String = ""  # Принудительный диалог по флагу
@export var force_dialogue_entry_index: int = 0  # Какой entry использовать

@export_group("Death")
@export var death_delay: float = 2.0

@export_group("Normal Maps (Sprite Sheets)")
@export var norm_idle: Texture2D
@export var norm_run: Texture2D
@export var norm_cast: Texture2D
@export var norm_dig: Texture2D
@export var norm_death: Texture2D

var current_normal_sheet: Texture2D
var normal_atlas_texture: AtlasTexture = AtlasTexture.new()

var camera_rig: Node3D
var current_entry: DialogueEntry = null
var is_talking: bool = false
var is_dead: bool = false
var is_digging: bool = false
var is_casting: bool = false
var home_position: Vector3 = Vector3.ZERO
var wander_target: Vector3 = Vector3.ZERO
var is_wandering: bool = false
var force_dialogue_triggered: bool = false
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var last_move_dir: Vector3 = Vector3.BACK  # Запоминаем последнее направление движения

# Антифликер
var current_facing: String = "down"
var facing_change_timer: float = 0.0 # SIIIIX SEVEEEEEEEEEEEEEEEEn
const FACING_CHANGE_COOLDOWN: float = 0.1
const FACING_HYSTERESIS: float = 1.5
var last_anim_name: String = ""

@onready var visuals = $Visuals
@onready var sprite: AnimatedSprite3D = $Visuals/Sprite
@onready var audio_player = $SfxPlayer

func _ready() -> void:
	_init_visuals()
	camera_rig = get_tree().get_first_node_in_group("camera_rig")
	home_position = global_position
	Events.dialogue_ended_ex.connect(_on_dialogue_ended)
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	
	if disappear_on_flag != "":
		Events.world_flag_changed.connect(_on_flag_changed)
		if Events.get_flag(disappear_on_flag):
			_disappear()
	
	# WOLF: слушаем флаги для принудительного диалога
	if force_dialogue_flag != "":
		Events.world_flag_changed.connect(_on_force_dialogue_flag_changed)
	
	if can_wander:
		_start_idle_cycle()
	elif npc_type == NPCType.RAT:
		_start_idle_cycle()

func _process(_delta: float) -> void:
	_update_sprite_normals()

func _physics_process(delta: float) -> void:
	if Events.is_paused or is_dead: return

	if facing_change_timer > 0.0:
		facing_change_timer -= delta

	if not is_on_floor():
		velocity.y -= gravity * delta

	# Каст или копание — стоим на месте
	if is_casting or is_digging:
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return

	_update_sprite_direction()

	if can_wander and is_wandering and not is_talking:
		_process_wander()
	elif not is_wandering:
		velocity.x = move_toward(velocity.x, 0, wander_speed)
		velocity.z = move_toward(velocity.z, 0, wander_speed)

	move_and_slide()

# ==========================================
# СПРАЙТ 4 НАПРАВЛЕНИЯ
# ==========================================
func _update_sprite_direction() -> void:
	if not camera_rig or is_dead or is_casting or is_digging: return

	var face_dir: Vector3
	if is_talking:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			face_dir = global_position.direction_to(player.global_position)
		else:
			face_dir = last_move_dir
	elif is_wandering and velocity.length() > 0.1:
		face_dir = Vector3(velocity.x, 0, velocity.z).normalized()
		last_move_dir = face_dir  # Запоминаем
	else:
		# Стоим — используем последнее направление, НЕ камеру
		face_dir = last_move_dir

	_update_facing_from_dir(face_dir)

	var prefix = "idle_"
	var norm_sheet = norm_idle
	if is_wandering and velocity.length() > 0.1:
		prefix = "run_"
		norm_sheet = norm_run

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
# ВЗАИМОДЕЙСТВИЕ
# ==========================================
func interact() -> void:
	if Events.is_in_dialogue or is_dead: return
	is_talking = true
	is_wandering = false
	is_digging = false
	velocity = Vector3.ZERO

	current_entry = _get_matching_entry()
	if current_entry == null or current_entry.lines.size() == 0:
		is_talking = false
		return

	var dialog_ui = get_tree().get_first_node_in_group("dialog_ui")
	if dialog_ui:
		dialog_ui.set_dialog_source(self)
	Events.start_dialogue(current_entry.lines, actor_name, current_entry.voice_lines)

# Принудительный диалог (без нажатия E, вызывается по флагу)
func _force_dialogue(entry_index: int) -> void:
	if Events.is_in_dialogue or is_dead: return
	if entry_index >= dialogue_entries.size(): return
	
	is_talking = true
	is_wandering = false
	is_digging = false
	velocity = Vector3.ZERO
	
	current_entry = dialogue_entries[entry_index]
	if current_entry == null or current_entry.lines.size() == 0:
		is_talking = false
		return
	
	var dialog_ui = get_tree().get_first_node_in_group("dialog_ui")
	if dialog_ui:
		dialog_ui.set_dialog_source(self)
	Events.start_dialogue(current_entry.lines, actor_name, current_entry.voice_lines)

func _on_dialogue_ended(completed: bool) -> void:
	is_talking = false
	if current_entry == null: return

	if completed:
		var set_flags_list: Array[String] = []
		for flag in current_entry.set_flags:
			if flag != "":
				Events.set_flag(flag)
				set_flags_list.append(flag)
		if current_entry.consume_item and Events.current_item != "":
			Events.use_item()
		
		# WOLF: проверяем нужно ли играть cast_ после этого диалога
		if npc_type == NPCType.WOLF and cast_after_flag != "":
			if cast_after_flag in set_flags_list:
				_play_cast()

	current_entry = null
	
	# Возобновляем цикл idle/wander/dig
	if not is_dead and not is_casting:
		_start_idle_cycle()

# ==========================================
# УСЛОВИЯ
# ==========================================
func _get_matching_entry() -> DialogueEntry:
	for entry in dialogue_entries:
		if _check_condition(entry):
			return entry
	return null

func _check_condition(entry: DialogueEntry) -> bool:
	match entry.condition_type:
		DialogueEntry.ConditionType.NONE: return true
		DialogueEntry.ConditionType.HAS_ITEM: return Events.has_item(entry.condition_value)
		DialogueEntry.ConditionType.FLAG_TRUE: return Events.get_flag(entry.condition_value)
		DialogueEntry.ConditionType.FLAG_FALSE: return not Events.get_flag(entry.condition_value)
	return false

# ==========================================
# IDLE CYCLE (WANDER / STAND / DIG)
# ==========================================
func _start_idle_cycle() -> void:
	if is_dead or is_talking or is_casting: return
	
	var wait_time = randf_range(wander_wait_min, wander_wait_max)
	await get_tree().create_timer(wait_time).timeout
	if not is_instance_valid(self) or is_talking or is_dead or is_casting: return
	
	# RAT: случайно выбираем wander / idle / dig
	if npc_type == NPCType.RAT:
		var roll = randf()
		if roll < dig_chance:
			_start_dig()
			return
		elif can_wander and roll < dig_chance + 0.4:
			_start_wander()
			return
		else:
			# Просто стоим и перезапускаем цикл
			_start_idle_cycle()
			return
	
	# Остальные типы: wander если можно
	if can_wander:
		_start_wander()
	else:
		_start_idle_cycle()

func _start_wander() -> void:
	wander_target = home_position + Vector3(
		randf_range(-wander_radius, wander_radius), 
		0, 
		randf_range(-wander_radius, wander_radius)
	)
	is_wandering = true

func _process_wander() -> void:
	var dir = global_position.direction_to(wander_target)
	dir.y = 0
	if global_position.distance_to(wander_target) > 0.3:
		velocity.x = dir.x * wander_speed
		velocity.z = dir.z * wander_speed
	else:
		velocity.x = 0
		velocity.z = 0
		is_wandering = false
		_start_idle_cycle()

# ==========================================
# RAT: КОПАНИЕ
# ==========================================
func _start_dig() -> void:
	is_digging = true
	velocity = Vector3.ZERO
	
	# Случайное направление копания
	var directions = ["down", "up", "left", "right"]
	current_facing = directions[randi() % directions.size()]
	
	last_anim_name = ""
	_set_anim_and_normal("dig_" + current_facing, norm_dig)
	
	var dig_time = randf_range(dig_duration_min, dig_duration_max)
	await get_tree().create_timer(dig_time).timeout
	if is_instance_valid(self) and not is_dead and not is_talking:
		is_digging = false
		last_anim_name = ""
		_start_idle_cycle()

# ==========================================
# WOLF: КАСТ АНИМАЦИЯ
# ==========================================
func _play_cast() -> void:
	is_casting = true
	velocity = Vector3.ZERO
	last_anim_name = ""
	_set_anim_and_normal("cast_" + current_facing, norm_cast)
	# Ждём окончания анимации через _on_sprite_animation_finished

func _on_sprite_animation_finished() -> void:
	if is_dead: return
	
	if sprite.animation.begins_with("cast_"):
		is_casting = false
		last_anim_name = ""
		_start_idle_cycle()

# ==========================================
# WOLF: ПРИНУДИТЕЛЬНЫЙ ДИАЛОГ ПО ФЛАГУ
# ==========================================
func _on_force_dialogue_flag_changed(flag_name: String, _value) -> void:
	if flag_name == force_dialogue_flag and Events.get_flag(force_dialogue_flag):
		if not force_dialogue_triggered:
			force_dialogue_triggered = true
			# Небольшая задержка чтобы не конфликтовать с другими диалогами
			await get_tree().create_timer(0.5).timeout
			if is_instance_valid(self) and not is_dead:
				_force_dialogue(force_dialogue_entry_index)

# ==========================================
# УРОН
# ==========================================
func take_damage(_amount: int) -> void:
	if is_dead: return
	
	# Кто может получать урон
	match npc_type:
		NPCType.GUARD: return   # Неубиваемый
		NPCType.KING: return    # Неубиваемый
		NPCType.RAT: return     # Неубиваемый
		NPCType.AMBIENT: pass   # Может умереть (от врагов)
		NPCType.WOLF: pass      # Может умереть (от всех)
	
	is_dead = true
	is_talking = false
	is_wandering = false
	is_digging = false
	is_casting = false
	velocity = Vector3.ZERO
	
	_flash_red()
	
	last_anim_name = ""
	_set_anim_and_normal("death", norm_death)
	
	var pixel_offset = 4.0 * sprite.pixel_size
	var tween = create_tween()
	tween.tween_property(sprite, "position:y", sprite.position.y - pixel_offset, 0.15)
	
	await get_tree().create_timer(death_delay).timeout
	if is_instance_valid(self):
		queue_free()

func _flash_red() -> void:
	if not sprite: return
	sprite.modulate = Color(1.0, 0.3, 0.3)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)

# ==========================================
# ИСЧЕЗНОВЕНИЕ (GUARD)
# ==========================================
func _on_flag_changed(flag_name: String, _value) -> void:
	if flag_name == disappear_on_flag and Events.get_flag(disappear_on_flag):
		_disappear()

func _disappear() -> void:
	if disappear_is_death:
		last_anim_name = ""
		_set_anim_and_normal("death", norm_death)
		await sprite.animation_finished
	queue_free()

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
