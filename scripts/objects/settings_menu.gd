extends Control # Или CanvasLayer, если ты его сменил по Библии

# --- НАСТРОЙКИ АНИМАЦИИ (Единый стиль по Библии) ---
var glow_color = Color(1.3, 1.3, 1.6) 
var normal_color = Color(1, 1, 1)
@export var hover_size_multiplier: float = 1.15
@onready var original_min_size: Vector2 = Vector2(0, 0)

# --- ГРУППА НАСТРОЕК АУДИО ---
@export_group("Audio Bus Names")
@export var master_bus: String = "Master"
@export var voice_bus: String = "Voice"
@export var sfx_bus: String = "Sfx"

# --- ССЫЛКИ НА УЗЛЫ ---
@onready var master_slider: HSlider = $MarginContainer/VBoxContainer/HBoxContainer/GenVolSlider
@onready var voice_slider: HSlider = $MarginContainer/VBoxContainer/HBoxContainer2/VoiceVolSlider
@onready var sfx_slider: HSlider = $MarginContainer/VBoxContainer/HBoxContainer3/SFXVolSlider
@onready var brightness_slider: HSlider = $MarginContainer/VBoxContainer/HBoxContainer4/BrightnessSlider
@onready var back_button: TextureButton = $MarginContainer/VBoxContainer/Back

var config = ConfigFile.new()
const SAVE_PATH = "user://settings.cfg"

func _ready() -> void:
	# Инициализация эталонного размера (Раздел 2.3 Библии)
	original_min_size = back_button.size
	
	_load_settings()
	_setup_signals()

func _setup_signals() -> void:
	# 1. Слайдеры
	master_slider.value_changed.connect(_on_volume_changed.bind(master_bus))
	voice_slider.value_changed.connect(_on_volume_changed.bind(voice_bus))
	sfx_slider.value_changed.connect(_on_volume_changed.bind(sfx_bus))
	brightness_slider.value_changed.connect(_on_brightness_changed)
	
	# 2. Кнопка Back
	if back_button:
		back_button.pressed.connect(func(): queue_free())
		
		# Эффекты для кнопки
		back_button.mouse_entered.connect(_on_btn_hover.bind(back_button))
		back_button.mouse_exited.connect(_on_btn_exit.bind(back_button))
		back_button.focus_entered.connect(_on_btn_hover.bind(back_button))
		back_button.focus_exited.connect(_on_btn_exit.bind(back_button))

	# 3. Эффекты для слайдеров (только свечение, без расширения, чтобы не ломать верстку)
	var sliders = [master_slider, voice_slider, sfx_slider, brightness_slider]
	for slider in sliders:
		if slider:
			slider.mouse_entered.connect(_on_slider_glow.bind(slider, true))
			slider.mouse_exited.connect(_on_slider_glow.bind(slider, false))

# --- ЭФФЕКТЫ (Синхронизировано с остальными меню) ---

func _on_btn_hover(btn: TextureButton) -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(btn, "self_modulate", glow_color, 0.1)
	var target_size = original_min_size * hover_size_multiplier
	tween.tween_property(btn, "custom_minimum_size", target_size, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_btn_exit(btn: TextureButton) -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(btn, "self_modulate", normal_color, 0.1)
	tween.tween_property(btn, "custom_minimum_size", original_min_size, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func _on_slider_glow(slider: HSlider, active: bool) -> void:
	var target_color = glow_color if active else normal_color
	create_tween().tween_property(slider, "self_modulate", target_color, 0.1)

# --- ЛОГИКА НАСТРОЕК ---

func _on_volume_changed(value: float, bus_name: String) -> void:
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index != -1:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value / 100.0))
		_save_local("audio", bus_name, value)

func _on_brightness_changed(value: float) -> void:
	var factor = value / 100.0
	var effects = get_tree().get_first_node_in_group("screen_effects")
	if effects:
		effects.modulate = Color(factor, factor, factor)
	_save_local("video", "brightness", value)

func _save_local(section: String, key: String, value: Variant):
	config.set_value(section, key, value)
	config.save(SAVE_PATH)

func _load_settings() -> void:
	if config.load(SAVE_PATH) == OK:
		master_slider.value = config.get_value("audio", master_bus, 75.0)
		voice_slider.value = config.get_value("audio", voice_bus, 75.0)
		sfx_slider.value = config.get_value("audio", sfx_bus, 75.0)
		brightness_slider.value = config.get_value("video", "brightness", 100.0)
