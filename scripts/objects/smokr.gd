extends Node3D

func _ready():
  # 1. Создаем узел 3D частиц
  var particles = GPUParticles3D.new()
  add_child(particles)
  
  # 2. Настройка меша (Draw Pass) — это то, чего нет в 2D
  # Создаем плоскость, на которую будет накладываться текстура дыма
  var quad_mesh = QuadMesh.new()
  quad_mesh.size = Vector2(0.5, 0.5) # Базовый размер 1x1 метр
  
  # Создаем материал для меша
  var material = StandardMaterial3D.new()
  material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED # Дым не ловит тени (опционально)
  material.vertex_color_use_as_albedo = true # Чтобы цвета из ParticleProcessMaterial работали
  material.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA # Включаем прозрачность
  
  # ВАЖНО: Делаем так, чтобы частицы всегда смотрели в камеру (Billboard)
  material.billboard_mode = StandardMaterial3D.BILLBOARD_PARTICLES
  
  quad_mesh.material = material
  particles.draw_pass_1 = quad_mesh
  
  # 3. Базовые настройки потока
  particles.amount = 30
  particles.lifetime = 3.0
  particles.preprocess = 2.0
  
  # 4. Настраиваем физику через материал процесса
  var mat = ParticleProcessMaterial.new()
  
  mat.direction = Vector3(0, 1, 0) # В 3D ось Y вверх — положительная
  mat.spread = 10.0
  
  # Физика (значения в 3D обычно меньше, т.к. это метры, а не пиксели)
  mat.gravity = Vector3(0, 0.1, 0)      # Легкий подъем вверх
  mat.initial_velocity_min = 1.5        # Скорость 1.5 м/с
  mat.initial_velocity_max = 2.5
  
  # Изменение размера
  mat.scale_min = 0.8
  mat.scale_max = 2.5
  
  # Плавное исчезновение (Alpha Curve)
  var alpha_curve = CurveTexture.new()
  var curve = Curve.new()
  curve.add_point(Vector2(0, 1)) # Полностью виден в начале
  curve.add_point(Vector2(1, 0)) # Исчезает к концу жизни
  alpha_curve.curve = curve
  mat.alpha_curve = alpha_curve
  
  # Применяем материал
  particles.process_material = mat
  particles.emitting = true
