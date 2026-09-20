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

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Доля линии в точке: расстояние до ближайшей линии сетки по каждой оси, сглаженное шириной пикселя.
float grid_line(vec2 p, float cell, float half_width) {
	vec2 to_line = abs(fract(p / cell + 0.5) - 0.5) * cell;
	vec2 fw = fwidth(p) + 1e-6;
	vec2 line = 1.0 - smoothstep(vec2(half_width), vec2(half_width) + fw, to_line);
	return max(line.x, line.y);
}

void fragment() {
	float line = grid_line(world_pos.xz, cell_m, thickness_m * 0.5);
	float fade = 1.0 - smoothstep(radius_m * 0.6, radius_m, distance(world_pos.xz, center.xz));
	float a = line * fade * alpha;
	if (a < 0.002) {
		discard;
	}
	ALBEDO = line_color.rgb;
	EMISSION = line_color.rgb * emission_boost;
	ALPHA = a;
}
