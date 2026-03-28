extends Control

# Время показа каждого слайда (без учёта фейдов)
@export var slide_duration: float = 15.0
@export var fade_duration: float = 1.0
@export var next_scene: String = "res://scenes/levels/location_1.tscn"

@onready var slide_image: TextureRect = $SlideImage

# Хардкод 5 картинок
var slides: Array[Texture2D] = []

func _ready() -> void:
	# Загружаем картинки хардкодом
	slides = [
		preload("res://assets/sprites/cutscene/slide_1.png"),
		preload("res://assets/sprites/cutscene/slide_2.png"),
		preload("res://assets/sprites/cutscene/slide_3.png"),
		preload("res://assets/sprites/cutscene/slide_4.png"),
		preload("res://assets/sprites/cutscene/slide_5.png"),
	]
	
	# Начинаем с чёрного экрана
	slide_image.modulate = Color(1, 1, 1, 0)
	
	_play_cutscene()


func _play_cutscene() -> void:
	for i in slides.size():
		# Ставим картинку (пока невидимую)
		slide_image.texture = slides[i]
		
		# Fade in — появление
		var tween_in = create_tween()
		tween_in.tween_property(slide_image, "modulate:a", 1.0, fade_duration)
		await tween_in.finished
		
		# Показываем слайд
		await get_tree().create_timer(slide_duration).timeout
		
		# Fade out — затухание
		var tween_out = create_tween()
		tween_out.tween_property(slide_image, "modulate:a", 0.0, fade_duration)
		await tween_out.finished
	
	# После последнего слайда — переход на первую сцену игры
	# Используем ScreenEffects если он есть, иначе просто меняем сцену
	get_tree().change_scene_to_file(next_scene)


func _input(event: InputEvent) -> void:
	# Пропуск катсцены по Escape или E
	if event.is_action_pressed("pause") or event.is_action_pressed("interact"):
		_skip()


func _skip() -> void:
	# Останавливаем все твины
	var tweens = get_tree().get_processed_tweens()
	# Просто сразу переходим
	get_tree().change_scene_to_file(next_scene)
