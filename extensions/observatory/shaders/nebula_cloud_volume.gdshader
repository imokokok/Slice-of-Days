shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled;
uniform sampler2D emission_image : source_color, filter_linear_mipmap;
varying vec3 world_position;
float hash(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float cloud(vec3 p) {
	vec3 cell=floor(p); vec3 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(mix(hash(cell),hash(cell+vec3(1,0,0)),f.x),mix(hash(cell+vec3(0,1,0)),hash(cell+vec3(1,1,0)),f.x),f.y),mix(mix(hash(cell+vec3(0,0,1)),hash(cell+vec3(1,0,1)),f.x),mix(hash(cell+vec3(0,1,1)),hash(cell+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec3 ray=normalize(world_position-CAMERA_POSITION_WORLD);
	vec3 result=vec3(0.0); float alpha=0.0;
	for(int i=0;i<96;i++) {
		vec3 p=CAMERA_POSITION_WORLD+ray*(float(i)*1.7+.5);
		vec2 uv=vec2(p.x/72.0+.5,.5-p.y/72.0);
		float edge=min(min(uv.x,1.0-uv.x),min(uv.y,1.0-uv.y));
		if(edge<=0.0 || abs(p.z)>24.0) continue;
		vec3 color=textureLod(emission_image,uv,1.5).rgb;
		float center=(cloud(vec3(p.xy*.045,2.0))-.5)*16.0;
		float mass=exp(-pow((p.z-center)/12.0,2.0));
		mass*=smoothstep(0.0,.08,edge)*(.40+.6*cloud(p*.14));
		float density=mass*.13;
		result+=(1.0-alpha)*color*density*1.45;
		alpha+=(1.0-alpha)*density;
		if(alpha>.98) break;
	}
	float face=smoothstep(.08,.32,abs(normalize(CAMERA_POSITION_WORLD).z));
	ALBEDO=result/max(alpha,.001);
	ALPHA=alpha*mix(1.0,.10,face);
}
