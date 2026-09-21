shader_type spatial;
// Виньетка комфорта: затемнение краёв поля зрения при движении (руководство Meta). Квад висит перед
// камерой и рисуется поверх всего, но только по краям: середина прозрачна, иначе он закрывал бы мир.
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled;

uniform float strength = 0.0;
// Радиус прозрачной середины и мягкость края, доли половины квада.
uniform float inner = 0.35;
uniform float outer = 0.95;

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float edge = smoothstep(inner, outer, r);
	ALBEDO = vec3(0.0);
	ALPHA = edge * clamp(strength, 0.0, 1.0);
}
