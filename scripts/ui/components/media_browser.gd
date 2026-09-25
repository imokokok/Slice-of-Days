extends Control
const PALETTE = preload("res://scripts/ui/components/interface_palette.gd")
var owner_ui: Control
var kind := "photo"
var entries: Array = []
var chosen := -1
var player: AudioStreamPlayer
var progress: HSlider
var elapsed: Label
var store := SampleStore.new()
var library := PhotoLibrary.new()
var current_duration := 0.0
var playback_icon: Control
var photo_filter := "all"
func _ready() -> void:
	theme=PALETTE.theme_for_tools()
	size=Vector2(1210,640)
	player=AudioStreamPlayer.new(); player.bus="Music"; add_child(player)
	refresh()
func refresh() -> void:
	player.stop()
	for child in get_children():
		if child!=player: remove_child(child); child.queue_free()
	progress=null
	entries.clear()
	if kind=="photo":
		for row in library.list_photos():
			if str(row.get("role",GameState.current_role))!=GameState.current_role: continue
			if photo_filter=="today" and int(row.get("day",0))!=GameState.current_day: continue
			if photo_filter=="here" and str(row.get("location",""))!=GameState.current_location: continue
			entries.append(row)
	else:
		for row in store.list_samples():
			if str(row.get("role",GameState.current_role))==GameState.current_role: entries.append(row)
	if kind=="sound":
		if entries.is_empty(): _empty_recorder()
		else: show_entry(clampi(chosen,0,entries.size()-1))
		return
	_label("照片收藏",Vector2(12,-8),Vector2(660,60)).add_theme_font_size_override("font_size",31)
	for i in 3:
		var filter_id: String=["all","today","here"][i]
		var filter_button := _button(["全部照片","今天拍的","在这里拍的"][i],Vector2(12+i*164,53),Vector2(150,40),func() -> void: photo_filter=filter_id; refresh())
		filter_button.variant="tab"; filter_button.refresh(); filter_button.add_theme_font_size_override("font_size",20); filter_button.selected=photo_filter==filter_id
	if entries.is_empty():
		_label("还没有冲洗完成的照片。拍摄后到杂货店送洗，照片会进入这里。" if photo_filter=="all" else "这里暂时没有照片。可以换一个分类看看。",Vector2(350,245),Vector2(570,100))
		var camera := TextureRect.new(); var atlas := AtlasTexture.new()
		atlas.atlas=preload("res://art/ui/pocket_doodles/objects.png"); atlas.region=Rect2(1024,0,512,512)
		camera.texture=atlas; camera.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; camera.position=Vector2(111,179); camera.size=Vector2(204,190); camera.mouse_filter=MOUSE_FILTER_IGNORE; add_child(camera)
		return
	var scroll := ScrollContainer.new(); scroll.position=Vector2(5,111); scroll.size=Vector2(1180,474); add_child(scroll)
	var grid := GridContainer.new(); grid.columns=4 if kind=="photo" else 1; grid.add_theme_constant_override("h_separation",16); grid.add_theme_constant_override("v_separation",16); scroll.add_child(grid)
	for i in entries.size():
		var item: Dictionary=entries[i]
		var card := preload("res://scripts/ui/components/solmere_button.gd").new()
		card.variant="archive"
		card.name=("PhotoCard_" if kind=="photo" else "RecordingItem_")+str(i)
		card.custom_minimum_size=Vector2(275,210) if kind=="photo" else Vector2(1120,72)
		card.text=LocalizationSystem.text(str(item.get("title","照片"))) if kind=="photo" else LocalizationSystem.text("%s    Day %02d    %s    %.1fs" % [item.name,int(item.get("game_day",0)),str(item.created_at).left(10),float(item.duration)])
		grid.add_child(card)
		card.add_theme_stylebox_override("normal",_card_style())
		if kind=="photo":
			card.text=""; var photo := library.load_photo(str(item.photo_id))
			if photo!=null: _image(card,photo,Vector2(10,8),Vector2(255,156))
			var title := Label.new(); title.text=LocalizationSystem.text(str(item.get("title","照片"))); title.position=Vector2(12,168); title.size=Vector2(252,32); title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; title.mouse_filter=MOUSE_FILTER_IGNORE; card.add_child(title)
		card.disabled=bool(item.get("missing",false)); card.pressed.connect(show_entry.bind(i))
