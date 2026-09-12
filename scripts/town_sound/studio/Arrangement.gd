class_name Arrangement
extends RefCounted

const RATE := 22050
var clips: Array[Dictionary] = []
var muted := [false, false, false, false]
var gains := [1.0, 1.0, 1.0, 1.0]
var prompt := "温暖，圆，细线，慢慢漂浮"
var seed_value := 23817
var cache: Dictionary = {}
var error := ""
var project_path := "user://projects/current.json"

func length() -> float:
	var result := 0.0
	for clip in clips:
		result = maxf(result, clip.start + clip.length)
	return minf(result, 60.0)

func add_sample(item: Dictionary, track: int, at: float) -> int:
	if not is_finite(at): return -1
	at = clampf(at, 0.0, 60.0)
	var duration := minf(float(item.duration), 60.0 - at)
	if duration <= 0:
		return -1
	clips.append({"sample_id": item.id, "name": item.name, "track": clampi(track, 0, 3), "start": at,
		"source_start": 0.0, "source_end": float(item.duration), "volume": 1.0, "speed": 1.0,
		"loop": false, "fade_in": 0.0, "fade_out": 0.0, "length": duration})
	return clips.size() - 1

func split(index: int, at: float) -> bool:
	if index < 0 or index >= clips.size():
		return false
	var clip := clips[index]
	var offset := at - float(clip.start)
	if offset <= 0.01 or offset >= float(clip.length) - 0.01:
		return false
	var other := clip.duplicate(true)
	other.start = at
	other.length = float(clip.length) - offset
	# Phase is independent of trim bounds so splitting a loop remains seamless.
	other.phase = float(clip.get("phase", 0.0)) + offset * float(clip.speed)
	clip.length = offset
	clip.fade_out = 0.0
	other.fade_in = 0.0
	clips.insert(index + 1, other)
	return true

func duplicate_clip(index: int) -> int:
	if index < 0 or index >= clips.size():
		return -1
	var clip := clips[index].duplicate(true)
	clip.start = minf(60.0 - float(clip.length), float(clip.start) + float(clip.length))
	clips.append(clip)
	return clips.size() - 1

func remove_range(begin: float, end: float, track: int) -> void:
	if not is_finite(begin) or not is_finite(end) or end <= begin: return
	begin = clampf(begin, 0, 60)
	end = clampf(end, 0, 60)
	var result: Array[Dictionary] = []
	for clip in clips:
		var finish := float(clip.start) + float(clip.length)
		if int(clip.track) != track or finish <= begin or float(clip.start) >= end:
			result.append(clip)
			continue
		if float(clip.start) < begin:
			var left := clip.duplicate(true)
			left.length = begin - float(clip.start)
			left.fade_out = 0.0
			result.append(left)
		if finish > end:
			var right := clip.duplicate(true)
			right.start = end
			right.length = finish - end
			right.phase = float(clip.get("phase", 0.0)) + (end - float(clip.start)) * float(clip.speed)
			right.fade_in = 0.0
			result.append(right)
	clips = result

func keep_range(begin: float, end: float, track: int) -> void:
	if not is_finite(begin) or not is_finite(end) or end <= begin: return
	remove_range(end, 60.0, track)
	remove_range(0.0, begin, track)

func load_pcm(sample_id: String) -> Dictionary:
	if cache.has(sample_id):
		return cache[sample_id]
	var path := "user://samples/" + sample_id + ".wav"
	if not FileAccess.file_exists(path):
		error = "找不到原始录音：" + sample_id
		return {}
	var wav := AudioStreamWAV.load_from_file(path)
	if wav == null or wav.format != AudioStreamWAV.FORMAT_16_BITS:
		error = "无法读取录音 PCM。"
		return {}
	var bytes := wav.data
	var channels := 2 if wav.stereo else 1
	var pcm := PackedFloat32Array()
	pcm.resize(bytes.size() / (2 * channels))
	for i in pcm.size():
		var sample_value := float(bytes.decode_s16(i * 2 * channels)) / 32768.0
		if channels == 2: sample_value = (sample_value + float(bytes.decode_s16(i * 4 + 2)) / 32768.0) * 0.5
		pcm[i] = sample_value
	cache[sample_id] = {"pcm": pcm, "rate": wav.mix_rate}
	return cache[sample_id]

