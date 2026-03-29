extends Node3D

@export var trigger_flag: String = "vex_attack"
@export var win_flag: String = "defeated_vex"
@export var enemies_to_spawn: Array[PackedScene] = []
@export var spawn_points: Array[Marker3D] = []

var is_active: bool = false
var spawned_enemies: Array[Node] = []

func _ready() -> void:
	# Если уже победили - удаляем спавнер
	if Events.get_flag(win_flag):
		queue_free()
		return
		
	Events.world_flag_changed.connect(_on_flag_changed)

func _on_flag_changed(flag_name: String, _value) -> void:
	if flag_name == trigger_flag and not is_active:
		_start_wave()

func _start_wave() -> void:
	is_active = true
	
	for i in enemies_to_spawn.size():
		if enemies_to_spawn[i] == null: continue
		var enemy = enemies_to_spawn[i].instantiate()
		get_parent().add_child(enemy)
		
		if i < spawn_points.size() and spawn_points[i] != null:
			enemy.global_position = spawn_points[i].global_position
		else:
			enemy.global_position = global_position # Запасной вариант
			
		spawned_enemies.append(enemy)

func _process(_delta: float) -> void:
	if not is_active: return
	
	var alive: Array[Node] = []
	for enemy in spawned_enemies:
		if is_instance_valid(enemy) and not enemy.is_dead:
			alive.append(enemy)
	spawned_enemies = alive
	
	if spawned_enemies.size() == 0:
		# Все мертвы!
		Events.set_flag(win_flag)
		queue_free()
