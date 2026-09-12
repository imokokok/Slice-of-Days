shader_type canvas_item;
uniform vec2 surface_size = vec2(1600.0, 900.0);
varying vec4 tint;

void vertex() { tint = COLOR; }

void fragment() {
	vec2 p = UV * surface_size;
	// Fine woven warp/weft, not a new picture painted over the user's reference.
	float warp = sin(p.x * 2.65);
	float weft = sin(p.y * 2.65);
	float grain = fract(sin(dot(floor(p), vec2(127.1, 311.7))) * 43758.5453) - 0.5;
	float weave = (warp * 0.025 + weft * 0.02 + warp * weft * 0.012 + grain * 0.025);
	float fold = sin(UV.x * 15.0 + UV.y * 3.0) * 0.023 + sin(UV.y * 19.0 - UV.x * 2.0) * 0.016;
	float vignette = 1.0 - smoothstep(0.2, 0.8, distance(UV, vec2(0.5))) * 0.26;
	vec3 original = texture(TEXTURE, UV).rgb;
	vec3 cloth = original * (0.93 + weave + fold) * vignette;
	cloth += vec3(0.026, 0.035, 0.038) * (0.5 + weave * 4.0);
	COLOR = vec4(cloth, 1.0) * tint;
}
