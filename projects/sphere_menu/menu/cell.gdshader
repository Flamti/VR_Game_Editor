// Ячейка шар-меню (слой 7, docs/design/sphere-menu.md §7).
//
// Меш — плоский CylinderMesh радиуса 1 (6 или 5 сегментов): вершина 0 на +Z,
// верх крышки смотрит по +Y — наружу из шара. На экземпляр (INSTANCE_CUSTOM):
//   r — строка данных подписи (menu/label_text.gd), < 0 — пусто;
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

// Подпись собирает шейдер из атласа глифов по строке данных custom.r (menu/label_text.gd;
// решение после сессии 9, атлас «клетка на пункт» удалён). Геометрия клетки и константы — те же,
// что в label_text.gd; правка здесь — правка там.
uniform sampler2D label_data : filter_nearest, repeat_disable;
uniform sampler2D glyph_atlas : source_color, filter_linear, repeat_disable;
uniform sampler2D icon_atlas : source_color, filter_linear, repeat_disable;
uniform vec2 glyph_atlas_px = vec2(768.0, 504.0);
const vec2 GLYPH_CELL = vec2(48.0, 56.0);
const float GLYPH_COLS = 16.0;
const float GLYPH_SCALE = 0.5;
const vec2 ICON_GRID = vec2(8.0, 6.0);
const int LINE_CHARS = 16;
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

// Линза (шаг 1з): проекция ячейки считается здесь, а не в GDScript (menu/surface_lens.gd,
// «рендер проекцией в шейдере»). Трансформ экземпляра единичный; экземпляр номер i —
// ячейка center + lens_ring_cell(i). Uniform, а не отдельный материал: новый вариант
// конвейера не возникает, прогрев (ADR-0003 п. 9) остаётся прежним.
// Шаги повторены в GDScript — surface_lens.shader_twin; правка здесь — правка там.
uniform bool lens_mode = false;
uniform vec2 lens_shift;
uniform float lens_twist;
uniform float lens_alpha = 0.22;
uniform float lens_max_theta = 2.67;
uniform vec3 lens_right = vec3(1.0, 0.0, 0.0);
uniform vec3 lens_up = vec3(0.0, 1.0, 0.0);
uniform vec3 lens_front = vec3(0.0, 0.0, 1.0);
uniform float lens_radius = 0.1;
uniform float lens_cell_radius = 0.01;
uniform float lens_gap = 0.9;
const ivec2 RING_CORNERS[6] = { ivec2(-1, 1), ivec2(0, 1), ivec2(1, 0), ivec2(1, -1), ivec2(0, -1), ivec2(-1, 0) };
const ivec2 RING_DIRS[6] = { ivec2(1, 0), ivec2(1, -1), ivec2(0, -1), ivec2(-1, 0), ivec2(-1, 1), ivec2(0, 1) };

varying flat vec4 custom;
varying flat float text_angle;
varying vec2 local_xz;
varying float cap;

// Ячейка номер i в порядке колец Layout.ring (surface_lens.ring_cell).
ivec2 lens_ring_cell(int i) {
	if (i == 0) {
		return ivec2(0);
	}
	int k = int(floor((3.0 + sqrt(float(12 * i - 3))) / 6.0));
	while (3 * k * (k + 1) + 1 <= i) {
		k++;
	}
	while (3 * k * (k - 1) + 1 > i) {
		k--;
	}
	int j = i - (3 * k * (k - 1) + 1);
	int side = j / k;
	int st = j - side * k;
	return RING_CORNERS[side] * k + RING_DIRS[side] * st;
}

// Направление точки плоскости rel (от центра переда) и её угол от переда.
vec3 lens_dir(vec2 rel, out float theta) {
	vec2 v = vec2(rel.x * cos(lens_twist) - rel.y * sin(lens_twist), rel.x * sin(lens_twist) + rel.y * cos(lens_twist));
	float ln = length(v);
	theta = ln * lens_alpha;
	if (theta < 1e-6) {
		return lens_front;
	}
	vec3 t = (lens_right * v.x + lens_up * v.y) / ln;
	return normalize(lens_front * cos(theta) + t * sin(theta));
}

// Подпись из текстуры данных: uv клетки 0…1 → пиксель клетки 128 → иконка или буква.
vec4 shader_label(int row, vec2 uv) {
	vec2 px = uv * 128.0;
	vec4 head = texelFetch(label_data, ivec2(0, row), 0);
	if (px.x >= 38.0 && px.x < 90.0 && px.y >= 10.0 && px.y < 62.0) {
		if (head.r < 0.0) {
			return vec4(0.0);
		}
		vec2 cell = vec2(mod(head.r, ICON_GRID.x), floor(head.r / ICON_GRID.x));
		return texture(icon_atlas, (cell + (px - vec2(38.0, 10.0)) / 52.0) / ICON_GRID);
	}
	int line = int(floor((px.y - 64.0) / 22.0));
	if (px.y < 64.0 || line > 1 || float(line) >= head.a) {
		return vec4(0.0);
	}
	float w = line == 0 ? head.g : head.b;
	float x = px.x - (128.0 - w) * 0.5;
	for (int j = 0; j < LINE_CHARS; j++) {
		vec4 e = texelFetch(label_data, ivec2(1 + line * LINE_CHARS + j, row), 0);
		if (e.r < 0.0 || x < e.g) {
			break;
		}
		if (x < e.g + e.b) {
			vec2 g = vec2(mod(e.r, GLYPH_COLS), floor(e.r / GLYPH_COLS));
			vec2 gp = vec2(x - e.g, px.y - 64.0 - float(line) * 22.0) / GLYPH_SCALE;
			return texture(glyph_atlas, (g * GLYPH_CELL + gp) / glyph_atlas_px);
		}
	}
	return vec4(0.0);
}

void vertex() {
	custom = INSTANCE_CUSTOM;
	local_xz = VERTEX.xz;
	// Подпись и подсветка — только на верхней крышке, бока и низ темнее.
	cap = step(0.0, VERTEX.y) * step(0.5, NORMAL.y);
	if (lens_mode) {
		ivec2 c = lens_ring_cell(INSTANCE_ID);
		vec2 rel = vec2(sqrt(3.0) * (float(c.x) + float(c.y) * 0.5), 1.5 * float(c.y)) + lens_shift;
		float theta;
		vec3 n = lens_dir(rel, theta);
		float squeeze = theta < 1e-4 ? 1.0 : clamp(sin(theta) / theta, 0.0, 1.0);
		float s = lens_cell_radius * squeeze * lens_gap;
		if (theta > lens_max_theta || s <= 0.0005) {
			VERTEX = vec3(0.0);    // за границей видимости — вырожденный треугольник
			text_angle = 0.0;
		} else {
			float theta_v;
			vec3 vtx = lens_dir(rel + vec2(0.0, 0.3), theta_v);
			vec3 z = normalize(vtx - n * dot(vtx, n));
			vec3 x = cross(n, z);
			// «Верх» мира в осях узла; экземпляр единичный, MODEL_MATRIX — узел.
			vec3 up_l = inverse(mat3(MODEL_MATRIX)) * vec3(0.0, 1.0, 0.0);
			text_angle = atan(dot(up_l, x), dot(up_l, z));
			VERTEX = (x * VERTEX.x + n * VERTEX.y + z * VERTEX.z) * s + n * lens_radius;
		}
	} else {
		vec3 up_obj = inverse(mat3(MODEL_MATRIX)) * vec3(0.0, 1.0, 0.0);
		text_angle = atan(up_obj.x, up_obj.z);
	}
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
			vec4 t = shader_label(int(custom.r + 0.5), uv);
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
