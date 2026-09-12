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
	# Three unequal clusters create hierarchy and deliberate negative space.
	var anchors := [Vector2(0.28, 0.34), Vector2(0.63, 0.58), Vector2(0.79, 0.29)]
	for i in int(float(profile.density) * 28 + 14):
		var anchor: Vector2 = anchors[i % 3]
		shapes.append({"x": clampf(anchor.x + rng.randf_range(-0.17, 0.17), 0.10, 0.89),
			"y": clampf(anchor.y + rng.randf_range(-0.21, 0.24), 0.12, 0.84),
			"radius": rng.randf_range(12, 44), "phase": rng.randf_range(-0.8, 0.8),
			"type": i % 7, "layer": i % 4, "motion": i % 11})
	shapes[0].merge({"x": 0.25 + rng.randf_range(-0.04, 0.04), "y": 0.33, "radius": 83.0, "type": 0}, true)
	shapes[1].merge({"x": 0.57, "y": 0.57, "radius": 100.0, "type": 1}, true)
	shapes[2].merge({"x": 0.70, "y": 0.58, "radius": 137.0, "type": 2}, true)
	queue_redraw()

static func parse_prompt(text: String, seed_number: int) -> Dictionary:
	var value := text.to_lower()
	var result := {"palette": "warm", "circle": 0.55, "density": 0.4, "speed": 0.7,
		"motion": "floating", "randomness": 0.2, "seed": seed_number, "visual_version": 2}
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
	draw_rect(Rect2(Vector2.ZERO, size), Color("efe7d3"))
	if profile.is_empty(): return
	analyze()
	# Work in a fixed artboard so covers and playback have identical composition.
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(960, 540))
	var ink := Color("25242c")
	var palette := [Color("265594"), Color("e0b337"), Color("b74636"), Color("262536")]
	if profile.palette == "cool": palette = [Color("244f8d"), Color("6e9c9a"), Color("b16b70"), Color("293849")]
	if profile.palette == "red": palette = [Color("993e45"), Color("d18a3e"), Color("c24f32"), Color("262432")]
	if profile.palette == "yellow": palette = [Color("386497"), Color("ebc238"), Color("d96736"), Color("343245")]
	# Subtle fixed paper fibres. No frame-random noise or flashing.
	for n in 65:
		var y := float(n) * 8.4
		draw_line(Vector2(0, y), Vector2(960, y + 0.6), Color(0.32, 0.26, 0.17, 0.025), 0.6)
	var bass := clampf(float(features[2]) * 5.0, 0, 1)
	var middle := clampf(float(features[3]) * 6.0, 0, 1)
	var treble := clampf(float(features[4]) * 10.0, 0, 1)
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
		var pos := Vector2(float(shape.x) * 960, float(shape.y) * 540)
		var phase := float(shape.phase)
		var r := float(shape.radius)
		var color: Color = palette[layer]
		color.a = clampf(0.65 + strength * 0.22, 0, 0.93)
		var angle := phase + sin(t * 0.35 + phase) * middle * 0.08
		pos += Vector2(sin(t * 0.4 + phase), cos(t * 0.3 + phase)) * middle * 6
		if profile.motion == "wave": pos.y += sin(t + pos.x * 0.01) * middle * 10
		var kind := int(shape.type)
		if i > 3 and float(profile.circle) > 0.8 and i % 2 == 0: kind = 0
		match kind:
			0: # Low tones: weighted circles, offset inner discs and fine halos.
				r *= 1.0 + bass * 0.12
				draw_circle(pos, r, Color(color, 0.14))
				draw_circle(pos, r * 0.86, ink if i == 0 else color)
				draw_circle(pos + Vector2(-r * 0.08, r * 0.035), r * 0.59, color if i == 0 else Color("e9dfc7"))
				draw_arc(pos + Vector2(r * 0.05, 0), r * 1.08, 0, TAU, 96, Color(ink, 0.65), 1.2, true)
			1: # Mid tones: long wedges under tension, rather than equal triangles.
				var points := PackedVector2Array([Vector2(-r * 0.48, r * 0.55), Vector2(r * 0.38, r * 0.49), Vector2(r * 0.14, -r * 1.3)])
				for j in points.size(): points[j] = pos + points[j].rotated(angle)
				draw_colored_polygon(points, Color(color, 0.60))
				draw_polyline(PackedVector2Array([points[0], points[2], points[1]]), ink, 1.3, true)
			2: # Oblique counterweight and adjacent rhythmic bars.
				var direction := Vector2(1, -0.65).rotated(angle)
				var normal := direction.orthogonal().normalized()
				draw_line(pos - direction * r, pos + direction * r, ink, 1.5 + middle * 1.5, true)
				for j in 5:
					var start := pos + direction * (float(j) - 2) * 12
					draw_line(start - normal * 13, start + normal * (22 + treble * 8), Color(ink, 0.8), 1, true)
			3: # Open arcs share a baseline, carrying the upper-frequency rhythm.
				for j in 3:
					draw_arc(pos + Vector2(j * 18, j * -4), r * 0.48, PI + angle, TAU + angle, 40, ink, 1.2 + treble, true)
			4: # Small checkerboard gives dense passages a measured rhythm.
				for row in 3:
					for col in 4:
						var cell := PackedVector2Array()
						for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
							cell.append(pos + ((Vector2(col - 2, row - 1) + corner) * 10).rotated(angle))
						draw_colored_polygon(cell, Color(ink if (row + col) % 2 == 0 else color, 0.72))
			5:
				var direction := Vector2(cos(angle), sin(angle))
				draw_line(pos - direction * r, pos + direction * r, ink, 0.9, true)
				draw_circle(pos + direction * r * 0.6, 3.5 + treble * 3, color)
			6:
				draw_arc(pos, r, phase, phase + PI * 1.5, 50, Color(color, 0.65), 4.0 + bass * 2, true)
	draw_set_transform(Vector2.ZERO)
