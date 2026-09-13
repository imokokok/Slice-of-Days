shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 star_color : source_color = vec4(0.78,0.86,1.0,1.0);
uniform float brightness = 1.0;
uniform float phase = 0.0;
uniform bool background_batch = false;
varying vec4 variation;
void vertex() {
 variation = background_batch ? INSTANCE_CUSTOM : vec4(phase,0.6,0.7,0.0);
 MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
  INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
  INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
  INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
}
void fragment() {
 vec2 p = (UV-vec2(0.5))*2.0;
 float d2 = dot(p,p);
 float pulse = 0.88 + 0.12*sin(TIME*(0.55+variation.y*0.7)+variation.x*6.28318);
 float core = exp(-d2*65.0);
 float halo = 0.09*exp(-d2*7.0);
 float rays = (exp(-abs(p.x)*125.0-abs(p.y)*8.0)+exp(-abs(p.y)*125.0-abs(p.x)*8.0))*0.15*variation.z;
 vec3 color = background_batch ? mix(vec3(0.60,0.74,1.0),vec3(1.0,0.89,0.70),variation.y) : star_color.rgb;
 ALBEDO = color * brightness * pulse * (background_batch ? 0.65+variation.z*1.4 : 1.0);
 ALPHA = (core+halo+rays)*smoothstep(1.0,0.7,length(p));
}
