extends Area3D

@export var item_id: String = ""
@export var used_flag: String = ""
@export var pickup_sfx: AudioStream
@export var bob_speed: float = 0
@export var bob_height: float = 0
@export var required_flag: String = "quest_started"

@export_group("Particles")
@export var particle_color: Color = Color(1.0, 0.9, 0.4, 0.8)

@onready var pickup_sound = $PickupSound
@onready var model_holder = $ModelHolder
@onready var particles: GPUParticles3D = $PickupParticles

var base_y: float = 0.0
var time: float = 0.0
var quest_active: bool = false

func _ready() -> void:
	if used_flag != "" and Events.get_flag(used_flag):
		queue_free()
		return
	
	base_y = model_holder.position.y
	
	# Проверяем флаг при загрузке
	quest_active = Events.get_flag(required_flag)
	
	# Слушаем изменения флагов
	Events.world_flag_changed.connect(_on_flag_changed)
	
	_update_availability()
	_setup_particles()

func _process(delta: float) -> void:
	if not quest_active: return
	time += delta
	model_holder.position.y = base_y + sin(time * bob_speed) * bob_height

func interact() -> void:
	# Нельзя брать без флага
	if not quest_active:
		return
	
	# Нельзя брать если уже есть предмет
	if Events.current_item != "":
		return
	
	Events.pick_up_item(item_id)
	
	if pickup_sfx and pickup_sound:
		pickup_sound.stream = pickup_sfx
		pickup_sound.play()
	
	particles.emitting = false
	model_holder.visible = false
	
	if pickup_sfx and pickup_sound:
		await pickup_sound.finished
	
	if is_instance_valid(self):
		queue_free()

func _on_flag_changed(flag_name: String, _value) -> void:
	if flag_name == required_flag:
		quest_active = Events.get_flag(required_flag)
		_update_availability()

func _update_availability() -> void:
	if quest_active:
		particles.emitting = true
		model_holder.visible = true
	else:
		particles.emitting = false
		# Модель видна но без партиклов — просто лежит как декор
		# Если хочешь скрыть полностью:
		# model_holder.visible = false

func _setup_particles() -> void:
	if not particles: return
	
	var mat = ParticleProcessMaterial.new()
	
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.3
	
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 10.0
	mat.initial_velocity_min = 0.2
	mat.initial_velocity_max = 0.4
	mat.gravity = Vector3.ZERO
	
	var gradient = Gradient.new()
	gradient.set_offset(0, 0.0)
	gradient.set_color(0, particle_color)
	gradient.set_offset(1, 1.0)
	gradient.set_color(1, Color(particle_color.r, particle_color.g, particle_color.b, 0.0))
	var color_ramp = GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp
	
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.3))
	scale_curve.add_point(Vector2(0.5, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var scale_texture = CurveTexture.new()
	scale_texture.curve = scale_curve
	mat.scale_min = 0.02
	mat.scale_max = 0.04
	mat.scale_curve = scale_texture
	
	particles.process_material = mat
	particles.amount = 6
	particles.lifetime = 1.2
	particles.fixed_fps = 30
	particles.one_shot = false
	particles.emitting = false  # Выключены по умолчанию
	
	var quad = QuadMesh.new()
	quad.size = Vector2(0.04, 0.04)
	particles.draw_pass_1 = quad
	
	var draw_mat = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.emission_enabled = true
	draw_mat.emission = particle_color
	draw_mat.emission_energy_multiplier = 1.5
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = draw_mat
