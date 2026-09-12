class_name SoundTimeline
extends Control

signal selected_changed(index: int)
signal edited
signal seek_requested(seconds: float)
signal region_selected(begin: float, end: float, track: int)
var arrangement: Arrangement
var selected := -1
var playhead := 0.0
var drag_mode := ""
var down := Vector2.ZERO
var original: Dictionary = {}
var peak_cache: Dictionary = {}
var selection_mode := false
var range_begin := -1.0
var range_end := -1.0
var range_track := 0
var pixels_per_second := 30.0
const COLORS := [Color("bfc9a1"), Color("9dbbb8"), Color("d8aa87"), Color("c7b7ca")]

func _ready() -> void:
	custom_minimum_size = Vector2(1800, 310)
	mouse_default_cursor_shape = Control.CURSOR_CROSS

func clip_rect(clip: Dictionary) -> Rect2:
	return Rect2(float(clip.start) / 60.0 * size.x, 36 + int(clip.track) * 66, maxf(6, float(clip.length) / 60.0 * size.x), 54)

func _draw() -> void:
	if arrangement == null:
		return
	for second in range(0, 61, 5):
		var x := float(second) / 60.0 * size.x
		draw_line(Vector2(x, 24), Vector2(x, 302), Color("d5d2c5"))
		draw_string(ThemeDB.fallback_font, Vector2(x + 2, 17), str(second), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("5b665d"))
	for track in 4:
		draw_rect(Rect2(0, 32 + track * 66, size.x, 62), Color(0.6, 0.6, 0.5, 0.06))
	for i in arrangement.clips.size():
		var clip := arrangement.clips[i]
		var rect := clip_rect(clip)
		var color: Color = COLORS[int(clip.track)]
		if arrangement.muted[int(clip.track)]:
			color.a = 0.3
		draw_rect(rect, color)
		if i == selected:
			draw_rect(rect, Color("aa613d"), false, 2)
			draw_rect(Rect2(rect.position, Vector2(minf(12, rect.size.x / 3), rect.size.y)), Color("aa613d"))
			draw_rect(Rect2(rect.end.x - minf(12, rect.size.x / 3), rect.position.y, minf(12, rect.size.x / 3), rect.size.y), Color("aa613d"))
		var source := arrangement.load_pcm(clip.sample_id)
		if not source.is_empty():
			var key := str(clip.sample_id)
			if not peak_cache.has(key):
				var peaks := PackedFloat32Array()
				var pcm: PackedFloat32Array = source.pcm
				for bucket in 300:
					var peak := 0.0
					for frame in range(int(float(bucket) / 300 * pcm.size()), int(float(bucket + 1) / 300 * pcm.size())):
						peak = maxf(peak, absf(pcm[frame]))
					peaks.append(peak)
				peak_cache[key] = peaks
			var duration := float(source.pcm.size()) / float(source.rate)
			for pixel in range(3, int(rect.size.x) - 3, 3):
				var source_time := float(pixel) / rect.size.x * float(clip.length) * float(clip.speed) + float(clip.get("phase", 0.0))
				var span := float(clip.source_end) - float(clip.source_start)
				if span <= 0 or (not clip.loop and source_time > span):
					continue
				source_time = float(clip.source_start) + fposmod(source_time, span)
				var height := float(peak_cache[key][clampi(int(source_time / duration * 300), 0, 299)]) * 15
				var center := rect.position + Vector2(pixel, 35)
				draw_line(center - Vector2(0, maxf(1, height)), center + Vector2(0, maxf(1, height)), Color("506052"), 1)
		draw_string(get_theme_default_font(), rect.position + Vector2(5, 17), str(clip.name), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 10, 12, Color("273d31"))
	if range_begin >= 0 and range_end >= 0:
		var begin := minf(range_begin, range_end)
		var end := maxf(range_begin, range_end)
		var region := Rect2(begin / 60.0 * size.x, 32 + range_track * 66, (end - begin) / 60.0 * size.x, 62)
		draw_rect(region, Color(0.95, 0.67, 0.22, 0.32))
		draw_rect(region, Color("a6602a"), false, 2)
	var cursor := playhead / 60.0 * size.x
	draw_line(Vector2(cursor, 22), Vector2(cursor, 302), Color("af5333"), 2)

func _get_drag_data(_at: Vector2) -> Variant:
	return null

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("sample")

func _drop_data(at: Vector2, data: Variant) -> void:
	selected = arrangement.add_sample(data.sample, clampi(int((at.y - 32) / 66), 0, 3), clampf(at.x / size.x * 60.0, 0, 59.8))
	selected_changed.emit(selected)
	edited.emit()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			if drag_mode == "range":
				region_selected.emit(minf(range_begin, range_end), maxf(range_begin, range_end), range_track)
				drag_mode = ""
				return
			if not drag_mode.is_empty():
				edited.emit()
			drag_mode = ""
			return
		down = event.position
		if down.y < 30:
			seek_requested.emit(clampf(down.x / size.x * 60.0, 0, 60))
			return
		if selection_mode:
			range_begin = clampf(down.x / size.x * 60.0, 0, 60)
			range_end = range_begin
			range_track = clampi(int((down.y - 32) / 66), 0, 3)
			drag_mode = "range"
			queue_redraw()
			return
		range_begin = -1
		range_end = -1
		region_selected.emit(-1, -1, range_track)
		selected = -1
		for i in range(arrangement.clips.size() - 1, -1, -1):
			var rect := clip_rect(arrangement.clips[i])
			if rect.has_point(down):
				selected = i
				original = arrangement.clips[i].duplicate(true)
				var handle := minf(12, rect.size.x / 3)
				drag_mode = "left" if down.x - rect.position.x < handle else ("right" if rect.end.x - down.x < handle else "move")
				break
		selected_changed.emit(selected)
		if selected < 0:
			seek_requested.emit(clampf(down.x / size.x * 60.0, 0, 60))
		queue_redraw()
	elif event is InputEventMouseMotion and drag_mode == "range":
		range_end = clampf(event.position.x / size.x * 60.0, 0, 60)
		queue_redraw()
	elif event is InputEventMouseMotion and not drag_mode.is_empty() and selected >= 0:
		var clip := arrangement.clips[selected]
		var delta: float = (event.position.x - down.x) / size.x * 60.0
		if drag_mode == "move":
			clip.start = clampf(snappedf(float(original.start) + delta, 0.05), 0, 60 - float(clip.length))
			clip.track = clampi(int((event.position.y - 32) / 66), 0, 3)
		elif drag_mode == "right":
			var maximum := 60.0 - float(clip.start)
			if not clip.loop:
				var source := arrangement.load_pcm(clip.sample_id)
				if source.is_empty():
					return
				maximum = minf(maximum, (float(source.pcm.size()) / float(source.rate) - float(clip.source_start) - float(clip.get("phase", 0))) / float(clip.speed))
			clip.length = clampf(float(original.length) + delta, 0.05, maxf(0.05, maximum))
			if not clip.loop:
				clip.source_end = float(clip.source_start) + float(clip.get("phase", 0)) + float(clip.length) * float(clip.speed)
		elif drag_mode == "left":
			var earliest := -float(original.start) if clip.loop else maxf(-float(original.start), -float(original.source_start) / float(original.speed))
			var movement := clampf(delta, earliest, float(original.length) - 0.05)
			clip.start = float(original.start) + movement
			clip.length = float(original.length) - movement
			if clip.loop:
				clip.phase = float(original.get("phase", 0.0)) + movement * float(original.speed)
			else:
				clip.source_start = float(original.source_start) + movement * float(original.speed)
		queue_redraw()
