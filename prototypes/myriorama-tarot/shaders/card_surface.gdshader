shader_type canvas_item;
uniform vec2 card_size = vec2(156.0, 267.0);
uniform float hover = 0.0;
uniform float joined = 0.0;
varying vec4 tint;

void vertex() { tint = COLOR; }

void fragment() {
	vec2 p = UV * card_size;
	float radius = mix(5.0, 0.8, joined);
	vec2 q = abs(p - card_size * 0.5) - (card_size * 0.5 - vec2(radius));
	float sdf = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	float mask = 1.0 - smoothstep(-0.28, 0.28, sdf);
	vec4 art = texture(TEXTURE, UV);
	float edge = min(min(p.x, card_size.x-p.x), min(p.y, card_size.y-p.y));
	float rim = 1.0 - smoothstep(0.08, mix(0.65, 0.30, joined), edge);
	vec3 ivory = vec3(0.86, 0.79, 0.62);
	vec3 base = mix(art.rgb, ivory, rim * 0.66);
	float grain = fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453) - 0.5;
	base += grain * 0.012;
	float sweep = exp(-pow((UV.x * 0.75 + UV.y * 0.5 - 0.28 - hover * 0.32) * 4.0, 2.0));
	base += vec3(0.96, 0.95, 0.87) * sweep * (0.018 + hover * 0.025);
	float top_light = (1.0 - smoothstep(0.0, 2.0, p.y)) * 0.06;
	float bottom_shade = (1.0 - smoothstep(0.0, 2.5, card_size.y - p.y)) * 0.10;
	base += top_light - bottom_shade;
	COLOR = vec4(base, art.a * mask) * tint;
}
