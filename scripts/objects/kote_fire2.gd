extends GPUParticles3D

func _ready():
	_setup_fire()

func _setup_fire() -> void:
	var mat = ParticleProcessMaterial.new()
	
	# Форма — кольцо вокруг котла (/ 4)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = 3         # было 3
	mat.emission_ring_inner_radius = 1    # было 1
	mat.emission_ring_height = 0.05        # было 0.05
	mat.emission_ring_axis = Vector3.UP
	
	# Скорость и гравитация (/ 4)
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 0.125         # было 0.5
	mat.initial_velocity_max = 0.5           # было 2.0
	mat.gravity = Vector3(0, 0.5, 0)         # было 2.0
	
	# Турбулентность (масштаб / 4, сила / 4)
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = 0.5      # было 2.0
	mat.turbulence_noise_speed_random = 0.5
	mat.turbulence_noise_scale = 1.0         # было 4.0
	mat.turbulence_influence_min = 0.3
	mat.turbulence_influence_max = 0.6
	
	# Цвет — без изменений
	var gradient = Gradient.new()
	gradient.set_offset(0, 0.0)
	gradient.set_color(0, Color(1.0, 0.95, 0.4, 1.0))
	gradient.add_point(0.15, Color(1.0, 0.7, 0.1, 1.0))
	gradient.add_point(0.35, Color(1.0, 0.35, 0.05, 0.9))
	gradient.add_point(0.6, Color(0.6, 0.1, 0.02, 0.6))
	gradient.set_offset(1, 1.0)
	gradient.set_color(1, Color(0.15, 0.08, 0.05, 0.0))
	
	var color_ramp = GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp
	
	# Размер частиц (/ 4)
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.3))
	scale_curve.add_point(Vector2(0.2, 1.0))
	scale_curve.add_point(Vector2(0.6, 0.7))
	scale_curve.add_point(Vector2(1.0, 0.1))
	var scale_texture = CurveTexture.new()
	scale_texture.curve = scale_curve
	mat.scale_min = 0.0025                   # было 0.01
	mat.scale_max = 0.0125                   # было 0.05
	mat.scale_curve = scale_texture
	
	process_material = mat
	amount = 60
	lifetime = 1.0
	explosiveness = 0.0
	randomness = 0.3
	fixed_fps = 30
	one_shot = false
	emitting = true
	
	# Меш — квадратики (/ 4)
	var quad = QuadMesh.new()
	quad.size = Vector2(0.075, 0.075)        # было 0.3, 0.3
	draw_pass_1 = quad
	
	# Материал — без изменений
	var draw_mat = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	draw_mat.emission_enabled = true
	draw_mat.emission = Color(1.0, 0.5, 0.1)
	draw_mat.emission_energy_multiplier = 3.0
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.no_depth_test = true
	quad.material = draw_mat
