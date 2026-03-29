shader_type canvas_item;

uniform float vignette_intensity : hint_range(0.0, 10.0) = 1.5;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.8;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// Подхватываем то, что рендерит камера под этим CanvasLayer
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
    // Берем оригинальный цвет экрана
    vec4 color = texture(screen_texture, SCREEN_UV);
    
    // Считаем дистанцию от центра экрана для Виньетки
    vec2 uv = UV - vec2(0.5);
    float dist = length(uv);
    
    // Делаем края мягкими
    float vignette = smoothstep(0.5, 0.5 - (vignette_intensity / 10.0), dist);
    
    // Смешиваем оригинальный цвет с цветом виньетки (затемняем края)
    color.rgb = mix(vignette_color.rgb, color.rgb, vignette + (1.0 - vignette_opacity));
    
    // Выводим на экран
    COLOR = color;
}