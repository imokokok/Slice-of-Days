extends Control
var owner_ui: Control
var kind := "photo"
var entries: Array = []
var chosen := -1
var player: AudioStreamPlayer
var progress: HSlider
var elapsed: Label
var store := SampleStore.new()
var library := PhotoLibrary.new()
func _ready() -> void:
	size=Vector2(1210,560)
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
			if str(row.get("role",GameState.current_role))==GameState.current_role: entries.append(row)
	else:
		for row in store.list_samples():
			if str(row.get("role",GameState.current_role))==GameState.current_role: entries.append(row)
	if entries.is_empty():
		_label("还没有冲洗完成的照片。拍摄后到杂货店送洗，照片会进入这里。" if kind=="photo" else "还没有录音，记录一段小镇的声音吧。",Vector2(40,110),Vector2(1000,70)); return
	var scroll := ScrollContainer.new(); scroll.position=Vector2(5,15); scroll.size=Vector2(1180,515); add_child(scroll)
	var grid := GridContainer.new(); grid.columns=4 if kind=="photo" else 1; grid.add_theme_constant_override("h_separation",16); grid.add_theme_constant_override("v_separation",16); scroll.add_child(grid)
	for i in entries.size():
		var item: Dictionary=entries[i]
		var card := preload("res://scripts/ui/components/solmere_button.gd").new()
		card.name=("PhotoCard_" if kind=="photo" else "RecordingItem_")+str(i)
		card.custom_minimum_size=Vector2(275,210) if kind=="photo" else Vector2(1120,72)
		card.text=str(item.get("title","照片")) if kind=="photo" else "%s    Day %02d    %s    %.1fs" % [item.name,int(item.get("game_day",0)),str(item.created_at).left(10),float(item.duration)]
		grid.add_child(card)
		if kind=="photo":
			card.text=""; var photo := library.load_photo(str(item.photo_id))
			if photo!=null: _image(card,photo,Vector2(10,8),Vector2(255,156))
			var title := Label.new(); title.text=str(item.get("title","照片")); title.position=Vector2(12,168); title.size=Vector2(252,32); title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; title.mouse_filter=MOUSE_FILTER_IGNORE; card.add_child(title)
		card.disabled=bool(item.get("missing",false)); card.pressed.connect(show_entry.bind(i))
func show_entry(index: int) -> void:
	chosen=clampi(index,0,entries.size()-1)
	player.stop(); player.stream_paused=false
	for child in get_children():
		if child!=player: remove_child(child); child.queue_free()
	var item: Dictionary=entries[chosen]
	_button("← 返回",Vector2(10,10),Vector2(150,42),refresh)
	if kind=="photo":
		var image := library.load_photo(str(item.photo_id))
		if image!=null: _image(self,image,Vector2(100,60),Vector2(1000,400))
		_label("Day %02d · %s · %s" % [int(item.day),TravelSystem.location_name(str(item.location)),str(item.created_at)],Vector2(100,465),Vector2(1000,40))
		_button("上一张",Vector2(330,512),Vector2(200,42),show_entry.bind(maxi(0,chosen-1))).disabled=chosen==0
		_button("下一张",Vector2(650,512),Vector2(200,42),show_entry.bind(mini(entries.size()-1,chosen+1))).disabled=chosen==entries.size()-1
	else:
		player.stream=store.load_audio(item)
		var title := LineEdit.new(); title.text=str(item.name); title.position=Vector2(180,20); title.size=Vector2(710,45); add_child(title)
		_button("重命名",Vector2(910,20),Vector2(200,45),func() -> void:
			if store.rename_sample(str(item.id),title.text):
				item.name=title.text.strip_edges().left(60)
				for record in GameState.artifacts.get("samples",[]):
					if str(record.get("id",""))==str(item.id): record.title=item.name
				ResidencySystem._sync_sources(); ResidencySystem.persist()
			else: owner_ui.feedback.text=store.last_error)
		var waveform := preload("res://scripts/residency/sound_paper.gd").new(); waveform.wav=player.stream; waveform.position=Vector2(100,100); waveform.size=Vector2(1000,180); add_child(waveform)
		progress=HSlider.new(); progress.position=Vector2(100,305); progress.size=Vector2(1000,35); progress.max_value=maxf(.01,float(item.duration)); progress.step=.01; add_child(progress)
		progress.value_changed.connect(func(value: float) -> void: if player.playing: player.seek(value))
		elapsed=_label("",Vector2(100,352),Vector2(1000,40))
		_button("播放 / 暂停",Vector2(370,405),Vector2(270,50),func() -> void:
			if player.stream_paused: player.stream_paused=false
			elif player.playing: player.stream_paused=true
			else: player.play(progress.value))
		var remove := _button("删除录音",Vector2(900,475),Vector2(200,45),func() -> void:
			player.stop()
			if store.delete_sample(str(item.id)):
				GameState.artifacts.samples=GameState.artifacts.get("samples",[]).filter(func(row: Dictionary) -> bool: return str(row.get("id",""))!=str(item.id))
				ResidencySystem.state().materials.erase(str(item.id)); ResidencySystem.persist(); refresh()
			else: owner_ui.feedback.text=store.last_error)
		for page in ResidencySystem.state().get("free_pages",{}).values():
			if page.any(func(piece: Dictionary) -> bool: return str(piece.get("material",""))==str(item.id)):
				remove.disabled=true; remove.tooltip_text="这段录音仍在作品页中使用。"
func _process(_delta: float) -> void:
	if is_instance_valid(progress):
		if player.playing: progress.set_value_no_signal(player.get_playback_position())
		elapsed.text="%05.1f / %05.1f s  ·  %s" % [progress.value,progress.max_value,"暂停" if player.stream_paused else "播放中" if player.playing else "已停止"]
func _label(value: String, at: Vector2, dimensions: Vector2) -> Label:
	var label := Label.new(); label.text=value; label.position=at; label.size=dimensions; add_child(label); return label
func _button(value: String, at: Vector2, dimensions: Vector2, action: Callable) -> Button:
	var button := preload("res://scripts/ui/components/solmere_button.gd").new(); button.text=value; button.position=at; button.size=dimensions; add_child(button); button.pressed.connect(action); return button
func _image(parent: Node, data: Image, at: Vector2, dimensions: Vector2) -> void:
	var photo := TextureRect.new(); photo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; photo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo.texture=ImageTexture.create_from_image(data); photo.position=at; photo.size=dimensions; photo.mouse_filter=MOUSE_FILTER_IGNORE; parent.add_child(photo)
