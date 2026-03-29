extends Control

var glow_color = Color(1.3, 1.3, 1.6)
var normal_color = Color(1, 1, 1)
@export var hover_size_multiplier: float = 1.15
@onready var original_min_size: Vector2 = Vector2(0, 0)

@export_group("Audio Bus Names")
@export var master_bus: String = "Master"
@export var voice_bus: String = "Voice"
@export var sfx_bus: String = "Sfx"

@onready var master_slider: HSlider = $MarginContainer/VBoxContainer/HBoxContainer/GenVolSlider
@onready var voice_slider: HSlider = $MarginContainer/VBoxContainer/HBoxContainer2/VoiceVolSlider
@onready var sfx_slider: HSlider = $MarginContainer/VBoxContainer/HBoxContainer3/SFXVolSlider
@onready var brightness_slider: HSlider = $MarginContainer/VBoxContainer/HBoxContainer4/BrightnessSlider
@onready var back_button: TextureButton = $MarginContainer/VBoxContainer/Back

var config = ConfigFile.new()
const SAVE_PATH = "user://settings.cfg"

func _ready() -> void:
	original_min_size = back_button.size
	_load_settings()
	_setup_signals()

# ✅ НОВОЕ: Закрытие настроек по ESC
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()  # ← Не даём событию уйти дальше
		queue_free()

func _setup_signals() -> void:
	master_slider.value_changed.connect(_on_volume_changed.bind(master_bus))
	voice_slider.value_changed.connect(_on_volume_changed.bind(voice_bus))
	sfx_slider.value_changed.connect(_on_volume_changed.bind(sfx_bus))
	brightness_slider.value_changed.connect(_on_brightness_changed)

	if back_button:
		back_button.pressed.connect(func(): queue_free())
		back_button.mouse_entered.connect(_on_btn_hover.bind(back_button))
		back_button.mouse_exited.connect(_on_btn_exit.bind(back_button))
		back_button.focus_entered.connect(_on_btn_hover.bind(back_button))
		back_button.focus_exited.connect(_on_btn_exit.bind(back_button))

	var sliders = [master_slider, voice_slider, sfx_slider, brightness_slider]
	for slider in sliders:
		if slider:
			slider.mouse_entered.connect(_on_slider_glow.bind(slider, true))
			slider.mouse_exited.connect(_on_slider_glow.bind(slider, false))

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

func _on_volume_changed(value: float, bus_name: String) -> void:
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index != -1:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value / 100.0))
		_save_local("audio", bus_name, value)

func _on_brightness_changed(value: float) -> void:
	var exposure_value = 0.5 + (value / 50.0)
	var world_env = get_tree().current_scene.find_child("WorldEnvironment", true, false)
	if world_env and world_env.environment:
		world_env.environment.tonemap_exposure = exposure_value
		world_env.environment.background_energy_multiplier = exposure_value
	_save_local("video", "brightness", value)

func _save_local(section: String, key: String, value: Variant) -> void:
	var cfg = ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value(section, key, value)
	cfg.save("user://settings.cfg")

func _load_settings() -> void:
	if config.load(SAVE_PATH) == OK:
		master_slider.value = config.get_value("audio", master_bus, 75.0)
		voice_slider.value = config.get_value("audio", voice_bus, 75.0)
		sfx_slider.value = config.get_value("audio", sfx_bus, 75.0)
		brightness_slider.value = config.get_value("video", "brightness", 100.0)
