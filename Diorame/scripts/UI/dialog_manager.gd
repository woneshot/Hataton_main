extends CanvasLayer

signal dialog_finished 

@onready var dialog_panel: Panel = $Panel
@onready var text_label: Label = $Panel/DialogText

var lines: Array[String] = []
var current_line_index: int = 0

var is_typing: bool = false
var type_timer: float = 0.0
var type_speed: float = 0.03 
var visible_chars: int = 0

# НОВЫЕ ПЕРЕМЕННЫЕ ДЛЯ ДИСТАНЦИИ
var active_player: Node3D = null
var active_npc: Node3D = null
var break_distance: float = 1.5 # Расстояние разрыва диалога (в метрах)

func _ready() -> void:
	dialog_panel.hide()

func _process(delta: float) -> void:
	# === ПРОВЕРКА РАЗРЫВА ДИСТАНЦИИ ===
	if dialog_panel.visible and active_player and active_npc:
		var dist = active_player.global_position.distance_to(active_npc.global_position)
		if dist > break_distance:
			close_dialog() # Игрок убежал - жестко закрываем диалог!

	# Пишущая машинка
	if is_typing:
		type_timer += delta
		if type_timer >= type_speed:
			type_timer = 0.0
			visible_chars += 1
			text_label.visible_characters = visible_chars
			
			if visible_chars >= text_label.text.length():
				is_typing = false

func _input(event: InputEvent) -> void:
	if dialog_panel.visible and event.is_action_pressed("interact"):
		if is_typing:
			text_label.visible_characters = text_label.text.length()
			is_typing = false
		else:
			next_line()

# ТЕПЕРЬ МЫ ПРИНИМАЕМ ИГРОКА И NPC
func start_dialog(new_lines: Array[String], player: Node3D, npc: Node3D) -> void:
	if new_lines.is_empty(): return
	
	lines = new_lines
	current_line_index = 0
	active_player = player
	active_npc = npc
	
	dialog_panel.show()
	show_line()

func show_line() -> void:
	text_label.text = lines[current_line_index]
	text_label.visible_characters = 0
	visible_chars = 0
	is_typing = true

func next_line() -> void:
	current_line_index += 1
	if current_line_index < lines.size():
		show_line()
	else:
		close_dialog()

# УНИВЕРСАЛЬНОЕ ЗАКРЫТИЕ
func close_dialog() -> void:
	dialog_panel.hide()
	active_player = null
	active_npc = null
	dialog_finished.emit() # Говорим NPC, что можно идти гулять
