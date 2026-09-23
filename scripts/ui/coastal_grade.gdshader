shader_type canvas_item;
render_mode unshaded;

// One non-destructive finish for the supplied art and native world geometry.
// UI is a sibling of WalkStage and never receives this material.
uniform vec2 camera_offset = vec2(0.0);
uniform vec3 daylight = vec3(1.0);
uniform float amount = 1.0;
uniform bool paper_key = false;
uniform vec4 local_lights[16];
uniform int light_count = 0;
uniform float night_strength = 0.0;
varying vec2 world_pixel;
varying vec4 vertex_tint;

float grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pixel = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy + camera_offset;
	vertex_tint = COLOR;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	if (paper_key) {
		source.a *= 1.0 - smoothstep(0.97, 0.995, min(source.r, min(source.g, source.b)));
	}
	vec4 base = source * vertex_tint;
	float lum = dot(base.rgb, vec3(0.2126, 0.7152, 0.0722));
	float chroma = max(base.r, max(base.g, base.b)) - min(base.r, min(base.g, base.b));
	// Bring monochrome cut-paper art into the same mineral-green / ivory range.
	// Preserve its ink, original relief and alpha; no replacement artwork.
	vec3 low = vec3(0.12, 0.22, 0.25);
	vec3 mid = vec3(0.55, 0.65, 0.59);
	vec3 high = vec3(0.99, 0.97, 0.90);
	vec3 mineral = lum < 0.5 ? mix(low, mid, lum * 2.0) : mix(mid, high, (lum - 0.5) * 2.0);
	float neutral = (1.0 - smoothstep(0.025, 0.12, chroma)) * 0.72;
	neutral *= mix(0.5, 1.0, smoothstep(0.04, 0.16, lum));
	vec3 color = mix(base.rgb, mineral, neutral);
	color = mix(vec3(dot(color, vec3(0.2126, 0.7152, 0.0722))), color, 0.90);
	// Sun-warmed highlights, gently lifted marine shadows; no sepia wash.
	color = color * vec3(0.965, 0.977, 0.952) + vec3(0.020, 0.018, 0.012);
	float fiber = (grain(floor(world_pixel)) - 0.5) * 0.022;
	fiber += (grain(floor(world_pixel / 3.0)) - 0.5) * 0.012;
	vec3 pigment = clamp(color + fiber, vec3(0.0), vec3(1.0));
	color = pigment * daylight;
	for (int i=0; i<16; i++) {
		if (i>=light_count) { break; }
		vec4 lamp=local_lights[i];
		vec2 distance_to_lamp=(world_pixel-lamp.xy)/vec2(lamp.z,lamp.z*1.25);
		float falloff=pow(max(0.0,1.0-length(distance_to_lamp)),2.0);
		color += pigment*vec3(1.0,0.74,0.38)*falloff*lamp.w*night_strength;
	}
	COLOR = vec4(mix(base.rgb, color, amount), base.a);
}
