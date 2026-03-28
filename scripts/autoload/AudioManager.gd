extends Node

var music_bus: int
var duck_db: float = -15.0
var normal_db: float = -6.0

func _ready():
	music_bus = AudioServer.get_bus_index("Music")
	Events.dialogue_started.connect(_on_dialogue_start)
	Events.dialogue_ended.connect(_on_dialogue_end)

func _on_dialogue_start(_lines, _name, _voice):
	var tween = create_tween()
	tween.tween_method(_set_music_vol, normal_db, duck_db, 0.5)

func _on_dialogue_end():
	var tween = create_tween()
	tween.tween_method(_set_music_vol, duck_db, normal_db, 0.5)

func _set_music_vol(value: float) -> void:
	AudioServer.set_bus_volume_db(music_bus, value)

func play_sfx(stream: AudioStream, position: Vector3 = Vector3.ZERO) -> void:
	var p = AudioStreamPlayer3D.new()
	add_child(p)
	p.stream = stream
	p.bus = &"SFX"
	p.global_position = position
	p.pitch_scale = randf_range(0.9, 1.1)
	p.play()
	p.finished.connect(p.queue_free)
