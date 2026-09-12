class_name WaveformView
extends Control

var peaks := PackedFloat32Array()
var ink := Color("708a81")

func set_audio(wav: AudioStreamWAV) -> void:
	peaks.clear()
	if wav != null and wav.format == AudioStreamWAV.FORMAT_16_BITS:
		var bytes := wav.data
		var stride := 4 if wav.stereo else 2
		var frames := bytes.size() / stride
		for bucket in range(180):
			var peak := 0.0
			for frame in range(int(bucket * frames / 180), int((bucket + 1) * frames / 180)):
				peak = maxf(peak, absf(float(bytes.decode_s16(frame * stride)) / 32768.0))
			peaks.append(peak)
	queue_redraw()

func _draw() -> void:
	draw_line(Vector2(0, size.y * 0.5), Vector2(size.x, size.y * 0.5), Color("d9d5c8"), 1.0)
	for i in peaks.size():
		var x := (float(i) + 0.5) / peaks.size() * size.x
		var height := maxf(1.0, peaks[i] * size.y * 0.45)
		draw_line(Vector2(x, size.y * 0.5 - height), Vector2(x, size.y * 0.5 + height), ink, 2.0)
