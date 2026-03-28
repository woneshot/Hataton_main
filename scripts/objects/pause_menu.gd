extends CanvasLayer

# --- НАСТРОЙКИ (Как в Main Menu) ---
var glow_color = Color(1.3, 1.3, 1.6) 
var normal_color = Color(1, 1, 1)

@export var hover_size_multiplier: float = 1.15
@onready var original_min_size: Vector2 = Vector2(0, 0)

# --- ССЫЛКИ НА УЗЛЫ ---
@onready var resume_button: TextureButton = $MarginContainer/VBoxContainer/BtnContinue
@onready var settings_button: TextureButton = $MarginContainer/VBoxContainer/BtnSettings
@onready var quit_button: TextureButton = $MarginContainer/VBoxContainer/BtnQuit

const SETTINGS_SCENE = preload("res://scenes/ui/settings_menu.tscn")

func _ready() -> void:
	hide()
	original_min_size = resume_button.size
	process_mode = Node.PROCESS_MODE_ALWAYS 
	_setup_signals()

func _setup_signals() -> void:
	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	for btn in [resume_button, settings_button, quit_button]:
		if btn:
			btn.mouse_entered.connect(_on_btn_hover.bind(btn))
			btn.mouse_exited.connect(_on_btn_exit.bind(btn))
			btn.focus_entered.connect(_on_btn_hover.bind(btn))
			btn.focus_exited.connect(_on_btn_exit.bind(btn))

# --- ЭФФЕКТЫ КНОПОК ---

func _on_btn_hover(btn: TextureButton) -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(btn, "self_modulate", glow_color, 0.1)
	var target_size = original_min_size * hover_size_multiplier
	tween.tween_property(btn, "custom_minimum_size", target_size, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_btn_exit(btn: TextureButton) -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(btn, "self_modulate", normal_color, 0.1)
	tween.tween_property(btn, "custom_minimum_size", original_min_size, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

# --- ЛОГИКА ПАУЗЫ ---

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): 
		if not visible:
			_pause_game()
		else:
			_resume_game()
	if event is InputEventMouseMotion:
		# Сила параллакса (чем меньше число, тем мягче эффект)
		var drift = event.relative * 0.05 
		var tween = create_tween()
		# Двигаем весь MarginContainer или спрайт фона
		tween.tween_property($Background, "position", $Background.position + Vector2(drift.x, drift.y), 0.5).set_trans(Tween.TRANS_SINE)

func _pause_game() -> void:
	show()
	get_tree().paused = true
	
	# ИСПРАВЛЕНИЕ: Блокируем сигналы при первом появлении паузы
	resume_button.set_block_signals(true)
	resume_button.grab_focus()
	resume_button.set_block_signals(false)

func _resume_game() -> void:
	hide()
	get_tree().paused = false

# --- ОБРАБОТЧИКИ ---

func _on_resume_pressed() -> void:
	_resume_game()

func _on_settings_pressed() -> void:
	var settings = SETTINGS_SCENE.instantiate()
	settings.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(settings) 
	self.hide()
	
	settings.tree_exited.connect(func(): 
		if is_instance_valid(self):
			self.show()
			
			# ИСПРАВЛЕНИЕ: Блокируем сигналы при возврате из настроек
			resume_button.set_block_signals(true)
			resume_button.grab_focus()
			resume_button.set_block_signals(false)
	)

func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
