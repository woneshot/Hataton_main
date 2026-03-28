extends Control

# Убедись, что пути @onready точно совпадают с твоим деревом узлов!
@onready var play_button: Button = $MarginContainer/VBoxContainer/Play
@onready var settings_button: Button = $MarginContainer/VBoxContainer/Settings
@onready var exit_button: Button = $MarginContainer/VBoxContainer/Exit

func _ready() -> void:
	# 1. Сбрасываем все старые соединения, чтобы не было ошибок дублирования
	_disconnect_signals()
	
	# 2. Подключаем заново (Чистый код по Библии)
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	
	# 3. Устанавливаем фокус для управления с клавиатуры
	play_button.grab_focus()
	
	print("Меню инициализировано. Кнопки готовы.")

func _disconnect_signals() -> void:
	if play_button.pressed.is_connected(_on_play_pressed):
		play_button.pressed.disconnect(_on_play_pressed)
	if settings_button.pressed.is_connected(_on_settings_pressed):
		settings_button.pressed.disconnect(_on_settings_pressed)
	if exit_button.pressed.is_connected(_on_exit_pressed):
		exit_button.pressed.disconnect(_on_exit_pressed)

func _on_play_pressed() -> void:
	print("Нажата кнопка ИГРАТЬ")
	# Путь к уровню согласно Библии
	get_tree().change_scene_to_file("res://scenes/levels/level_1.tscn")

func _on_settings_pressed() -> void:
	print("Нажаты НАСТРОЙКИ")

func _on_exit_pressed() -> void:
	print("Кнопка ВЫХОД нажата успешно!")
	get_tree().quit()

# Защита от прокликивания сквозь UI (Раздел 11 Библии)
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if get_viewport().gui_get_focus_owner() != null:
			get_viewport().set_input_as_handled()
