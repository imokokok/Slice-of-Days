class_name FieldRecorder
extends Node
## A private, muted microphone bus. Capture happens before the bus is muted.
## The microphone is opened only while the player is actively recording.

signal meter_changed(peak: float, seconds: float)
signal completed(wav: AudioStreamWAV, warning: String)
signal failed(message: String)

const MAX_SECONDS := 60.0
const MIN_SECONDS := 0.15
var capturing := false
var capture: AudioEffectCapture
var microphone: AudioStreamPlayer
var pcm := PackedByteArray()
var frame_count := 0
var sample_rate := 48000
var bus_index := -1
var elapsed := 0.0
var largest_peak := 0.0
var discarded_start := 0

func _ready() -> void:
	bus_index = AudioServer.bus_count
	AudioServer.add_bus(bus_index)
	AudioServer.set_bus_name(bus_index, "TownSoundMicrophone")
	AudioServer.set_bus_mute(bus_index, true)
	capture = AudioEffectCapture.new()
	capture.buffer_length = 0.5
	AudioServer.add_bus_effect(bus_index, capture)
	microphone = AudioStreamPlayer.new()
	microphone.bus = "TownSoundMicrophone"
	microphone.stream = AudioStreamMicrophone.new()
	add_child(microphone)
	set_process(false)

func start(device: String) -> bool:
	if capturing:
		return false
	if AudioServer.get_driver_name() == "Dummy":
		failed.emit("MICROPHONE NOT AVAILABLE · 当前音频驱动不支持录音。")
		return false
	if not AudioServer.get_input_device_list().has(device):
		failed.emit("MICROPHONE NOT AVAILABLE · 输入设备已断开，请刷新后重试。")
		return false
	AudioServer.input_device = device
	sample_rate = int(AudioServer.get_mix_rate())
	frame_count = 0
	elapsed = 0.0
	largest_peak = 0.0
	pcm = PackedByteArray()
	pcm.resize(int(MAX_SECONDS * sample_rate) * 2)
	capture.clear_buffer()
	discarded_start = capture.get_discarded_frames()
	capturing = true
	microphone.play()
	set_process(true)
	return true

func _process(delta: float) -> void:
	elapsed += delta
	_drain()
	if elapsed > 2.0 and frame_count == 0:
		_cancel()
		failed.emit("MICROPHONE NOT AVAILABLE · 未收到音频。请检查麦克风权限和输入设备，再点重试。")
	elif frame_count >= int(MAX_SECONDS * sample_rate):
		stop()

func _drain() -> void:
	var count := capture.get_frames_available()
	if count <= 0:
		return
	var frames := capture.get_buffer(count)
	var peak := 0.0
	for frame in frames:
		if frame_count >= int(MAX_SECONDS * sample_rate):
			break
		var mono := clampf((frame.x + frame.y) * 0.5, -1.0, 1.0)
		peak = maxf(peak, absf(mono))
		pcm.encode_s16(frame_count * 2, int(round(mono * 32767.0)))
		frame_count += 1
	largest_peak = maxf(largest_peak, peak)
	meter_changed.emit(peak, float(frame_count) / sample_rate)

func stop() -> void:
	if not capturing:
		return
	_drain()
	_cancel()
	if frame_count < int(MIN_SECONDS * sample_rate):
		failed.emit("录音太短或未收到声音数据，请至少录制 0.15 秒。")
		return
	pcm.resize(frame_count * 2)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = pcm
	var warning := ""
	if largest_peak < 0.0001:
		warning = "这段录音没有可听见的信号。请在声音设置中选择实际麦克风（如 Realtek），然后重新录制。"
	elif largest_peak < 0.01:
		warning = "录音音量非常小。请确认选择了实际麦克风，并靠近麦克风重新录制。"
	elif largest_peak > 0.98:
		warning = "输入接近削波；下次可以离麦克风远一点。"
	if capture.get_discarded_frames() > discarded_start:
		warning += " 录音期间有丢帧，建议重录。"
	completed.emit(wav, warning)
	pcm = PackedByteArray()

func _cancel() -> void:
	capturing = false
	set_process(false)
	microphone.stop()

func _exit_tree() -> void:
	if is_instance_valid(microphone):
		microphone.stop()
	if bus_index >= 0 and bus_index < AudioServer.bus_count:
		AudioServer.remove_bus(bus_index)
