// Ячейка шар-меню (слой 7, docs/design/sphere-menu.md §7).
//
// Меш — плоский CylinderMesh радиуса 1 (6 или 5 сегментов): вершина 0 на +Z,
// верх крышки смотрит по +Y — наружу из шара. На экземпляр (INSTANCE_CUSTOM):
//   r — индекс клетки в атласе (иконка + подпись), < 0 — пусто;
//   g — подсветка: 0 нет, 0.5 под лучом, 1 активная; +2 — отмечена (множественный выбор);
//   b — код цвета / 20: Item.Kind 0–7, 8 — назад/отмена, 9 — пусто, 10 — опасное действие;
//   a — прогресс удержания курка 0…1 (кольцо по краю).
//
// Подпись стоит вертикально по мировому «верху»: он переводится в систему
// ячейки через MODEL_MATRIX экземпляра. Раньше угол считал GDScript на каждую
// ячейку каждый кадр — это часть тех 6.6–7.8 мс скриптов из самопроверки.
//
// Ориентация текстуры. Зритель смотрит на ячейку снаружи, вдоль −n. Для камеры
// право = вперёд × верх, значит право экрана = (−n) × up = up × n. При up = +Z и
// n = +Y это −X. Первая версия отображала «вправо» текстуры на +X — подписи на
// шлеме вышли отражёнными (самопроверка 2026-09-15, снимок экрана).
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform sampler2D atlas : source_color, filter_linear, repeat_disable;
uniform vec2 atlas_grid = vec2(8.0, 8.0);
// Число сторон многоугольника: 6 — шестиугольник, 5 — пятиугольник (свой материал).
uniform float sides = 6.0;
// Цвета: действие, папка, переключатель, опция, файл, ассет, изображение, сцена,
// назад/отмена, пусто, опасное действие. Константа, а не uniform: значения по
// умолчанию у uniform-массивов Godot не поддерживает.
const vec3 KIND_COLORS[11] = {
	vec3(0.18, 0.22, 0.32), vec3(0.20, 0.30, 0.18), vec3(0.30, 0.22, 0.14),
	vec3(0.24, 0.18, 0.30), vec3(0.14, 0.26, 0.30), vec3(0.28, 0.26, 0.14),
	vec3(0.14, 0.22, 0.34), vec3(0.26, 0.18, 0.24),
	vec3(0.34, 0.12, 0.12), vec3(0.07, 0.07, 0.08), vec3(0.45, 0.10, 0.10)
};

varying flat vec4 custom;
varying flat float text_angle;
varying vec2 local_xz;
varying float cap;

void vertex() {
	custom = INSTANCE_CUSTOM;
	local_xz = VERTEX.xz;
	vec3 up_obj = inverse(mat3(MODEL_MATRIX)) * vec3(0.0, 1.0, 0.0);
	text_angle = atan(up_obj.x, up_obj.z);
	// Подпись и подсветка — только на верхней крышке, бока и низ темнее.
	cap = step(0.0, VERTEX.y) * step(0.5, NORMAL.y);
}

void fragment() {
	int kind = clamp(int(round(custom.b * 20.0)), 0, 10);
	vec3 base = KIND_COLORS[kind];
	// Кант по расстоянию до ближайшей стороны многоугольника, а не по радиусу:
	// радиальный кант (первая версия) рисовал ячейки кругами. Вершина 0 — на +Z,
	// нормали сторон — посередине между вершинами.
	float step_a = 6.28318530718 / sides;
	float d = 0.0;
	for (int k = 0; k < int(sides); k++) {
		float ang = step_a * (float(k) + 0.5);
		d = max(d, dot(local_xz, vec2(sin(ang), cos(ang))));
	}
	float inr = cos(step_a * 0.5);
	float edge = smoothstep(inr * 0.82, inr * 0.97, d);
	vec3 col = mix(base, base * 0.35, edge);

	if (custom.r >= 0.0 && cap > 0.5) {
		float a = text_angle;
		vec2 q = vec2(local_xz.x * cos(a) - local_xz.y * sin(a), local_xz.x * sin(a) + local_xz.y * cos(a));
		// q.y — «вверх» подписи, −q.x — «вправо» для зрителя снаружи.
		vec2 uv = vec2(0.5 - q.x * 0.6, 0.5 - q.y * 0.6);
		if (uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0) {
			float idx = custom.r;
			vec2 tile = vec2(mod(idx, atlas_grid.x), floor(idx / atlas_grid.x));
			vec4 t = texture(atlas, (tile + uv) / atlas_grid);
			col = mix(col, vec3(0.95), t.a);
		}
	}

	float marked = step(1.5, custom.g);
	float hl = custom.g - 2.0 * marked;
	// Галочка множественного выбора — зелёный кружок у верхнего края ячейки.
	if (marked > 0.5 && cap > 0.5) {
		float a2 = text_angle;
		vec2 q2 = vec2(local_xz.x * cos(a2) - local_xz.y * sin(a2), local_xz.x * sin(a2) + local_xz.y * cos(a2));
		float dot_r = length(q2 - vec2(-0.42, 0.42));
		col = mix(col, vec3(0.20, 0.80, 0.35), 1.0 - smoothstep(0.14, 0.18, dot_r));
	}
	// Кольцо прогресса удержания: заливка кромки по часовой от верха.
	if (custom.a > 0.001 && cap > 0.5) {
		float ang = atan(local_xz.x, local_xz.y) / 6.28318530718 + 0.5;
		float ring = smoothstep(inr * 0.78, inr * 0.84, d) * step(ang, custom.a);
		col = mix(col, vec3(1.0, 0.85, 0.30), ring);
	}
	vec3 glow = hl > 0.75 ? vec3(0.95, 0.80, 0.25) : vec3(0.40, 0.70, 0.95);
	col = mix(col, glow, (hl > 0.0 ? 0.35 : 0.0) * (1.0 - edge) + (hl > 0.0 ? 0.6 : 0.0) * edge);
	ALBEDO = col * (cap > 0.5 ? 1.0 : 0.45);
}