func show_entry(index: int) -> void:
	chosen=clampi(index,0,entries.size()-1)
	player.stop(); player.stream_paused=false
	for child in get_children():
		if child!=player: remove_child(child); child.queue_free()
	var item: Dictionary=entries[chosen]
	if kind=="photo": _button("← 返回",Vector2(10,10),Vector2(150,42),refresh)
	if kind=="photo":
		var image := library.load_photo(str(item.photo_id))
		if image!=null: _image(self,image,Vector2(100,60),Vector2(1000,400))
		_label("Day %02d · %s · %s" % [int(item.day),TravelSystem.location_name(str(item.location)),str(item.created_at)],Vector2(100,465),Vector2(1000,40))
		_button("上一张",Vector2(330,512),Vector2(200,42),show_entry.bind(maxi(0,chosen-1))).disabled=chosen==0
		_button("下一张",Vector2(650,512),Vector2(200,42),show_entry.bind(mini(entries.size()-1,chosen+1))).disabled=chosen==entries.size()-1
	else:
		progress=null; _recorder_face()
		player.stream=store.load_audio(item); current_duration=float(item.duration)
		var title := LineEdit.new(); title.text=str(item.name); title.position=Vector2(58,113); title.size=Vector2(510,43); add_child(title)
		for state in ["normal","focus"]: title.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		title.add_theme_font_size_override("font_size",25)
		_button("✓",Vector2(602,113),Vector2(42,42),func() -> void:
			if store.rename_sample(str(item.id),title.text):
				item.name=title.text.strip_edges().left(60)
				for record in GameState.artifacts.get("samples",[]):
					if str(record.get("id",""))==str(item.id): record.title=item.name
				ResidencySystem._sync_sources(); ResidencySystem.persist()
			else: owner_ui.feedback.text=LocalizationSystem.text(store.last_error)).tooltip_text=LocalizationSystem.text("保存录音名称")
		_label("Day %02d  ·  %s" % [int(item.get("game_day",0)),str(item.created_at).left(10)],Vector2(58,175),Vector2(596,31)).add_theme_font_size_override("font_size",14)
		var waveform := preload("res://scripts/residency/sound_paper.gd").new(); waveform.wav=player.stream; waveform.position=Vector2(410,237); waveform.size=Vector2(272,112); add_child(waveform)
		if player.stream!=null:
			var visual=load("res://scripts/town_sound/visual/SampleVisual.gd").new()
			visual.player=player; visual.model=Arrangement.new(); visual.model.add_sample(item,0,0)
			visual.configure(player.stream,"像素",int(item.get("mv_seed",23817)))
			visual.position=Vector2(58,215); visual.size=Vector2(320,180); visual.mouse_filter=MOUSE_FILTER_IGNORE; add_child(visual)
		progress=HSlider.new(); progress.position=Vector2(58,415); progress.size=Vector2(624,24); progress.max_value=maxf(.01,float(item.duration)); progress.step=.01; add_child(progress)
		progress.value_changed.connect(func(value: float) -> void:
			if player.playing or player.stream_paused: player.seek(value))
		elapsed=_label("",Vector2(58,446),Vector2(624,28)); elapsed.add_theme_font_size_override("font_size",14)
		var play := _button("播放 / 暂停",Vector2(315,489),Vector2(80,68),_toggle_play)
		# Accessible name stays on the real button; the drawn play symbol is decorative.
		play.add_theme_color_override("font_color",Color.TRANSPARENT); play.add_theme_color_override("font_hover_color",Color.TRANSPARENT); play.add_theme_color_override("font_focus_color",Color.TRANSPARENT); play.add_theme_color_override("font_pressed_color",Color.TRANSPARENT)
		playback_icon=preload("res://scripts/ui/components/ink_icon.gd").new(); playback_icon.kind="play"; playback_icon.position=Vector2(14,9); playback_icon.size=Vector2(50,50); play.add_child(playback_icon)
		_button("− 5s",Vector2(180,503),Vector2(95,44),_seek_by.bind(-5.0))
		_button("+ 5s",Vector2(420,503),Vector2(95,44),_seek_by.bind(5.0))
		var scroll := ScrollContainer.new(); scroll.position=Vector2(755,120); scroll.size=Vector2(415,410); add_child(scroll)
		var rows := VBoxContainer.new(); rows.size_flags_horizontal=SIZE_EXPAND_FILL; scroll.add_child(rows)
		for i in entries.size():
			var row: Dictionary=entries[i]
			var entry := preload("res://scripts/ui/components/solmere_button.gd").new(); entry.name="RecordingItem_"+str(i); entry.alignment=HORIZONTAL_ALIGNMENT_LEFT
			entry.text=""; entry.tooltip_text=str(row.name); entry.custom_minimum_size=Vector2(390,58); entry.selected=i==chosen; entry.disabled=bool(row.get("missing",false)); rows.add_child(entry); entry.pressed.connect(show_entry.bind(i))
			var name_label := Label.new(); name_label.text="▷  "+str(row.name); name_label.position=Vector2(12,15); name_label.size=Vector2(284,30); name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; name_label.mouse_filter=MOUSE_FILTER_IGNORE; name_label.add_theme_font_size_override("font_size",18); entry.add_child(name_label)
			var time := _label(_clock(float(row.duration)),Vector2.ZERO,Vector2(70,42)); remove_child(time); entry.add_child(time); time.position=Vector2(310,17); time.add_theme_font_size_override("font_size",15)
		var remove := _button("删除",Vector2(597,566),Vector2(76,36),func() -> void:
			var confirm := preload("res://scripts/ui/components/confirm_sheet.gd").new()
			confirm.heading="删除录音？"; confirm.description="将「%s」移到本地录音回收目录。" % str(item.name); confirm.confirm_text="删除"
			owner_ui.add_child(confirm)
			confirm.accepted.connect(func() -> void:
				player.stop()
				if store.delete_sample(str(item.id)):
					GameState.artifacts.samples=GameState.artifacts.get("samples",[]).filter(func(row: Dictionary) -> bool: return str(row.get("id",""))!=str(item.id))
					ResidencySystem.state().materials.erase(str(item.id)); ResidencySystem.persist(); refresh()
				else: owner_ui.feedback.text=store.last_error
				confirm.queue_free()))
		for page in ResidencySystem.state().get("free_pages",{}).values():
			if page.any(func(piece: Dictionary) -> bool: return str(piece.get("material",""))==str(item.id)):
				remove.disabled=true; remove.tooltip_text=LocalizationSystem.text("这段录音仍在作品页中使用。")
		if CoreLoopSystem.material_in_use(str(item.id)):
			remove.disabled=true; remove.tooltip_text=LocalizationSystem.text("这段录音已留在分享或申请的记录里。")

