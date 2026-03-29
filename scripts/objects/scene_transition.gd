extends StaticBody3D

@export var target_scene: PackedScene
@export var required_flag: String = ""
@export var transition_sfx: AudioStream

@export_group("Portal Visuals")
@export var portal_width: float = 2.0
@export var portal_color_1: Color = Color(0.3, 0.8, 1.0, 0.8)
@export var portal_color_2: Color = Color(0.1, 0.4, 0.9, 0.0)

var is_transitioning: bool = false

@onready var particles: GPUParticles3D = $PortalParticles
@onready var sfx_player: AudioStreamPlayer3D = $SfxPlayer

func _ready() -> void:
	_setup_portal_particles()

func interact() -> void:
	if is_transitioning: return
	if target_scene == null: return
	if required_flag != "" and not Events.get_flag(required_flag): return
	
	is_transitioning = true
	
	if transition_sfx and sfx_player:
		sfx_player.stream = transition_sfx
		sfx_player.play()
	
	var fade = get_tree().get_first_node_in_group("screen_effects")
	if fade:
		await fade.fade_out(0.7)        # Плавно темнеет 0.7 сек
		await get_tree().create_timer(0.3).timeout  # Пауза в темноте
	
	get_tree().change_scene_to_packed(target_scene)

func _setup_portal_particles() -> void:
	var mat = ParticleProcessMaterial.new()
	
	# Линия частиц вдоль порога (по X)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(portal_width / 2.0, 0.05, 0.05)
	
	# Летят вверх
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 15.0
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.5
	mat.gravity = Vector3.ZERO
	
	# Цвет
	var gradient = Gradient.new()
	gradient.set_offset(0, 0.0)
	gradient.set_color(0, portal_color_1)
	gradient.set_offset(1, 1.0)
	gradient.set_color(1, portal_color_2)
	
	var color_ramp = GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp
	
	# Размер
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.5))
	scale_curve.add_point(Vector2(0.5, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var scale_texture = CurveTexture.new()
	scale_texture.curve = scale_curve
	mat.scale_min = 0.03
	mat.scale_max = 0.07
	mat.scale_curve = scale_texture
	
	particles.process_material = mat
	particles.amount = 100
	
	particles.lifetime = 1.5
	particles.explosiveness = 0.0
	particles.randomness = 0.2
	particles.fixed_fps = 30
	particles.one_shot = false
	particles.position = Vector3(0, 0.05, 0)  # Чуть над полом
	
	# Меш — маленькие квадратики
	var quad = QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	particles.draw_pass_1 = quad
	
	# Светящийся материал
	var draw_mat = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.emission_enabled = true
	draw_mat.emission = portal_color_1
	draw_mat.emission_energy_multiplier = 2.0
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = draw_mat
