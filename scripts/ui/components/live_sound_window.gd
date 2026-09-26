extends Panel
## A live view of the world plus imagery driven by recorded PCM, never a loop.
var source: Node
var energy := 0.0
var motion := 0.0
var frames_seen := 0
var bands := PackedFloat32Array([0,0,0,0,0,0])
var world_picture: ColorRect
var picture_caption: Label
func _ready() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE
	clip_contents=true
	var face := StyleBoxEmpty.new(); add_theme_stylebox_override("panel",face)
	world_picture=ColorRect.new(); world_picture.name="LiveTownPicture"; world_picture.mouse_filter=MOUSE_FILTER_IGNORE
	var shader:=Shader.new()
	shader.code="shader_type canvas_item; uniform sampler2D town : hint_screen_texture, filter_linear; void fragment(){ vec2 world_uv=vec2(mix(0.13,0.87,UV.x),mix(0.20,0.72,UV.y)); COLOR=vec4(textureLod(town,world_uv,0.0).rgb,1.0); }"
	var material:=ShaderMaterial.new(); material.shader=shader; world_picture.material=material
	add_child(world_picture)
	picture_caption=Label.new(); picture_caption.text="眼前的小镇 · 下方是声音的形状"
	picture_caption.add_theme_color_override("font_color",Color("fff4d9")); picture_caption.add_theme_color_override("font_shadow_color",Color("263d3a")); picture_caption.add_theme_constant_override("shadow_offset_x",1); picture_caption.add_theme_constant_override("shadow_offset_y",1); picture_caption.add_theme_font_size_override("font_size",16)
	picture_caption.mouse_filter=MOUSE_FILTER_IGNORE; add_child(picture_caption)
	resized.connect(_layout_picture); _layout_picture()
func _layout_picture() -> void:
	world_picture.size=Vector2(size.x,size.y*.70)
	picture_caption.position=Vector2(12,10)
func _process(_delta: float) -> void:
	if not is_instance_valid(source): return
	# Saved playback uses its stored score/seed; the current street is not passed
	# off as a video recorded earlier.
	world_picture.visible=size.x>300 and not source.playback.playing
	picture_caption.visible=world_picture.visible
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
