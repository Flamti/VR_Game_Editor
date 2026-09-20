shader_type spatial;
// Сетка пола в режиме «рентген»: та же сетка, но без проверки глубины — видна сквозь платформы и
// объекты. Отдельный файл, потому что render_mode шейдера в рантайме не меняется.
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled;

#include "res://world/floor_grid_body.gdshaderinc"
