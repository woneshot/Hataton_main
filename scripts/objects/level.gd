extends Node3D

@export_group("Level Settings")
@export var monologue_flag: String = ""  # Уникальный флаг, чтобы монолог не повторялся (например, "mono_level_1")
@export var monologue_lines: Array[String] = []

func _ready() -> void:
	# Обязательно регаем сцену (это часть архитектуры из Библии)
	Events.register_scene(scene_file_path)
	
	# Если на уровне задан монолог и мы его еще не видели
	if monologue_flag != "" and monologue_lines.size() > 0:
		if not Events.get_flag(monologue_flag):
			Events.set_flag(monologue_flag)
			_play_monologue()

func _play_monologue() -> void:
	# Ждём полсекунды, чтобы камера стабилизировалась и игрок понял, что сцена загрузилась
	await get_tree().create_timer(0.7).timeout
	
	# Запускаем диалог. Передаём пустую строку "" вместо имени.
	Events.start_dialogue(monologue_lines, "Авантюрист") 
