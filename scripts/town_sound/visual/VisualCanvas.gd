class_name VisualCanvas
extends Control
var audio: AudioStreamWAV
var model: Arrangement
var profile: Dictionary = {}
var time := 0.0
var frozen := false
var pcm := PackedByteArray()
var shapes: Array[Dictionary] = []
var features := [0.0, 0.0, 0.0, 0.0, 0.0]

func configure(wav: AudioStreamWAV, prompt: String, seed_number: int) -> void:
	audio = wav
	pcm = wav.data
	profile = parse_prompt(prompt, seed_number)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_number
	shapes.clear()
	for i in int(float(profile.density) * 45 + 8):
		shapes.append({"x": rng.randf(), "y": rng.randf(), "radius": rng.randf_range(8, 50),
			"phase": rng.randf() * TAU, "type": rng.randf(), "layer": i % 4, "motion": i % 11})
	queue_redraw()

static func parse_prompt(text: String, seed_number: int) -> Dictionary:
	var value := text.to_lower()
	var result := {"palette": "warm", "circle": 0.55, "density": 0.4, "speed": 0.7,
		"motion": "floating", "randomness": 0.2, "seed": seed_number, "visual_version": 1}
	if has_words(value, ["冷", "蓝", "cold", "blue", "海", "wave"]): result.palette = "cool"
	if has_words(value, ["红", "red", "黑", "black"]): result.palette = "red"
	if has_words(value, ["黄", "yellow", "快乐", "happy"]): result.palette = "yellow"
	if has_words(value, ["圆", "circle", "soft", "柔和"]): result.circle = 0.85
	if has_words(value, ["尖", "sharp", "紧张", "tense"]):
		result.circle = 0.12
		result.motion = "jitter"
		result.density = 0.7
	if has_words(value, ["线", "line"]): result.circle = float(result.circle) * 0.65
	if has_words(value, ["密集", "crowded", "混乱", "chaotic"]):
		result.density = 0.85
		result.randomness = 0.8
	if has_words(value, ["平静", "calm", "留白", "empty", "space", "简约", "minimal"]): result.density = 0.18
	if has_words(value, ["快", "fast"]): result.speed = 1.7
	if has_words(value, ["慢", "slow", "calm", "平静"]): result.speed = 0.3
	if has_words(value, ["海浪", "wave"]): result.motion = "wave"
	return result

static func has_words(text: String, words: Array) -> bool:
	for word in words:
		if text.contains(word): return true
	return false

func analyze() -> void:
	features = [0.0, 0.0, 0.0, 0.0, 0.0]
	if audio == null or pcm.is_empty(): return
	var offset := int(time * audio.mix_rate)
	var low := 0.0
	var mid_low := 0.0
	var rms := 0.0
	var peak := 0.0
	var bass := 0.0
	var mid := 0.0
	var high := 0.0
	var count := 0
	var alpha_low := 1.0 - exp(-TAU * 250.0 / audio.mix_rate)
	var alpha_mid := 1.0 - exp(-TAU * 2000.0 / audio.mix_rate)
	for i in range(maxi(0, offset - 1024), mini(pcm.size() / 2, offset)):
		var value := float(pcm.decode_s16(i * 2)) / 32768.0
		low += alpha_low * (value - low)
		mid_low += alpha_mid * (value - mid_low)
		rms += value * value
		peak = maxf(peak, absf(value))
		bass += low * low
		mid += (mid_low - low) * (mid_low - low)
		high += (value - mid_low) * (value - mid_low)
		count += 1
	if count > 0:
		features = [sqrt(rms / count), peak, sqrt(bass / count), sqrt(mid / count), sqrt(high / count)]

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("ede6d4"))
	if profile.is_empty(): return
	analyze()
	var palette := [Color("bf6748"), Color("d5b44c"), Color("527d78"), Color("383f35")]
	if profile.palette == "cool": palette = [Color("557da0"), Color("6b9b91"), Color("aec4b2"), Color("304d66")]
	if profile.palette == "red": palette = [Color("aa3d30"), Color("292825"), Color("bb6550"), Color("5a493d")]
	if profile.palette == "yellow": palette = [Color("d4b03d"), Color("ca8654"), Color("e2c973"), Color("627d68")]
	var t := time * float(profile.speed)
	for i in shapes.size():
		var shape := shapes[i]
		var layer := int(shape.layer)
		var strength := 1.0
		if model != null:
			if model.muted[layer]: continue
			strength = 0.0
			for clip in model.clips:
				if int(clip.track) == layer and time >= float(clip.start) and time < float(clip.start) + float(clip.length):
					strength = maxf(strength, float(clip.volume) * float(model.gains[layer]))
			if strength <= 0: continue
		var phase := float(shape.phase)
		var position := Vector2(float(shape.x) * size.x, float(shape.y) * size.y)
		var radius := float(shape.radius) * (size.x / 900.0) * (0.7 + float(features[0]) * 3.0) * strength
		position += Vector2(sin(t * 0.5 + phase) * 14, cos(t * 0.7 + phase) * 18)
		match int(shape.motion):
			0: radius *= 1 + float(features[1]) * sin(t * 8) # pulse
			1: position.y += sin(t + phase) * 25 # float
			2: position.y = fposmod(position.y + t * 12, size.y) # fall
			3: phase += t * (0.2 + float(features[4]) * 12) # rotate
			4: radius *= 1 + absf(sin(t * 0.6)) * float(features[2]) * 5 # expand
			5: radius *= 1 - minf(0.6, float(features[1])) # contract
			6: position.x += sin(t) * float(features[3]) * 80 # stretch
			7: position.y += sin(position.x * 0.02 + t) * 24 # wave
			8: position += Vector2(sin(t * 27 + phase), cos(t * 31 + phase)) * float(features[4]) * 60 # jitter
			9: position += Vector2(cos(t + phase), sin(t + phase)) * 25 # orbit
			10: position += Vector2(sin(phase), cos(phase)) * float(features[1]) * 90 # scatter
		if profile.motion == "wave": position.y += sin(t + position.x * 0.02) * 22
		if profile.motion == "jitter": position.x += sin(t * 30 + phase) * (2 + float(features[4]) * 50)
		var color: Color = palette[layer]
		color.a = 0.55 + minf(0.45, float(features[0]) * 2)
		if float(shape.type) < float(profile.circle):
			if i % 3 == 0: draw_arc(position, radius, 0, TAU, 48, color, 2, true)
			else: draw_circle(position, maxf(radius, 1), color)
		elif i % 2 == 0:
			var direction := Vector2(cos(phase + t * 0.1), sin(phase + t * 0.1))
			draw_line(position - direction * radius, position + direction * radius * (1 + float(features[3]) * 5), color, 2, true)
		else:
			var points := PackedVector2Array()
			for corner in 3:
				points.append(position + Vector2(cos(phase + corner * TAU / 3 + t * 0.1), sin(phase + corner * TAU / 3 + t * 0.1)) * radius)
			draw_colored_polygon(points, color)
