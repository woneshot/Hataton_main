extends Node

# ==========================================
# СИГНАЛЫ
# ==========================================
signal dialogue_started(lines: Array[String], actor_name: String, voice_lines: Array)
signal dialogue_ended
signal dialogue_ended_ex(completed: bool)

signal item_picked_up(item_id: String)
signal item_used(item_id: String)

signal world_flag_changed(flag_name: String, value)

signal camera_shake_requested(intensity: float, duration: float)
signal player_died
signal player_damaged(new_health: int)

signal scene_transition_requested(scene_path: String)
signal pause_toggled(is_paused: bool)
# Этот сигнал будут слушать все, кому интересно здоровье игрока (включая твой HUD)

# ==========================================
# СОСТОЯНИЯ
# ==========================================
var is_paused: bool = false
var is_in_dialogue: bool = false
var current_item: String = ""
var current_scene_name: String = ""

# ==========================================
# МИРОВЫЕ ФЛАГИ
# ==========================================
var world_flags: Dictionary = {}

func set_flag(flag_name: String, value = true) -> void:
	world_flags[flag_name] = value
	world_flag_changed.emit(flag_name, value)

func get_flag(flag_name: String, default = false):
	return world_flags.get(flag_name, default)

func has_flag(flag_name: String) -> bool:
	return world_flags.has(flag_name)

# ==========================================
# УПРАВЛЕНИЕ СОСТОЯНИЕМ
# ==========================================
func set_paused(value: bool) -> void:
	is_paused = value
	pause_toggled.emit(value)

func start_dialogue(lines: Array[String], actor_name: String = "", voice_lines: Array = []) -> void:
	is_in_dialogue = true
	dialogue_started.emit(lines, actor_name, voice_lines)

func end_dialogue() -> void:
	is_in_dialogue = false
	dialogue_ended.emit()

func end_dialogue_ex(completed: bool) -> void:
	is_in_dialogue = false
	dialogue_ended.emit()
	dialogue_ended_ex.emit(completed)

func pick_up_item(item_id: String) -> void:
	current_item = item_id
	item_picked_up.emit(item_id)

func use_item() -> String:
	var used = current_item
	current_item = ""
	item_used.emit(used)
	return used

func has_item(item_id: String) -> bool:
	return current_item == item_id

func register_scene(scene_path: String) -> void:
	current_scene_name = scene_path
	var short_name = scene_path.get_file().get_basename()
	set_flag("visited_" + short_name, true)

# ==========================================
# СМЕРТЬ
# ==========================================
func handle_player_death() -> void:
	player_died.emit()
	set_paused(true)
	await get_tree().create_timer(1.0).timeout
	get_tree().reload_current_scene()
	is_paused = false
	is_in_dialogue = false
