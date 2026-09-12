extends RefCounted
## Authored procedural resident compositions, clearly separate from microphone recordings.
static func ensure_presets() -> void:
	var library := LocalRecordLibrary.new()
	var existing: Dictionary = {}
	for record in library.list_records():
		existing[str(record.get("preset_key", ""))] = true
	var titles := ["Late Bus Home", "Kitchen, 11:43", "Before It Rained"]
	for index in 3:
		if existing.has(str(index)): continue
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = 22050
		var bytes := PackedByteArray()
		bytes.resize(22050 * 12 * 2)
		var rng := RandomNumberGenerator.new()
		rng.seed = index + 10
		for i in 22050 * 12:
			var time := float(i) / 22050
			var phase := fmod(time, 0.5 + index * 0.125)
			var value := sin(time * TAU * (110 + index * 55)) * 0.09 * (0.6 + sin(time * 0.7) * 0.3)
			value += sin(phase * TAU * (440 + int(time) % 4 * 110)) * exp(-phase * 18) * 0.2
			value += rng.randf_range(-0.04, 0.04) * exp(-phase * 45)
			value *= minf(1, time) * minf(1, 12 - time)
			bytes.encode_s16(i * 2, int(value * 32767))
		wav.data = bytes
		var image := Image.create(512, 512, false, Image.FORMAT_RGB8)
		image.fill(Color("eee5d3"))
		for y in 512:
			for x in 512:
				if Vector2(x - 230, y - 235).length() < 140 - index * 20:
					image.set_pixel(x, y, [Color("c27651"), Color("76958e"), Color("b7ac65")][index])
		library.save_record({"preset_key": str(index), "origin": "preset", "title": titles[index], "artist": ["Mina", "Jules", "Solmere"][index],
			"one_line_note": "居民唱片 · 本地程序化原创小品", "duration": 12.0, "payment": 0, "visual_prompt": ["warm circles", "blue wave", "calm minimal"][index],
			"visual_seed": index + 10, "visual_version": 1}, wav, image)
