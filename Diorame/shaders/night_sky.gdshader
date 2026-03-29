shader_type sky;

// Текстура звездного неба
uniform sampler2D stars_texture : source_color, filter_linear_mipmap, repeat_enable;

// Скорость вращения неба (чем меньше, тем медленнее)
uniform float rotation_speed = 0.005;

// Фоновый цвет неба (ниже горизонта и между звездами)
uniform vec4 sky_color : source_color = vec4(0.02, 0.02, 0.05, 1.0);

// Интенсивность звезд (яркость)
uniform float stars_intensity = 1.5;

void sky() {
    // Вычисляем координаты для купола (маппинг полусферы)
    vec2 uv = EYEDIR.xz / (EYEDIR.y + 1.0);
    
    // Добавляем плавное вращение от времени
    float time = TIME * rotation_speed;
    float cos_t = cos(time);
    float sin_t = sin(time);
    mat2 rot_matrix = mat2(vec2(cos_t, -sin_t), vec2(sin_t, cos_t));
    
    uv = rot_matrix * uv;
    
    // Берем цвет из текстуры звезд
    vec4 star_color = texture(stars_texture, uv * 2.0); // Умножение на 2.0 меняет масштаб звезд
    
    // Смешиваем темный фон и яркие звезды
    // EYEDIR.y отвечает за горизонт (чем ниже, тем чернее)
    float horizon_mask = smoothstep(0.0, 0.2, EYEDIR.y);
    
    vec3 final_color = sky_color.rgb + (star_color.rgb * stars_intensity * horizon_mask);
    
    COLOR = final_color;
}