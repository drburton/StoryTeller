// Draws a backdrop and blends to the next one. Used by BackdropView.
// Modes: 0 cut, 1 fade, 2 dissolve, 3 wipe, 4 slide.
shader_type canvas_item;

uniform sampler2D from_tex : filter_linear, repeat_disable;
uniform sampler2D to_tex : filter_linear, repeat_disable;
uniform bool from_has_tex = false;
uniform bool to_has_tex = false;
uniform vec4 from_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 to_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec2 from_size = vec2(1.0);
uniform vec2 to_size = vec2(1.0);
uniform vec2 screen_size = vec2(1152.0, 648.0);
uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform int mode = 1;
// Direction the edge or image moves, in screen space (y points down).
uniform vec2 direction = vec2(-1.0, 0.0);
uniform sampler2D mask_tex : filter_linear;
uniform bool has_mask = false;
uniform float smoothness : hint_range(0.0, 0.5) = 0.08;

// Scales UVs so the texture covers the screen without stretching.
vec2 cover_uv(vec2 uv, vec2 tex_size) {
	float screen_ratio = screen_size.x / screen_size.y;
	float tex_ratio = tex_size.x / tex_size.y;
	vec2 scale = vec2(1.0);
	if (tex_ratio > screen_ratio) {
		scale.x = screen_ratio / tex_ratio;
	} else {
		scale.y = tex_ratio / screen_ratio;
	}
	return (uv - 0.5) * scale + 0.5;
}

vec4 sample_from(vec2 uv) {
	return from_has_tex ? texture(from_tex, cover_uv(uv, from_size)) : from_color;
}

vec4 sample_to(vec2 uv) {
	return to_has_tex ? texture(to_tex, cover_uv(uv, to_size)) : to_color;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// 0 at the edge where a wipe starts, 1 at the far edge.
float along(vec2 uv) {
	if (direction.x > 0.5) return uv.x;
	if (direction.x < -0.5) return 1.0 - uv.x;
	if (direction.y > 0.5) return uv.y;
	return 1.0 - uv.y;
}

void fragment() {
	vec2 uv = UV;
	float t = clamp(progress, 0.0, 1.0);
	if (mode == 0) {
		COLOR = t < 1.0 ? sample_from(uv) : sample_to(uv);
	} else if (mode == 4) {
		vec2 old_uv = uv - direction * t;
		if (old_uv.x >= 0.0 && old_uv.x <= 1.0 && old_uv.y >= 0.0 && old_uv.y <= 1.0) {
			COLOR = sample_from(old_uv);
		} else {
			COLOR = sample_to(uv + direction * (1.0 - t));
		}
	} else {
		float amount = t;
		if (mode == 2) {
			float n = has_mask ? texture(mask_tex, uv).r : value_noise(uv * screen_size / 32.0);
			amount = smoothstep(n - smoothness, n + smoothness, t * (1.0 + 2.0 * smoothness) - smoothness);
		} else if (mode == 3) {
			float edge = t * (1.0 + smoothness);
			amount = 1.0 - smoothstep(edge - smoothness, edge, along(uv));
		}
		COLOR = mix(sample_from(uv), sample_to(uv), amount);
	}
}
