extends Control
## A record shelf with a permanent listening picture, never below the long list.
var host:Control
var player:AudioStreamPlayer
var visual:VisualCanvas
var note:Label
var library:=LocalRecordLibrary.new()
var monitor_locked:=false
var page:Control
var cover:TextureRect
var title:Label
var scrub:HSlider
var play_button:Button
var rows:VBoxContainer
var current_record:Dictionary={}
var scrubbing:=false

func _ready() -> void:
	add_to_group("town_sound_workspace")
	WorldSound.lock_monitor(true); monitor_locked=true
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme=preload("res://scripts/ui/components/interface_palette.gd").theme_for_tools()
	var backdrop:=ColorRect.new(); backdrop.color=Color("dfccb0"); backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT); add_child(backdrop)
	page=Control.new(); page.size=Vector2(1460,810); add_child(page); resized.connect(_fit); _fit()
	var p=preload("res://scripts/ui/components/interface_palette.gd")
	p.words(page,"把唱片从架上取下来",Vector2(36,24),1060,34)
	p.words(page,"每张封面里，都留着一段你听过的生活。",Vector2(39,78),1100,20)
	_button("回到店里",Vector2(1236,30),Vector2(180,46),func():queue_free())
	for area in [Rect2(22,127,450,625),Rect2(487,127,930,625)]:
		var paper=preload("res://scripts/town_sound/PaperNote.gd").new(); paper.position=area.position; paper.size=area.size; paper.ruled=false; page.add_child(paper)
	var scroll:=ScrollContainer.new(); scroll.position=Vector2(38,147); scroll.size=Vector2(416,582); page.add_child(scroll)
	rows=VBoxContainer.new(); rows.add_theme_constant_override("separation",14); rows.size_flags_horizontal=SIZE_EXPAND_FILL; scroll.add_child(rows)
	player=AudioStreamPlayer.new(); player.bus="Music"; add_child(player)
	player.finished.connect(func():play_button.text="▶ 再听一遍")
	title=p.words(page,"在左边，选一张想听的唱片。",Vector2(650,150),735,25)
	title.max_lines_visible=4; title.clip_text=true; title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	title.custom_maximum_size.y=122
	cover=TextureRect.new(); cover.position=Vector2(510,148); cover.size=Vector2(120,120); cover.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; cover.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; page.add_child(cover)
	visual=VisualCanvas.new(); visual.position=Vector2(631,284); visual.size=Vector2(640,360); visual.mouse_filter=MOUSE_FILTER_IGNORE; page.add_child(visual)
	scrub=HSlider.new(); scrub.position=Vector2(510,650); scrub.size=Vector2(882,28); scrub.step=.01; page.add_child(scrub)
	scrub.value_changed.connect(func(value:float):
		if scrubbing: return
		visual.time=value; visual.queue_redraw()
		if player.playing: player.seek(value))
	play_button=_button("▶ 听一听",Vector2(510,694),Vector2(230,43),_toggle)
	_button("■ 收起声音",Vector2(759,694),Vector2(230,43),func():
		player.stop(); play_button.text="▶ 听一听")
	note=p.words(page,"本地唱片架 · 声音、封面和画面都保存在你的电脑里。",Vector2(38,774),1340,18)
	note.max_lines_visible=1; note.clip_text=true; note.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	var items:=library.list_records(); items.reverse()
	for record in items:
		var item:=HBoxContainer.new(); item.add_theme_constant_override("separation",12); rows.add_child(item)
		var jacket:=TextureRect.new(); jacket.custom_minimum_size=Vector2(92,92); jacket.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; jacket.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		jacket.texture=_cover(record); item.add_child(jacket)
		var b=preload("res://scripts/ui/components/solmere_button.gd").new(); b.variant="archive"; b.alignment=HORIZONTAL_ALIGNMENT_LEFT; b.size_flags_horizontal=SIZE_EXPAND_FILL
		b.text="%s\n%s · %.1f 秒"%[str(record.title).left(14),str(record.artist).left(12),float(record.duration)]
		b.tooltip_text=str(record.title)+" / "+str(record.artist); b.clip_text=true; b.custom_minimum_size=Vector2(255,92); b.pressed.connect(listen.bind(record)); item.add_child(b)
	play_button.disabled=true; scrub.editable=false; visual.hide()
	if items.is_empty(): visual.hide(); title.text="还没有自己的唱片。\n到声音手作桌完成第一张吧。"

func _fit() -> void:
	if page==null:return
	var factor:=minf(size.x/1460,size.y/810)
	page.scale=Vector2.ONE*factor; page.position=(size-Vector2(1460,810)*factor)*.5
func _button(words:String,at:Vector2,extent:Vector2,action:Callable) -> Button:
	var b=preload("res://scripts/ui/components/solmere_button.gd").new(); b.text=words; b.variant="paper"; b.position=at; b.size=extent; b.pressed.connect(action); page.add_child(b); return b
func _cover(record:Dictionary) -> Texture2D:
	var path:=str(record.get("cover_path",""))
	if not FileAccess.file_exists(path): return null
	var image:=Image.load_from_file(path)
	return ImageTexture.create_from_image(image) if image!=null else null
func listen(record:Dictionary) -> void:
	var path:=str(record.get("final_audio_path",""))
	var wav:=AudioStreamWAV.load_from_file(path) if FileAccess.file_exists(path) else null
	if wav==null:
		note.text="这张唱片的音频暂时找不到，其他唱片仍可以听。"; return
	player.stop(); player.stream_paused=false; current_record=record
	visual.show(); visual.configure(wav,str(record.get("visual_prompt","像素")),int(record.get("visual_seed",23817)))
	if record.get("visual_profile") is Dictionary and not record.visual_profile.is_empty(): visual.profile=record.visual_profile.duplicate(true)
	visual.model=null
	if record.get("mv_clips") is Array:
		visual.model=Arrangement.new(); visual.model.clips.assign(record.mv_clips)
		visual.model.muted=record.get("mv_muted",[false,false,false,false]); visual.model.gains=record.get("mv_gains",[1,1,1,1])
	cover.texture=_cover(record); title.text=str(record.title)+"\n"+str(record.artist)+"\n"+str(record.get("one_line_note","")).left(70)
	title.tooltip_text=str(record.title)+" / "+str(record.artist)+"\n"+str(record.get("one_line_note",""))
	scrubbing=true; scrub.max_value=wav.get_length(); scrub.value=0; scrubbing=false
	player.stream=wav; player.play(); play_button.disabled=false; scrub.editable=true; play_button.text="Ⅱ 暂停"
	note.text="正在听「%s」· 拖动进度条，可以回到喜欢的那一刻。"%str(record.title)
	note.tooltip_text=note.text
func _toggle() -> void:
	if player.stream==null:return
	if player.playing and not player.stream_paused: player.stream_paused=true; play_button.text="▶ 接着听"
	elif player.stream_paused: player.stream_paused=false; play_button.text="Ⅱ 暂停"
	else:
		player.play(0 if scrub.value>=scrub.max_value-.1 else scrub.value); play_button.text="Ⅱ 暂停"
func _process(_delta:float) -> void:
	if player!=null and player.playing and not player.stream_paused:
		visual.time=player.get_playback_position(); visual.queue_redraw()
		scrubbing=true; scrub.value=visual.time; scrubbing=false
func _unhandled_input(event:InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): queue_free(); get_viewport().set_input_as_handled()
func _exit_tree() -> void:
	if monitor_locked: WorldSound.lock_monitor(false)
