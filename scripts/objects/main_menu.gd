extends Control

# --- РЕСУРСЫ ---
const SETTINGS_SCENE = preload("res://scenes/ui/settings_menu.tscn")
const LEVEL_1_PATH = "res://scenes/ui/cutscene.tscn"

# --- НАСТРОЙКИ АНИМАЦИИ ---
@export var fade_duration: float = 0.5
@export var hover_size_multiplier: float = 1.15 # На сколько увеличивать (15%)
# В начало скрипта к остальным переменным
var p_tween: Tween
var glow_color = Color(1.3, 1.3, 1.6) # Голубое свечение (HDR)
var normal_color = Color(1, 1, 1)
var particles_normal_speed: float = 3.0   # Скорость в обычном состоянии
var particles_fast_speed: float = 9.5     # Скорость при наведении
# Переменная для хранения исходного размера (Раздел 2.3 Библии: Game Feel)
@onready var original_min_size: Vector2 = Vector2(0, 0) 
@onready var particles: CPUParticles2D = $MenuParticles # Убедись, что путь верный
# --- ССЫЛКИ НА УЗЛЫ ---
@onready var new_game_button: TextureButton = $MarginContainer/VBoxContainer/BtnNewGame
@onready var settings_button: TextureButton = $MarginContainer/VBoxContainer/BtnSettings
@onready var quit_button: TextureButton = $MarginContainer/VBoxContainer/BtnQuit

func _ready() -> void:
	# 1. Сначала сохраняем размер
	original_min_size = new_game_button.size
	
	# 2. Устанавливаем начальную прозрачность
	self.modulate.a = 0.0
	_fade_in()
	
	# 3. ДАЕМ ФОКУС ДО ПОДКЛЮЧЕНИЯ СИГНАЛОВ
	# Это выделит кнопку для системы ввода, но не запустит анимацию _on_btn_hover
	new_game_button.grab_focus()
	
	# 4. И ТОЛЬКО ТЕПЕРЬ подключаем сигналы
	_setup_signals()

func _setup_signals() -> void:
	# Нажатия
	new_game_button.pressed.connect(_on_new_game_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Свечение и изменение размера при наведении/фокусе
	for btn in [new_game_button, settings_button, quit_button]:
		if btn:
			btn.mouse_entered.connect(_on_btn_hover.bind(btn))
			btn.mouse_exited.connect(_on_btn_exit.bind(btn))
			btn.focus_entered.connect(_on_btn_hover.bind(btn))
			btn.focus_exited.connect(_on_btn_exit.bind(btn))

# --- ЛОГИКА АНИМАЦИИ (Fade) ---

func _fade_in() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, fade_duration).set_trans(Tween.TRANS_SINE)

func _fade_out_and_change_scene(path: String) -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_duration).set_trans(Tween.TRANS_SINE)
	await tween.finished
	get_tree().change_scene_to_file(path)

# --- ОБРАБОТЧИКИ ---

func _on_new_game_pressed() -> void:
	if ResourceLoader.exists(LEVEL_1_PATH):
		_fade_out_and_change_scene(LEVEL_1_PATH)
	else:
		print("Ошибка: Сцена уровня не найдена: ", LEVEL_1_PATH)

func _on_settings_pressed() -> void:
	var settings_instance = SETTINGS_SCENE.instantiate()
	get_parent().add_child(settings_instance)
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	await tween.finished
	self.hide()
	
	settings_instance.tree_exited.connect(func():
		self.show()
		var t = create_tween()
		t.tween_property(self, "modulate:a", 1.0, 0.2)
		
		# --- ИСПРАВЛЕНИЕ ТУТ ---
		new_game_button.set_block_signals(true) # Выключаем сигналы
		new_game_button.grab_focus()            # Даем фокус (анимация не сработает)
		new_game_button.set_block_signals(false)# Включаем сигналы обратно
	)

func _on_quit_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	get_tree().quit()

# --- ЭФФЕКТЫ КНОПОК (Твой новый блок) ---

# --- ЭФФЕКТЫ КНОПОК ---

func _on_btn_hover(btn: TextureButton) -> void:
	# 1. Анимация кнопки (тут kill не обязателен, т.к. кнопки разные, но для частиц — критично)
	var btn_tween = create_tween().set_parallel(true)
	btn_tween.tween_property(btn, "self_modulate", glow_color, 0.1)
	var target_size = original_min_size * hover_size_multiplier
	btn_tween.tween_property(btn, "custom_minimum_size", target_size, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 2. Анимация частиц
	if particles:
		if p_tween: p_tween.kill() # Останавливаем старую анимацию частиц
		p_tween = create_tween().set_parallel(true)
		p_tween.tween_property(particles, "speed_scale", particles_fast_speed, 0.3)
		p_tween.tween_property(particles, "color", glow_color, 0.3)

func _on_btn_exit(btn: TextureButton) -> void:
	# 1. Возврат кнопки
	var btn_tween = create_tween().set_parallel(true)
	btn_tween.tween_property(btn, "self_modulate", normal_color, 0.1)
	btn_tween.tween_property(btn, "custom_minimum_size", original_min_size, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	
	# 2. Возврат частиц
	if particles:
		if p_tween: p_tween.kill() # Останавливаем старую анимацию частиц
		p_tween = create_tween().set_parallel(true)
		p_tween.tween_property(particles, "speed_scale", particles_normal_speed, 0.5)
		p_tween.tween_property(particles, "color", Color(1, 1, 1, 0.3), 0.5)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if get_viewport().gui_get_focus_owner() == null:
			new_game_button.grab_focus()
