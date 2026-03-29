extends Node3D

func _ready():
  # 1. Создаем узел частиц
  var fireflies = GPUParticles3D.new()
  add_child(fireflies)
  
  # 2. Настройки количества и времени
  fireflies.amount = 20
  fireflies.lifetime = 6.0
  fireflies.preprocess = 6.0
  
  # 3. ГЕОМЕТРИЯ (Важно для 3D)
  # Создаем маленький "квадрат", который всегда смотрит в камеру
  var quad_mesh = QuadMesh.new()
  quad_mesh.size = Vector2(0.01, 0.01) # Размер светлячка
  
  # Создаем материал для меша (чтобы он светился)
  var material = StandardMaterial3D.new()
  material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED # Не зависит от света
  material.billboard_mode = StandardMaterial3D.BILLBOARD_PARTICLES # Всегда лицом к камере
  material.vertex_color_use_as_albedo = true # Позволяет менять цвет через ParticleMaterial
  material.use_particle_trails = false
  
  quad_mesh.material = material
  fireflies.draw_pass_1 = quad_mesh
  
  # 4. ФИЗИКА И ПОВЕДЕНИЕ (ParticleProcessMaterial)
  var mat = ParticleProcessMaterial.new()
  
  # Зона появления (Объемный куб)
  mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
  mat.emission_box_extents = Vector3(5, 5, 5) # Облако 10x10x10 метров
  
  # Движение
  mat.gravity = Vector3(0, 0, 0) # Невесомость
  mat.initial_velocity_min = 0.2
  mat.initial_velocity_max = 0.5
  mat.spread = 180.0
  
  # Турбулентность (плавное парение)
  mat.turbulence_enabled = true
  mat.turbulence_noise_strength = 0.5
  mat.turbulence_noise_scale = 2.0
  
  # 5. ЦВЕТ И МЕРЦАНИЕ
  mat.color = Color(0.5, 1.0, 0.2, 1.0) # Салатовый
  
  # Плавное появление и затухание (Scale Curve)
  var scale_curve = CurveTexture.new()
  var curve = Curve.new()
  curve.add_point(Vector2(0, 0))
  curve.add_point(Vector2(0.5, 1))
  curve.add_point(Vector2(1, 0))
  scale_curve.curve = curve
  mat.scale_curve = scale_curve
  
  fireflies.process_material = mat
  fireflies.emitting = true
