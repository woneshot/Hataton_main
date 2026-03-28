shader_type canvas_item;

// --- НАСТРОЙКИ ВОЛНЫ ---
uniform float wave_amplitude = 10.0; // Высота прыжков букв
uniform float wave_frequency = 5.0;  // Скорость волны
uniform float wave_length = 50.0;     // "Длина" волны (насколько буквы будут сдвинуты друг относительно друга)

void vertex() {
	// 1. Берем время (чтобы волна двигалась)
	float time = TIME * wave_frequency;
	
	// 2. Берем позицию вершины по X (чтобы буквы прыгали по-разному)
	float pos_x = VERTEX.x / wave_length;
	
	// 3. Вычисляем смещение по Y с помощью синуса
	float displacement_y = sin(time + pos_x) * wave_amplitude;
	
	// 4. Применяем смещение
	VERTEX.y += displacement_y;
}