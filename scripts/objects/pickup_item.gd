extends Area3D

@export var item_id: String = ""
@export var used_flag: String = ""
@export var pickup_sfx: AudioStream
@export var bob_speed: float = 2.0
@export var bob_height: float = 0.15
@export var rotate_speed: float = 1.5

@onready var pickup_sound = $PickupSound
@onready var model_holder = $ModelHolder

var base_y: float = 0.0
var time: float = 0.0

func _ready() -> void:
	if used_flag != "" and Events.get_flag(used_flag):
		queue_free()
		return
	
	base_y = model_holder.position.y
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	time += delta
	model_holder.position.y = base_y + sin(time * bob_speed) * bob_height
	model_holder.rotate_y(rotate_speed * delta)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"): return
	
	Events.pick_up_item(item_id)
	
	if pickup_sfx and pickup_sound:
		pickup_sound.stream = pickup_sfx
		pickup_sound.play()
	
	model_holder.visible = false
	set_deferred("monitoring", false)
	
	if pickup_sfx and pickup_sound:
		await pickup_sound.finished
	
	queue_free()
