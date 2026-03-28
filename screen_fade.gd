extends CanvasLayer
# Путь: res://scripts/objects/screen_fade.gd

@onready var color_rect = $ColorRect

func _ready():
	# Обязательная регистрация в группе согласно разделу 11
	add_to_group("screen_effects")
	
	# Убеждаемся, что экран при старте прозрачный
	color_rect.color.a = 0
	
	# Подписываемся на глобальные события, если они определены в Events.gd
	if Events.has_signal("player_died"):
		Events.connect("player_died", _on_player_died)
	# 1. Применяем текущую яркость сразу при появлении сцены
	update_brightness(Events.current_brightness)
	
	# 2. Подписываемся на будущие изменения (если игрок меняет настройки прямо в игре)
	Events.brightness_updated.connect(update_brightness)
	
func update_brightness(factor: float):
	# Допустим, у тебя там черный ColorRect для фейда, 
	# но нам нужно менять модуляцию всего слоя или фонового спрайта
	self.modulate = Color(factor, factor, factor)
## Плавное появление черного экрана (Fade Out)
func fade_out(duration: float = 1.0) -> void:
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

## Плавное исчезновение черного экрана (Fade In)
func fade_in(duration: float = 1.0) -> void:
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

## Реакция на смерть игрока (из требований по интеграции)
func _on_player_died():
	fade_out(2.0)
