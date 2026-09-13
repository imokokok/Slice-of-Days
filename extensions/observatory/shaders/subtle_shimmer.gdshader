shader_type canvas_item;
void fragment() {
 vec4 c = texture(TEXTURE, UV);
 float sea = smoothstep(0.45,0.49,UV.y) * (1.0-smoothstep(0.66,0.73,UV.y));
 c.rgb += sea * 0.005 * sin(UV.y*280.0 + TIME*0.55 + sin(UV.x*20.0));
 COLOR = c;
}
