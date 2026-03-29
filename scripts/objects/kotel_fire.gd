extends GPUParticles3D

func _ready():
	_setup_fire()

func _setup_fire() -> void:
	var mat = ParticleProcessMaterial.new()
	
# Форма — кольцо вокруг котла
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = 3
	
	mat.emission_ring_inner_radius = 1
	
	
	mat.emission_ring_height = 0.05
	mat.emission_ring_axis = Vector3.UP
	
	# Летят во все стороны вверх
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0  # ← Полусфера, огонь во все стороны
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 2.0
	mat.gravity = Vector3(0, 2.0, 0)  # Тянет вверх сильнее
	
	# Турбулентность
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = 2.0
	mat.turbulence_noise_speed_random = 0.5
	mat.turbulence_noise_scale = 4.0
	mat.turbulence_influence_min = 0.3
	mat.turbulence_influence_max = 0.6
	
	# Цвет: жёлтый → оранжевый → красный → чёрный дым
	var gradient = Gradient.new()
	gradient.set_offset(0, 0.0)
	gradient.set_color(0, Color(1.0, 0.95, 0.4, 1.0))    # Яркий жёлтый
	gradient.add_point(0.15, Color(1.0, 0.7, 0.1, 1.0))   # Оранжевый
	gradient.add_point(0.35, Color(1.0, 0.35, 0.05, 0.9))  # Красно-оранжевый
	gradient.add_point(0.6, Color(0.6, 0.1, 0.02, 0.6))   # Тёмно-красный
	gradient.set_offset(1, 1.0)
	gradient.set_color(1, Color(0.15, 0.08, 0.05, 0.0))   # Чёрный дым → прозрачный
	
	var color_ramp = GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp
	
	# Размер: маленький → большой → исчезает
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.3))
	scale_curve.add_point(Vector2(0.2, 1.0))
	scale_curve.add_point(Vector2(0.6, 0.7))
	scale_curve.add_point(Vector2(1.0, 0.1))
	var scale_texture = CurveTexture.new()
	scale_texture.curve = scale_curve
	mat.scale_min = 0.15
	mat.scale_max = 0.35
	mat.scale_curve = scale_texture
	
	process_material = mat
	amount = 60
	lifetime = 1.0
	explosiveness = 0.0
	randomness = 0.3
	fixed_fps = 30
	one_shot = false
	emitting = true
	
	# Меш — квадратики
	var quad = QuadMesh.new()
	quad.size = Vector2(0.3, 0.3)
	draw_pass_1 = quad
	
	# Материал — светящийся, без теней, billboard
	var draw_mat = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD  # Аддитивный — огонь светится
	draw_mat.emission_enabled = true
	draw_mat.emission = Color(1.0, 0.5, 0.1)
	draw_mat.emission_energy_multiplier = 3.0
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.no_depth_test = true
	quad.material = draw_mat
