shader_type canvas_item;
varying vec4 tint;
uniform float saturation : hint_range(0.0, 1.0) = 0.72;
uniform float projection_contrast : hint_range(0.0, 1.0) = 0.63;
uniform vec3 ambient_paper = vec3(0.14,0.16,0.205);
uniform float edge_softness : hint_range(0.0, 0.04) = 0.009;
void vertex() { tint = COLOR; }
// 幕布四角对应原图 (945,245), (1316,233), (1316,453), (945,450)。
// 先映射斜边幕布，再按照片比例裁切；原始 JPG 不做修改。
void fragment() {
 float top = mix(12.0/220.0, 0.0, UV.x);
 float bottom = mix(217.0/220.0, 1.0, UV.x);
 vec2 p = vec2(UV.x, (UV.y-top)/(bottom-top));
 vec2 screen_uv = p;
 float edge = min(min(p.x,1.0-p.x),min(p.y,1.0-p.y));
 float mask = smoothstep(0.0,edge_softness,edge);
 vec2 photo_size = vec2(textureSize(TEXTURE,0));
 float aspect = photo_size.x/photo_size.y;
 float screen_aspect = 371.0/214.0;
 if (aspect > screen_aspect) p.x = (p.x-0.5)*screen_aspect/aspect+0.5;
 else p.y = (p.y-0.5)*aspect/screen_aspect+0.5;
 vec4 sampled = texture(TEXTURE,p);
 // 投影幕布受夜色和环境灯影响：抬高纯黑，压住白光，保留照片细节。
 float luminance = dot(sampled.rgb,vec3(0.2126,0.7152,0.0722));
 vec3 projected = mix(vec3(luminance),sampled.rgb,saturation);
 projected = projected * vec3(0.96,0.98,1.0) * projection_contrast + ambient_paper.rgb;
 float vignette = 1.0 - 0.11 * dot((screen_uv-0.5)*1.4,(screen_uv-0.5)*1.4);
 // 极淡、静止的幕布颗粒，避免动画噪点与模糊滤镜。
 float grain = fract(sin(dot(floor(screen_uv*vec2(576.0,336.0)),vec2(12.9898,78.233)))*43758.5453)-0.5;
 projected = projected * vignette + grain * 0.006;
 COLOR = tint * vec4(projected,sampled.a*mask);
}
