extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect

func _ready():
	color_rect.color = Color(0, 0, 0, 1)
	Events.player_died.connect(_on_player_died)
	# Ждём 2 кадра + маленькая пауза, потом плавно светлеем
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	fade_in(0.7)

func fade_in(duration: float = 0.7) -> void:
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, duration)
	await tween.finished

func fade_out(duration: float = 0.7) -> void:
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, duration)
	await tween.finished

func _on_player_died() -> void:
	fade_out(1.0)
