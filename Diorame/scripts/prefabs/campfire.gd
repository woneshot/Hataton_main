extends Node3D

@onready var light: OmniLight3D = $OmniLight3D
var noise = FastNoiseLite.new()
var time: float = 0.0

@export var base_energy: float = 4.0 # Базовая яркость
@export var flicker_speed: float = 50.0 # Скорость дрожания

func _ready() -> void:
	# Настраиваем генератор шума для плавного мерцания
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.05

func _process(delta: float) -> void:
	time += delta * flicker_speed
	
	# Шум генерирует значения от -1 до 1. 
	# Умножаем на 1.5, чтобы свет ощутимо прыгал по яркости.
	var noise_val = noise.get_noise_1d(time)
	light.light_energy = base_energy + (noise_val * 1.5)
	
	# Чуть-чуть меняем радиус освещения, чтобы тени на стенах "плясали"
	light.omni_range = 8.0 + (noise_val * 0.5)
