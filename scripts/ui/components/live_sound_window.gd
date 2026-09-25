extends Panel
## A live view of the world plus imagery driven by recorded PCM, never a loop.
var source: Control
var energy := 0.0
var motion := 0.0
var frames_seen := 0
var bands := PackedFloat32Array([0,0,0,0,0,0])
func _ready() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE
	clip_contents=true
	var face := StyleBoxEmpty.new(); add_theme_stylebox_override("panel",face)
func _process(delta: float) -> void:
	if not is_instance_valid(source): return
	var peak := 0.0
	if source.recorder.capturing and not source.levels.is_empty(): peak=float(source.levels.back())
	elif source.playback.playing and source.playback.stream is AudioStreamWAV:
		var wav: AudioStreamWAV=source.playback.stream
		var start := int(source.playback.get_playback_position()*wav.mix_rate)*2
		for i in range(start,mini(start+1024,wav.data.size()-1),8): peak=maxf(peak,absf(wav.data.decode_s16(i)/32768.0))
	energy=lerpf(energy,clampf(peak*6,0,1),1-exp(-delta*14))
	var next := PackedFloat32Array([0,0,0,0,0,0])
	if source.recorder.capturing: next=source.recorder.spectrum_levels()
	elif source.playback.playing and source.playback.stream is AudioStreamWAV:
		next=preload("res://scripts/town_sound/audio/SignalSpectrum.gd").from_wav(source.playback.stream,source.playback.get_playback_position())
	for i in 6: bands[i]=lerpf(bands[i],next[i],1-exp(-delta*12))
	if energy>.002: motion+=delta*energy*3
	frames_seen+=1; queue_redraw()
func _draw() -> void:
	if not is_instance_valid(source): return
	var at: float = float(source.recorder.frame_count)/source.recorder.sample_rate if source.recorder.capturing else source.playback.get_playback_position()
	var seed_value:int=source.current_mv_seed() if source.has_method("current_mv_seed") else source.mv_seed
	preload("res://scripts/town_sound/visual/PixelScore.gd").paint(self,size,at,energy,bands,source.current_mv_kind(),seed_value)
