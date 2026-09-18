shader_type canvas_item;
render_mode unshaded;
uniform sampler2D sea_mask : filter_linear, repeat_disable;
uniform float elapsed = 0.0;
uniform float motion_strength = 1.0;

float ellipse(vec2 uv, vec2 center, vec2 radii) {
	return 1.0-smoothstep(0.55,1.0,length((uv-center)/radii));
}
vec2 swivel(vec2 uv, vec2 pivot, float angle) {
	vec2 p=uv-pivot;
	return pivot+vec2(cos(angle)*p.x-sin(angle)*p.y,sin(angle)*p.x+cos(angle)*p.y);
}
void fragment() {
	vec2 uv=UV;
	float t=elapsed;
	float opening=exp(-pow((t-1.65)/0.88,2.0));
	float breeze=(0.35+1.15*opening)*sin(t*1.65);
	// Continuous local warps keep the title, furniture and coastline still.
	float canopy=(1.0-smoothstep(0.24,0.40,uv.x))*(1.0-smoothstep(0.33,0.69,uv.y));
	float branch=canopy*smoothstep(0.0,0.14,uv.y+uv.x*.25);
	vec2 moving=uv;
	moving.x += branch*motion_strength*(0.0028*breeze+0.0006*sin(t*2.6+uv.y*22.0));
	moving.y += branch*motion_strength*0.0011*sin(t*1.5+uv.x*15.0)*(0.4+opening);
	float lemon_a=ellipse(uv,vec2(.182,.204),vec2(.073,.108));
	float lemon_b=ellipse(uv,vec2(.053,.344),vec2(.071,.115));
	vec2 tilt_a=swivel(moving,vec2(.188,.123),motion_strength*.038*breeze);
	vec2 tilt_b=swivel(moving,vec2(.064,.253),motion_strength*.045*sin(t*1.55-.4)*(.35+opening));
	moving=mix(moving,tilt_a,lemon_a);
	moving=mix(moving,tilt_b,lemon_b);
	float right_crowns=max(ellipse(uv,vec2(.967,.555),vec2(.07,.065)),max(ellipse(uv,vec2(.947,.694),vec2(.10,.075)),ellipse(uv,vec2(.851,.800),vec2(.083,.048))));
	vec2 crown_sway=swivel(moving,vec2(.953,.916),motion_strength*.014*breeze);
	moving=mix(moving,crown_sway,right_crowns);
	float water=texture(sea_mask,uv).r;
	vec3 original=texture(TEXTURE,uv).rgb;
	// Protect white sails, dark trees and pale rock at the water boundary.
	float blue=smoothstep(.025,.11,original.b-original.r)*smoothstep(.015,.08,original.g-original.r);
	water *= blue;
	float depth=smoothstep(.57,.89,uv.y);
	moving.x += water*motion_strength*(.00065+.00075*depth)*sin(uv.y*175.0-t*1.2+sin(uv.x*14.0));
	moving.y += water*motion_strength*.00085*sin(uv.x*53.0+uv.y*91.0-t*.95);
	vec4 color=texture(TEXTURE,clamp(moving,vec2(.001),vec2(.999)));
	float ripple=sin(uv.y*330.0+sin(uv.x*24.0)-t*1.9)*sin(uv.x*66.0+t*.25);
	color.rgb *= 1.0+water*motion_strength*.027*ripple;
	COLOR=color;
}
