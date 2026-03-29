extends CanvasLayer

@export var close_distance: float = 3.5

@export var chars_per_second: float = 30.0

var lines: Array[String] = []
var voice_lines: Array = []
var current_line_index: int = 0
var actor_name: String = ""
var dialog_source: Node3D = null
var player: Node3D = null
var is_typing: bool = false
var voice_player: AudioStreamPlayer3D = null
var completed: bool = false  # Дочитал ли игрок всё до конца

@onready var dialog_root = $DialogRoot
@onready var actor_name_label = $DialogRoot/Panel/MarginContainer/VBoxContainer/ActorName
@onready var dialog_text = $DialogRoot/Panel/MarginContainer/VBoxContainer/DialogText
@onready var continue_hint = $DialogRoot/Panel/MarginContainer/VBoxContainer/ContinueHint

func _ready() -> void:
	dialog_root.hide()
	Events.dialogue_started.connect(_on_dialogue_started)

func _process(_delta: float) -> void:
	if not dialog_root.visible: return
	
	# Автозакрытие если игрок отошел далеко
	if dialog_source and player:
		if player.global_position.distance_to(dialog_source.global_position) > close_distance:
			_close_dialogue()
			
	# Скрываем хинт прозрачностью, чтобы текст не прыгал вверх-вниз
	if is_typing:
		continue_hint.modulate = Color(1, 1, 1, 0)
	else:
		continue_hint.modulate = Color(1, 1, 1, 1)

func _input(event: InputEvent) -> void:
	if not dialog_root.visible: return
	
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if is_typing:
			_show_full_line()
		else:
			_advance()

func _on_dialogue_started(new_lines: Array[String], new_actor_name: String, new_voice_lines: Array) -> void:
	lines = new_lines
	voice_lines = new_voice_lines
	actor_name = new_actor_name
	current_line_index = 0
	completed = false
	player = get_tree().get_first_node_in_group("player")
	
	if actor_name != "":
		actor_name_label.text = actor_name
		actor_name_label.show()
	else:
		actor_name_label.hide()
		
	dialog_root.show()
	_show_line()

func set_dialog_source(source: Node3D) -> void:
	dialog_source = source
	voice_player = source.get_node_or_null("SfxPlayer")
	if not voice_player:
		voice_player = source.get_node_or_null("AudioStreamPlayer3D")
	
	# Направляем на шину Voice
	if voice_player:
		voice_player.bus = &"Voice"

func _show_line() -> void:
	if current_line_index >= lines.size():
		completed = true
		_close_dialogue()
		return
		
	_play_voice_line(current_line_index)
	var full_text = lines[current_line_index]
	
	if chars_per_second > 0:
		_type_text(full_text)
	else:
		dialog_text.text = full_text
		is_typing = false

func _play_voice_line(index: int) -> void:
	if not voice_player: return
	if voice_player.playing: voice_player.stop()
	
	if index < voice_lines.size() and voice_lines[index] != null:
		voice_player.stream = voice_lines[index]
		voice_player.play()

func _type_text(full_text: String) -> void:
	is_typing = true
	dialog_text.text = ""
	
	for i in full_text.length():
		if not is_typing: return
		dialog_text.text += full_text[i]
		await get_tree().create_timer(1.0 / chars_per_second).timeout
		
	is_typing = false

func _show_full_line() -> void:
	is_typing = false
	if current_line_index < lines.size():
		dialog_text.text = lines[current_line_index]

func _advance() -> void:
	current_line_index += 1
	if current_line_index >= lines.size():
		completed = true
		_close_dialogue()
	else:
		_show_line()

func _close_dialogue() -> void:
	is_typing = false
	dialog_root.hide()
	
	var was_completed = completed
	
	lines = []
	voice_lines = []
	current_line_index = 0
	completed = false
	dialog_source = null
	
	if voice_player and voice_player.playing: voice_player.stop()
	voice_player = null
	
	Events.end_dialogue_ex(was_completed)
