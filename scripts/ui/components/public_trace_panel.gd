extends Control
## Real shared records; reading changes only discovery metadata, never ownership.
var detail: Label
var actions: VBoxContainer
var media: HBoxContainer
var audio: AudioStreamPlayer
func _ready() -> void:
	add_to_group("meta_modal")
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme=preload("res://art/ui/solmere_ui.tres")
	var panel := PanelContainer.new(); panel.position=Vector2(360,155); panel.size=Vector2(880,590)
	var face := StyleBoxFlat.new(); face.bg_color=Color("faf7ee"); face.set_corner_radius_all(9); face.set_content_margin_all(28); panel.add_theme_stylebox_override("panel",face); add_child(panel)
	var rows := VBoxContainer.new(); rows.add_theme_constant_override("separation",16); panel.add_child(rows)
	var heading := Label.new(); heading.text="公共柜 · 小镇留下的东西"; heading.add_theme_font_size_override("font_size",28); rows.add_child(heading)
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size.y=180; rows.add_child(scroll)
	actions=VBoxContainer.new(); actions.size_flags_horizontal=SIZE_EXPAND_FILL; scroll.add_child(actions)
	var traces := ChapterSystem.traces_at(GameState.current_location)
	for trace in traces:
		var card := preload("res://scripts/ui/components/solmere_button.gd").new()
		card.name="Trace_"+str(trace.id); card.variant="outlined"; card.text=str(trace.title)+" · Day %02d"%int(trace.day); card.custom_minimum_size.y=54
		card.pressed.connect(_read.bind(str(trace.id))); actions.add_child(card)
	if traces.is_empty():
		var empty := Label.new(); empty.text="柜里还没有作品。"; actions.add_child(empty)
	detail=Label.new(); detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; detail.custom_minimum_size=Vector2(800,95); rows.add_child(detail)
	media=HBoxContainer.new(); rows.add_child(media)
	audio=AudioStreamPlayer.new(); audio.bus="Music"; add_child(audio)
	var back := preload("res://scripts/ui/components/solmere_button.gd").new(); back.text="放回柜里"; back.pressed.connect(queue_free); rows.add_child(back)
	back.grab_focus()
func _read(id: String) -> void:
	var snapshot := GameState.to_save_data()
	var trace := ChapterSystem.inspect_trace(id)
	if trace.is_empty(): return
	var payload: Dictionary=trace.payload
	audio.stop()
	for child in media.get_children(): media.remove_child(child); child.queue_free()
	var labels: Array=payload.get("interaction",{}).get("selected_labels",[])
	detail.text=str(trace.title)+"\n"+str(payload.get("label",""))+"\n"+" · ".join(labels)
	if GameState.current_day>=3 and str(trace.owner)!=GameState.current_role: detail.text+="\n这份记录不是我留下的。"
	var record: Dictionary=payload.get("record",{})
	var path := str(record.get("final_audio_path",""))
	if FileAccess.file_exists(path):
		audio.stream=AudioStreamWAV.load_from_file(path)
		var play := preload("res://scripts/ui/components/solmere_button.gd").new(); play.text="听听这张唱片"; media.add_child(play)
		play.pressed.connect(func():
			if audio.playing: audio.stop(); play.text="听听这张唱片"
			else: audio.play(); play.text="停止播放")
		audio.finished.connect(func(): if is_instance_valid(play): play.text="再听一次",CONNECT_ONE_SHOT)
	var preview := str(payload.get("letter",{}).get("preview_path",record.get("cover_path","")))
	if FileAccess.file_exists(preview):
		var photo := TextureRect.new(); photo.texture=ImageTexture.create_from_image(Image.load_from_file(preview)); photo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; photo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; photo.custom_minimum_size=Vector2(180,125); media.add_child(photo)
	if not SaveManager.save_or_report("公共柜记录未能保存"):
		GameState.load_save_data(snapshot); detail.text="暂时没能记下这次查看，可以再试一次。"
	GuidanceSystem.refresh()
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): queue_free(); get_viewport().set_input_as_handled()
