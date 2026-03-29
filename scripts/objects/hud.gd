extends CanvasLayer

# Согласно роли UI-разработчика, мы работаем с экспортами для быстрой настройки
@export_group("Health Bar Settings")
@export var health_bar: TextureProgressBar
@export var danger_threshold: int = 3
@export var danger_color: Color = Color.RED
@export var normal_color: Color = Color.WHITE

var flash_tween: Tween
var bar_tween: Tween

func _ready() -> void:
	# 1. Валидация (Раздел Тимлид: проверка связей)
	if not health_bar:
		push_error("UI ERROR: HealthBar не привязан в инспекторе HUD!")
		return

	# 2. ПОДКЛЮЧЕНИЕ (Раздел 2: Работа через шину Events)
	# Мы не лезем в код игрока, мы просто слушаем глобальный сигнал
	Events.player_damaged.connect(_on_player_damaged)
	
	# 3. ИНИЦИАЛИЗАЦИЯ (Раздел 11: Интеграция)
	# При старте запрашиваем данные у игрока, чтобы синхронизировать полоску
	call_deferred("_initial_sync")

func _initial_sync() -> void:
	# По библии (Раздел 11), игрок всегда в группе "player"
	var player = get_tree().get_first_node_in_group("player")
	if player:
		health_bar.max_value = player.max_health
		health_bar.value = player.health
		_check_danger_state(player.health)

func _on_player_damaged(current_health: int) -> void:
	# Анимация изменения (Раздел: Качество кода)
	if bar_tween:
		bar_tween.kill()
	
	bar_tween = create_tween()
	bar_tween.tween_property(health_bar, "value", current_health, 0.25)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	
	# Проверка критического состояния
	_check_danger_state(current_health)

func _check_danger_state(hp: int) -> void:
	if hp <= danger_threshold and hp > 0:
		_start_flashing()
	else:
		_stop_flashing()

# --- ВИЗУАЛЬНЫЕ ЭФФЕКТЫ (Твоя прямая обязанность как UI-ника) ---

func _start_flashing() -> void:
	if flash_tween and flash_tween.is_running():
		return
		
	flash_tween = create_tween().set_loops()
	flash_tween.tween_property(health_bar, "tint_progress", danger_color, 0.4)
	flash_tween.tween_property(health_bar, "tint_progress", normal_color, 0.4)

func _stop_flashing() -> void:
	if flash_tween:
		flash_tween.kill()
	
	# Плавный возврат к нормальному цвету
	var reset_tween = create_tween()
	reset_tween.tween_property(health_bar, "tint_progress", normal_color, 0.2)
