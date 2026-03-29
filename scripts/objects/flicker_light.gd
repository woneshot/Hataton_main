
extends OmniLight3D 
@export var energy_min: float = 1.0 
@export var energy_max: float = 2.0 
@export var flicker_speed: float = 4.0 
var time: float = 0.0 
func _process(delta: float) -> void: 
	time += delta * flicker_speed 
	light_energy = lerp(energy_min, energy_max, (sin(time) + 1.0) / 2.0) 
	omni_range = lerp(5.0, 5.5, (cos(time * 0.5) + 1.0) / 2.0)
