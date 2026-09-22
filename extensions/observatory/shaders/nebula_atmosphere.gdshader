shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled;
uniform vec3 gas_color : source_color = vec3(.25,.19,.32);
varying vec3 world_position;
float hash(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float cloud(vec3 p) {
	vec3 cell=floor(p); vec3 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(mix(hash(cell),hash(cell+vec3(1,0,0)),f.x),mix(hash(cell+vec3(0,1,0)),hash(cell+vec3(1,1,0)),f.x),f.y),mix(mix(hash(cell+vec3(0,0,1)),hash(cell+vec3(1,0,1)),f.x),mix(hash(cell+vec3(0,1,1)),hash(cell+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec3 ray=normalize(world_position-CAMERA_POSITION_WORLD);
	float density=0.0;
	for(int i=0;i<24;i++) {
		vec3 p=(CAMERA_POSITION_WORLD+ray*(float(i)*4.0+16.0))*.035;
		density+=pow(cloud(p)*.75+cloud(p*2.3)*.25,3.0)/24.0;
	}
	ALBEDO=vec3(.026,.043,.070)+gas_color*density*.85;
	ALPHA=1.0;
}
