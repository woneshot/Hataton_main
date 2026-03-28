extends Area3D

@export_file("*.tscn") var target_scene: String
@export var required_flag: String = ""  # Например: level_completed
@export var interact_to_use: bool = true # E для перехода, или просто зайти

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if not interact_to_use and _can_transition(body):
		_do_transition()

func interact() -> void:
	if interact_to_use and _can_transition(get_tree().get_first_node_in_group("player")):
		_do_transition()

func _can_transition(body: Node3D) -> bool:
	if not body or not body.is_in_group("player"): return false
	if required_flag != "" and not Events.get_flag(required_flag): return false
	return true

func _do_transition() -> void:
	# Можно добавить вызов fade_out здесь
	get_tree().change_scene_to_file(target_scene)