func mix() -> AudioStreamWAV:
	error = ""
	var seconds := length()
	if seconds <= 0:
		error = "时间轴还是空的。"
		return null
	var output := PackedFloat32Array()
	output.resize(ceili(seconds * RATE))
	for clip in clips:
		if muted[int(clip.track)]:
			continue
		var source := load_pcm(clip.sample_id)
		if source.is_empty():
			return null
		var pcm: PackedFloat32Array = source.pcm
		var rate := float(source.rate)
		var span := float(clip.source_end) - float(clip.source_start)
		if span <= 0:
			continue
		var begin := int(round(float(clip.start) * RATE))
		var count := mini(int(round(float(clip.length) * RATE)), output.size() - begin)
		for frame in count:
			var time := float(frame) / RATE
			var offset := time * float(clip.speed) + float(clip.get("phase", 0.0))
			if clip.loop:
				offset = fposmod(offset, span)
			elif offset >= span:
				break
			var position := (float(clip.source_start) + offset) * rate
			var left := int(position)
			if left < 0 or left >= pcm.size():
				continue
			var value := lerpf(pcm[left], pcm[mini(left + 1, pcm.size() - 1)], position - left)
			var envelope := 1.0
			if float(clip.fade_in) > 0:
				envelope *= minf(1.0, time / float(clip.fade_in))
			if float(clip.fade_out) > 0:
				envelope *= minf(1.0, (float(clip.length) - time) / float(clip.fade_out))
			output[begin + frame] += value * envelope * float(clip.volume) * float(gains[int(clip.track)])
	var bytes := PackedByteArray()
	bytes.resize(output.size() * 2)
	for i in output.size():
		bytes.encode_s16(i * 2, int(clampf(output[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = bytes
	return wav

func save_project() -> bool:
	DirAccess.make_dir_recursive_absolute(project_path.get_base_dir())
	var file := FileAccess.open(project_path + ".tmp", FileAccess.WRITE)
	if file == null:
		error = "工程无法写入。"
		return false
	file.store_string(JSON.stringify({"version": 1, "clips": clips, "muted": muted, "gains": gains,
		"prompt": prompt, "seed": seed_value}, "\t"))
	file.flush()
	var result := file.get_error()
	file.close()
	if result != OK:
		error = "工程写入不完整。"
		return false
	result = DirAccess.rename_absolute(project_path + ".tmp", project_path)
	if result != OK:
		error = "工程保存失败。"
	return result == OK

func load_project() -> bool:
	if not FileAccess.file_exists(project_path):
		return false
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(project_path)) != OK or not parser.data is Dictionary:
		error = "工程损坏，保留原文件。"
		return false
	var value: Dictionary = parser.data
	if not value.get("clips") is Array or not value.get("muted") is Array or not value.get("gains") is Array:
		error = "工程结构无效。"
		return false
	if value.muted.size() != 4 or value.gains.size() != 4:
		error = "工程轨道数量无效。"
		return false
	for i in 4:
		if not value.muted[i] is bool or not valid_number(value.gains[i]) or float(value.gains[i]) < 0 or float(value.gains[i]) > 1.5:
			error = "工程轨道音量无效。"
			return false
	var restored: Array[Dictionary] = []
	for clip in value.clips:
		if not clip is Dictionary or not clip.has_all(["sample_id", "name", "track", "start", "source_start", "source_end", "volume", "speed", "loop", "fade_in", "fade_out", "length"]):
			error = "工程片段信息不完整。"
			return false
		for key in ["track", "start", "source_start", "source_end", "volume", "speed", "fade_in", "fade_out", "length"]:
			if not valid_number(clip[key]):
				error = "工程片段数值无效。"
				return false
		if not clip.sample_id is String or str(clip.sample_id).get_file() != clip.sample_id or not clip.loop is bool or not valid_number(clip.get("phase", 0)):
			error = "工程片段来源无效。"
			return false
		if float(clip.source_start) < 0 or float(clip.source_end) <= float(clip.source_start) or float(clip.volume) < 0 or float(clip.volume) > 2 or float(clip.fade_in) < 0 or float(clip.fade_out) < 0:
			error = "工程裁剪或音量无效。"
			return false
		if float(clip.start) < 0 or float(clip.length) <= 0 or float(clip.start) + float(clip.length) > 60.01 or int(clip.track) < 0 or int(clip.track) > 3 or float(clip.speed) < 0.5 or float(clip.speed) > 2:
			error = "工程片段超出范围。"
			return false
		restored.append(clip)
	clips = restored
	muted = value.muted
	gains = value.gains
	prompt = str(value.get("prompt", ""))
	seed_value = int(value.get("seed", 23817))
	return true

static func valid_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
