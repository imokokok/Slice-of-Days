// A color-only finish: no UV changes, blur, noise, quantization or alpha edits.
// Shared by the coast, original building cutouts, room plates and characters.
vec3 summer_rgb_to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 0.00001)), d / (q.x + 0.00001), q.x);
}
vec3 summer_hsv_to_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}
vec3 summer_palette(vec3 source) {
	vec3 hsv = summer_rgb_to_hsv(clamp(source, 0.0, 1.0));
	float hue = hsv.x;
	float chromatic = smoothstep(0.10, 0.28, hsv.y);
	// Leaf highlights lean yellow-green; darker foliage retains forest greens.
	float leaves = smoothstep(0.17, 0.24, hue) * (1.0 - smoothstep(0.42, 0.49, hue)) * chromatic;
	float leaf_hue = mix(0.285, 0.23, smoothstep(0.25, 0.88, hsv.z));
	hsv.x = mix(hsv.x, leaf_hue, leaves * 0.70);
	hsv.y = mix(hsv.y, min(hsv.y * 0.90 + 0.035, 0.78), leaves * 0.75);
	// Keep distinct clear water blues instead of applying green to everything.
	float water = smoothstep(0.47, 0.53, hue) * (1.0 - smoothstep(0.65, 0.71, hue)) * chromatic;
	hsv.x = mix(hsv.x, 0.575, water * 0.46);
	hsv.y = mix(hsv.y, min(hsv.y * 1.07, 0.77), water * 0.40);
	vec3 color = summer_hsv_to_rgb(hsv);
	// Tame violet accents toward warm brick without recoloring blue shadows.
	float violet = smoothstep(0.68, 0.77, hue) * (1.0 - smoothstep(0.94, 0.99, hue)) * chromatic;
	color.b = mix(color.b, min(color.b, color.g * 1.04 + 0.01), violet * 0.84);
	float lightness = dot(color, vec3(0.2126, 0.7152, 0.0722));
	color *= mix(vec3(1.02, 1.01, 0.985), vec3(1.0, 0.972, 0.925), smoothstep(0.60, 0.98, lightness));
	color += vec3(0.05, 0.073, 0.09) * 0.22 * (1.0 - smoothstep(0.01, 0.24, lightness));
	float middle = smoothstep(0.12, 0.5, lightness) * (1.0 - smoothstep(0.75, 1.0, lightness));
	color += (vec3(1.0) - color) * 0.028 * middle;
	return clamp(color, 0.0, 1.0);
}
vec3 summer_moonlight(vec3 pigment, vec3 lit, float night) {
	float value = dot(pigment, vec3(0.2126, 0.7152, 0.0722));
	vec3 moon = mix(vec3(0.095, 0.145, 0.24), vec3(0.45, 0.61, 0.81), value);
	moon *= 0.58 + 0.16 * value;
	return mix(lit, moon, night * 0.64);
}
