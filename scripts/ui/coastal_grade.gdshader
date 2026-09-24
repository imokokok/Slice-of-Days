shader_type canvas_item;
render_mode unshaded;
#include "res://scripts/ui/summer_palette.gdshaderinc"

// One non-destructive finish for the supplied art and native world geometry.
// UI is a sibling of WalkStage and never receives this material.
uniform vec2 camera_offset = vec2(0.0);
uniform vec3 daylight = vec3(1.0);
uniform float amount = 1.0;
uniform float palette_strength = 1.0;
uniform bool paper_key = false;
uniform vec4 local_lights[16];
uniform int light_count = 0;
uniform float night_strength = 0.0;
varying vec2 world_pixel;
varying vec4 vertex_tint;

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
	vec3 pigment = mix(base.rgb, summer_palette(base.rgb), palette_strength);
	vec3 color = summer_moonlight(pigment, pigment * daylight, night_strength);
	for (int i=0; i<16; i++) {
		if (i>=light_count) { break; }
		vec4 lamp=local_lights[i];
		vec2 distance_to_lamp=(world_pixel-lamp.xy)/vec2(lamp.z,lamp.z*1.25);
		float falloff=pow(max(0.0,1.0-length(distance_to_lamp)),2.0);
		color += pigment*vec3(1.0,0.74,0.38)*falloff*lamp.w*night_strength;
	}
	COLOR = vec4(mix(base.rgb, color, amount), base.a);
}
