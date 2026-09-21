// Общее тело сетки пола: два шейдера отличаются только режимом проверки глубины
// (обычный и «рентген»), поэтому код — здесь, а не в двух копиях.
uniform vec4 line_color : source_color = vec4(0.35, 0.85, 0.95, 1.0);
// Сторона клетки и ширина линии, метры.
uniform float cell_m = 0.5;
uniform float thickness_m = 0.004;
uniform float alpha = 0.35;
// Докуда видна сетка от центра, метры; к краю гаснет.
uniform float radius_m = 6.0;
// Центр затухания в мире (позиция человека). У сетки «вся сцена» радиус большой.
uniform vec3 center = vec3(0.0);
uniform float emission_boost = 0.0;
// Гашение мелкой сетки по расстоянию: клетка тоньше LOD_MIN_PX пикселей не видна вовсе, от
// LOD_FULL_PX — в полную силу. Числа не измерены: это порог различимости линии на экране.
const float LOD_MIN_PX = 3.0;
const float LOD_FULL_PX = 12.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Доля линии в точке: расстояние до ближайшей линии сетки по каждой оси, сглаженное шириной пикселя.
// Второе значение — «плотность»: сколько пикселей приходится на клетку. Мелкая сетка вдали сливается
// в заливку (сессия 14, ячейка 10 см), поэтому по плотности она гасится.
vec2 grid_line(vec2 p, float cell, float half_width) {
	vec2 to_line = abs(fract(p / cell + 0.5) - 0.5) * cell;
	vec2 fw = fwidth(p) + 1e-6;
	vec2 line = 1.0 - smoothstep(vec2(half_width), vec2(half_width) + fw, to_line);
	float px_per_cell = cell / max(fw.x, fw.y);
	return vec2(max(line.x, line.y), px_per_cell);
}

void fragment() {
	vec2 g = grid_line(world_pos.xz, cell_m, thickness_m * 0.5);
	float fade = 1.0 - smoothstep(radius_m * 0.6, radius_m, distance(world_pos.xz, center.xz));
	// Клетка мельче LOD_MIN_PX пикселей — линии уже неразличимы и дают «шум»; гасим до LOD_FULL_PX.
	float lod = smoothstep(LOD_MIN_PX, LOD_FULL_PX, g.y);
	float a = g.x * fade * lod * alpha;
	if (a < 0.002) {
		discard;
	}
	ALBEDO = line_color.rgb;
	EMISSION = line_color.rgb * emission_boost;
	ALPHA = a;
}
