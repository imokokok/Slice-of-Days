shader_type canvas_item;
// Illustrative cooking dose, not a calibrated chemical or temperature model.
uniform float cooked : hint_range(0.0, 1.0) = 0.0;
uniform float browned : hint_range(0.0, 1.0) = 0.0;
uniform float charred : hint_range(0.0, 1.0) = 0.0;
uniform int food_profile = 0;

float grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float contact_patch(vec2 p) {
	vec2 tile = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(grain(tile), grain(tile + vec2(1.0, 0.0)), f.x), mix(grain(tile + vec2(0.0, 1.0)), grain(tile + vec2(1.0)), f.x), f.y);
}

void fragment() {
	vec4 source = COLOR;
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 done = source.rgb;
	if (food_profile == 1) {
		// Protein loses its raw red/pink pigment while its painted texture stays.
		done = vec3(0.88, 0.72, 0.53) * (0.40 + luminance * 0.74);
	} else if (food_profile == 2) {
		done = source.rgb * vec3(0.73, 0.85, 0.61);
	} else {
		done = source.rgb * vec3(1.02, 0.89, 0.70);
	}
	vec3 pigment = mix(source.rgb, done, cooked * 0.82);
	// Stable uneven contact browning. UV follows each original ingredient,
	// including the same surface clipped into independently simulated slices.
	float toast = smoothstep(0.2, 0.8, contact_patch(UV * 12.0));
	pigment = mix(pigment, pigment * vec3(0.57, 0.34, 0.16), browned * (0.3 + 0.5 * toast));
	pigment = mix(pigment, vec3(0.12, 0.09, 0.065) * (0.65 + luminance * 0.4), charred * (0.6 + 0.4 * toast));
	COLOR = vec4(pigment, source.a);
}
