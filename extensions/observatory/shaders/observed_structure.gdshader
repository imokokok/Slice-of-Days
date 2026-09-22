shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform vec4 layer_color : source_color = vec4(.7,.8,.9,1.0);
uniform sampler2D observed_image : source_color, repeat_disable;
uniform bool use_observed_image = false;
uniform float image_mix = 0.72;
void fragment() {
    // Neutral directional illumination only: no invented filaments, noise,
    // photographic colour projection, displacement or decorative star field.
    float shape = .42 + .58 * abs(dot(normalize(NORMAL), normalize(vec3(-.4,.55,1.0))));
    vec3 measured = texture(observed_image, UV).rgb;
    vec3 base = use_observed_image ? mix(layer_color.rgb, measured, image_mix) : layer_color.rgb;
    ALBEDO = base * shape;
}