func _process(_delta: float) -> void:
	if is_instance_valid(progress):
		if player.playing: progress.set_value_no_signal(player.get_playback_position())
		elapsed.text=_clock(progress.value)+"                                      "+_clock(progress.max_value)
		if is_instance_valid(playback_icon):
			playback_icon.kind="pause" if player.playing and not player.stream_paused else "play"; playback_icon.queue_redraw()
func _clock(seconds: float) -> String: return "%02d:%02d" % [int(seconds)/60,int(seconds)%60]
func _toggle_play() -> void:
	if player.stream_paused: player.stream_paused=false
	elif player.playing: player.stream_paused=true
	else: player.play(progress.value)
func _seek_by(seconds: float) -> void:
	progress.value=clampf(progress.value+seconds,0,progress.max_value)
func _card_style() -> StyleBoxFlat:
	var face := StyleBoxFlat.new(); face.bg_color=Color("fffcf4"); face.set_corner_radius_all(3); face.set_border_width_all(1); face.border_color=Color("beb7a6",.3); return face
func _recorder_face() -> void:
	_label("声音收藏",Vector2(12,-8),Vector2(660,60)).add_theme_font_size_override("font_size",31)
	_button("＋ 新录音",Vector2(915,5),Vector2(260,46),owner_ui._home_action.bind("recorder"))

func _empty_recorder() -> void:
	_recorder_face()
	var badge := TextureRect.new(); var atlas := AtlasTexture.new()
	atlas.atlas=preload("res://art/ui/pocket_doodles/objects.png"); atlas.region=Rect2(0,512,512,512)
	badge.texture=atlas; badge.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; badge.position=Vector2(141,196); badge.size=Vector2(200,190); badge.mouse_filter=MOUSE_FILTER_IGNORE; add_child(badge)
	_label("这里还很安静。",Vector2(404,222),Vector2(600,52)).add_theme_font_size_override("font_size",29)
	_label("把今天听到的小镇声音留下来。\n保存的录音可以试听、改名，也能带到唱片店编排。",Vector2(405,290),Vector2(620,96))

func _label(value: String, at: Vector2, dimensions: Vector2) -> Label:
	var label := PALETTE.words(self,value,at,dimensions.x,20,PALETTE.INK); label.size=dimensions; return label
func _button(value: String, at: Vector2, dimensions: Vector2, action: Callable) -> Button:
	var button := preload("res://scripts/ui/components/solmere_button.gd").new(); button.text=LocalizationSystem.text(value); button.position=at; button.size=dimensions; add_child(button); button.pressed.connect(action); return button
func _image(parent: Node, data: Image, at: Vector2, dimensions: Vector2) -> void:
	var photo := TextureRect.new(); photo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; photo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo.texture=ImageTexture.create_from_image(data); photo.position=at; photo.size=dimensions; photo.mouse_filter=MOUSE_FILTER_IGNORE; parent.add_child(photo)
