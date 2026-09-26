extends Panel
## A live view of the world plus imagery driven by recorded PCM, never a loop.
var source: Node
var energy := 0.0
var motion := 0.0
var frames_seen := 0
var bands := PackedFloat32Array([0,0,0,0,0,0])
func _ready() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE
	clip_contents=true
	var face := StyleBoxEmpty.new(); add_theme_stylebox_override("panel",face)
func _process(_delta: float) -> void:
	if not is_instance_valid(source): return
	var features:=[0.0,0.0,0.0,0.0,0.0]
	var analyzer=preload("res://scripts/town_sound/audio/SignalSpectrum.gd")
	if source.recorder.capturing:
		features=analyzer.envelope(source.recorder.pcm,source.recorder.sample_rate,float(source.recorder.frame_count)/source.recorder.sample_rate,false,source.recorder.frame_count)
	elif source.playback.playing and source.playback.stream is AudioStreamWAV:
		var wav:AudioStreamWAV=source.playback.stream
		features=analyzer.envelope(wav.data,wav.mix_rate,source.playback.get_playback_position(),wav.stereo)
	energy=float(features[0]); bands=PackedFloat32Array([features[2],features[3],features[4]])
	frames_seen+=1; queue_redraw()

func _draw() -> void:
	if not is_instance_valid(source): return
	var at: float = float(source.recorder.frame_count)/source.recorder.sample_rate if source.recorder.capturing else source.playback.get_playback_position()
	var seed_value:int=source.current_mv_seed() if source.has_method("current_mv_seed") else source.mv_seed
	preload("res://scripts/town_sound/visual/PixelScore.gd").paint(self,size,at,energy,bands,source.current_mv_kind(),seed_value)
