extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func tone(hz: float) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(22050 * 2)
	for i in 22050: data.encode_s16(i * 2, int(sin(float(i) / 22050 * TAU * hz) * 8000))
	wav.data = data
	return wav
func run() -> void:
	var canvas := VisualCanvas.new()
	canvas.size = Vector2(960, 540)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(canvas)
	canvas.configure(tone(100), "黄 蓝 圆 线 留白", 23817)
	canvas.time = 0.5
	canvas.analyze()
	check(canvas.features[2] > canvas.features[4], "Bass is not distinguished from treble")
	var original := canvas.shapes.duplicate(true)
	canvas.configure(tone(5000), "黄 蓝 圆 线 留白", 23817)
	canvas.analyze()
	check(canvas.features[4] > canvas.features[2], "Treble is not distinguished from bass")
	check(canvas.shapes == original, "Audio playback changed deterministic composition")
	canvas.configure(tone(220), "黄 蓝 圆 线 留白", 14771)
	check(canvas.shapes != original, "Seed does not alter composition")
	canvas.configure(tone(220), "黄 蓝 圆 线 留白", 23817)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://tests/screenshots")
	viewport.get_texture().get_image().save_png("user://tests/screenshots/visual-composition-v2.png")
	viewport.free()
	print("VISUAL_COMPOSITION_TESTS: ", "PASS" if failures == 0 else "FAIL")
	quit(failures)
