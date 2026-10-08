shader_type canvas_item;
// Recolors everything drawn below this layer. Used by StoryEffects.filter().

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
// 0 none, 1 grayscale, 2 sepia, 3 night, 4 warm, 5 cold.
uniform int mode = 0;
uniform float strength : hint_range(0.0, 1.0) = 0.0;

vec3 recolor(vec3 c) {
	float gray = dot(c, vec3(0.299, 0.587, 0.114));
	if (mode == 1) {
		return vec3(gray);
	} else if (mode == 2) {
		return vec3(gray * 1.07, gray * 0.87, gray * 0.66) + vec3(0.06, 0.03, 0.0);
	} else if (mode == 3) {
		return mix(vec3(gray), c, 0.35) * vec3(0.55, 0.65, 1.0) * 0.7;
	} else if (mode == 4) {
		return c * vec3(1.1, 0.98, 0.82);
	} else if (mode == 5) {
		return c * vec3(0.85, 0.97, 1.12);
	}
	return c;
}

void fragment() {
	vec3 c = texture(screen_texture, SCREEN_UV).rgb;
	COLOR = vec4(mix(c, recolor(c), strength), 1.0);
}
