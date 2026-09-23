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
	var view := ColorRect.new(); view.name="LiveScene"; view.mouse_filter=MOUSE_FILTER_IGNORE
	view.set_anchors_and_offsets_preset(PRESET_FULL_RECT); add_child(view); view.show_behind_parent=true
	var shader := Shader.new()
	shader.code="shader_type canvas_item; render_mode unshaded; uniform sampler2D world_frame : hint_screen_texture, filter_linear; void fragment(){ vec2 p=vec2(UV.x,0.11+UV.y*0.82); COLOR=vec4(texture(world_frame,p).rgb,1.0); }"
	var effect := ShaderMaterial.new(); effect.shader=shader; view.material=effect
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
	# Six translucent cut-paper forms follow actual low-to-high frequency energy.
	# Silence settles them; there is no random playback or semantic AI claim.
	var colors := [Color("a9c6bd"),Color("719b9b"),Color("c7c6a1"),Color("ead6a9"),Color("d89c74"),Color("bf785e")]
	for band in 6:
		if bands[band]<.025: continue
		var points := PackedVector2Array()
		var center := Vector2(size.x*(.15+band*.14),size.y*(.54-.04*(band%2)))
		var radius := 12+bands[band]*48
		for i in 9:
			var a := TAU*i/9.0
			points.append(center+Vector2(cos(a),sin(a))*(radius+sin(a*3+motion)*bands[band]*5))
		var color: Color=colors[band]; color.a=.22+bands[band]*.55
		draw_colored_polygon(points,color)
	# Ink ripples expand only when the captured signal has energy.
	if energy>.003:
		var center := Vector2(size.x*.5,size.y*.48)
		for ring in 3:
			var phase := fposmod(motion+ring*.34,1.0)
			var points := PackedVector2Array()
			for i in 55:
				var a := float(i)/54*TAU
				points.append(center+Vector2(cos(a),sin(a)*.56)*(24+phase*110+sin(a*4+motion)*2))
			draw_polyline(points,Color("f7edce",energy*(1-phase)*.8),2.2,true)
	var values: Array=source.levels
	draw_rect(Rect2(0,size.y-45,size.x,45),Color("ece4cc",.94))
	for i in values.size():
		var height := clampf(float(values[i])*110,0,16)
		draw_line(Vector2(21+i*4.35,size.y-23-height),Vector2(21+i*4.35,size.y-23+height),Color("607b7d"),2,true)
	draw_rect(Rect2(Vector2.ONE,size-Vector2.ONE*2),Color("756448"),false,2)
