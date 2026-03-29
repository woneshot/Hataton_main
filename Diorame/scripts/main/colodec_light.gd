extends OmniLight3D

var time: float = 0.0

func _process(delta: float) -> void:
	time += delta * 1.0 # Скорость пульсации (меняй, если нужно быстрее/медленнее)
	
	# sin(time) выдает значения от -1 до 1.
	# (sin(time) + 1.0) / 2.0 переводит это в диапазон от 0 до 1.
	# Итог: базовая 0.5 + плавающая добавка от 0.0 до 1.0 = (от 0.5 до 1.5 в пике)
	var pulse = (sin(time) + 1.0) / 2.0 
	
	light_energy = 0.2 + pulse
