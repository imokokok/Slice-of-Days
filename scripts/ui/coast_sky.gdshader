shader_type canvas_item;
render_mode unshaded;
uniform sampler2D dusk_sky : source_color, filter_linear;
uniform sampler2D night_sky : source_color, filter_linear;
uniform sampler2D rain_sky : source_color, filter_linear;
uniform vec3 blend = vec3(1.0,0.0,0.0);
uniform float rain = 0.0;
uniform vec3 light = vec3(1.0);
void fragment() {
	vec4 src=texture(TEXTURE,UV);
	// Classify the sky in the original high resolution panorama. Never blend
	// generated buildings/trees/lighthouses over the original geometry.
	float pale=smoothstep(.42,.58,min(src.g,src.b))*smoothstep(-.11,-.02,src.b-src.g);
	float cloud=1.0-smoothstep(.025,.16,max(src.r,max(src.g,src.b))-min(src.r,min(src.g,src.b)));
	float tower=step(.834,UV.x)*step(UV.x,.858)*step(.10,UV.y)*step(UV.y,.76);
	float horizon=.51+.23*UV.x;
	float sky=pale*(1.0-smoothstep(horizon-.008,horizon+.006,UV.y));
	// Cream lighthouse bands cannot be mistaken for white cloud.
	sky*=1.0-tower*(1.0-smoothstep(.01,.09,src.b-src.r));
	// Sample sky-only strips: no landmark coordinates are present in these.
	vec3 dusk=texture(dusk_sky,vec2(.40+UV.x*.08,.035+UV.y*.58)).rgb;
	vec3 night=texture(night_sky,vec2(.20,.34)).rgb*mix(.85,1.35,UV.y);
	vec3 overcast=texture(rain_sky,vec2(.04+UV.x*.73,.025+UV.y*.23)).rgb;
	// Preserve the original painted cloud shapes, including their pale blue cuts.
	dusk=mix(dusk,vec3(.85,.69,.64),cloud*.75);
	night=mix(night,vec3(.13,.18,.28),cloud*.6);
	vec3 sky_color=src.rgb*blend.x+dusk*blend.y+night*blend.z;
	sky_color=mix(sky_color,overcast*mix(vec3(1.0),vec3(.26,.35,.48),blend.z),rain);
	vec3 solid=src.rgb*light;
	solid*=mix(vec3(1.0),vec3(.47,.58,.70),blend.z);
	solid=mix(solid,solid*vec3(.82,.89,.92),rain*.45);
	// Only the existing lantern glass receives light; the tower stays crisp.
	float lamp=step(.841,UV.x)*step(UV.x,.850)*step(.164,UV.y)*step(UV.y,.226);
	solid=mix(solid,vec3(1.0,.86,.48),lamp*(blend.y*.45+blend.z)*.70);
	vec3 color=mix(solid,sky_color,sky);
	// Tiny stationary stars use world coordinates; they never move with the HUD
	// or inherit the highly stretched pixels of a low-resolution sky plate.
	vec2 cells=UV*vec2(100.0,30.0);
	vec2 cell=floor(cells);
	float seed=fract(sin(dot(cell,vec2(127.1,311.7)))*43758.5453);
	vec2 offset=vec2(fract(seed*31.7),fract(seed*57.3))*.6+.2;
	float star=1.0-smoothstep(.65,1.5,length((fract(cells)-offset)*vec2(80.0,30.0)));
	color+=vec3(.72,.76,.80)*star*step(.96,seed)*blend.z*sky*(1.0-cloud)*(1.0-rain);
	COLOR=vec4(color,src.a);
}
