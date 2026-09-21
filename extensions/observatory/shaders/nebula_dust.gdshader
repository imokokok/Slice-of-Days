shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform float opacity = 0.65;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float radius = dot(p,p);
	ALBEDO = COLOR.rgb;
	ALPHA = exp(-radius * 4.0) * smoothstep(1.0, 0.6, radius) * COLOR.a * opacity;
}
