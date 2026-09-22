shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D emission_image : source_color, filter_linear_mipmap_anisotropic;
uniform bool has_image = true;
uniform bool reconstructed = false;
varying vec3 world_normal;
varying float front_view;
void vertex() {
	world_normal = mat3(MODEL_MATRIX) * NORMAL;
	// Preserve photographic detail during ordinary orbit angles. Only yield to
	// gas at grazing angles, where the reconstructed boundary is edge-on.
	front_view = smoothstep(.08,.32,abs(normalize(CAMERA_POSITION_WORLD).z));
}
void fragment() {
	vec3 col = has_image ? texture(emission_image, UV).rgb : mix(vec3(.36,.12,.16), vec3(.95,.60,.30), clamp(UV.y,0.0,1.0));
	float relief = .72 + .28 * abs(dot(normalize(world_normal), normalize(vec3(-.3,.5,1.0))));
	ALBEDO = col * (reconstructed ? 1.0 : relief);
	if (reconstructed) {
		float edge = min(min(UV.x,1.0-UV.x),min(UV.y,1.0-UV.y));
		ALPHA = smoothstep(0.0,.06,edge) * front_view;
	}
}
