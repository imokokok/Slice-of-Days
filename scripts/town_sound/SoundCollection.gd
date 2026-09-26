extends Control
## One collection view for field and shop. Editing is still a shop activity.
signal closed
signal studio_requested
var shop_mode:=false
var page: Control
var rows: VBoxContainer
var search: LineEdit
var filter: OptionButton
var status: Label
var detail: Label
var name_input: LineEdit
var player: AudioStreamPlayer
var picture: VisualCanvas
var scrub: HSlider
var play: Button
var remove: Button
var rename: Button
var selected: Dictionary={}
var store:=SampleStore.new()
var refreshing:=false
var listened:=false

func _ready() -> void:
	add_to_group("world_tool")
	theme=preload("res://scripts/ui/components/interface_palette.gd").theme_for_tools()
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var backdrop:=ColorRect.new(); backdrop.color=Color("e4cfb3"); backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT); add_child(backdrop)
	page=Control.new(); page.size=Vector2(1460,810); add_child(page); resized.connect(_fit); _fit()
	var p=preload("res://scripts/ui/components/interface_palette.gd")
	for area in [Rect2(22,124,452,632),Rect2(487,124,928,632)]:
		var note=preload("res://scripts/town_sound/PaperNote.gd").new(); note.position=area.position; note.size=area.size; note.ruled=false; page.add_child(note)
	p.words(page,"路上的声音收藏",Vector2(34,28),1000,34)
	p.words(page,"每一段都带着地点、时间和同步画面。",Vector2(37,81),1030,20)
	_button("收好",Vector2(1265,30),Vector2(145,46),_close)
	search=LineEdit.new(); search.placeholder_text="找名字、地点或声音类型"; search.position=Vector2(36,137); search.size=Vector2(423,43); page.add_child(search)
	search.text_changed.connect(func(_text:String): refresh())
	filter=OptionButton.new(); filter.position=Vector2(36,194); filter.size=Vector2(423,42)
	for title in ["全部收藏","今天录的","在这里录的"]: filter.add_item(title)
	page.add_child(filter); filter.item_selected.connect(func(_i:int): refresh())
	var scroll:=ScrollContainer.new(); scroll.position=Vector2(36,254); scroll.size=Vector2(427,420); page.add_child(scroll)
	rows=VBoxContainer.new(); rows.size_flags_horizontal=SIZE_EXPAND_FILL; rows.add_theme_constant_override("separation",8); scroll.add_child(rows)
	if CharacterSystem.owns_pocket_item("recorder"):
		_button("＋ 录下新的声音",Vector2(36,697),Vector2(423,49),func(): _close(); GlobalRecorder.open_recorder.call_deferred())
	name_input=LineEdit.new(); name_input.max_length=60; name_input.placeholder_text="选择左边的一段声音"; name_input.position=Vector2(506,137); name_input.size=Vector2(660,43); page.add_child(name_input)
	rename=_button("记下名字",Vector2(1190,137),Vector2(210,43),_rename)
	detail=p.words(page,"",Vector2(510,194),890,18)
	player=AudioStreamPlayer.new(); player.bus="Music"; add_child(player)
	player.finished.connect(func(): play.text="▶ 听一听")
	picture=load("res://scripts/town_sound/visual/SampleVisual.gd").new(); picture.player=player; picture.position=Vector2(506,245); picture.size=Vector2(894,380); picture.mouse_filter=MOUSE_FILTER_IGNORE; page.add_child(picture)
	scrub=HSlider.new(); scrub.position=Vector2(506,636); scrub.size=Vector2(894,26); scrub.step=.01; page.add_child(scrub)
	scrub.value_changed.connect(func(value:float):
		if refreshing: return
		picture.time=value; picture.queue_redraw()
		if player.playing or player.stream_paused: player.seek(value))
	play=_button("▶ 听一听",Vector2(506,697),Vector2(200,49),_play)
	play.icon=preload("res://scripts/town_sound/SoundIcons.gd").get_icon("play"); play.add_theme_constant_override("icon_max_width",22)
	remove=_button("放入回收袋",Vector2(723,697),Vector2(215,49),_delete)
	var desk:=_button("去声音手作桌 →" if shop_mode else "剪辑和制作 · 去街角唱片店",Vector2(955,697),Vector2(445,49),func(): studio_requested.emit())
	desk.icon=preload("res://scripts/town_sound/SoundIcons.gd").get_icon("scissors" if shop_mode else "map-pin"); desk.add_theme_constant_override("icon_max_width",24)
	if not shop_mode:
		desk.text="唱片店在哪里？"
		desk.pressed.connect(func(): status.text="收好收藏，在街区步行到唱片店门口进入。去手作桌剪辑、调音量、变速，再为唱片制作封套。")
	status=p.words(page,"",Vector2(38,770),1350,18)
	refresh()

func _fit() -> void:
	if page==null: return
	var factor:=maxf(.1,minf(size.x/1460,size.y/810))
	page.scale=Vector2.ONE*factor; page.position=(size-Vector2(1460,810)*factor)*.5

func _button(text:String,at:Vector2,extent:Vector2,action:Callable) -> Button:
	var button=preload("res://scripts/ui/components/solmere_button.gd").new(); button.text=text; button.variant="paper"; button.position=at; button.size=extent; button.pressed.connect(action); page.add_child(button); return button

func refresh() -> void:
	for child in rows.get_children(): rows.remove_child(child); child.queue_free()
	var items:=store.list_samples(); items.reverse()
	var count:=0
	for item in items:
		var places:Array=item.get("locations",[item.get("location","")])
		if filter.selected==1 and int(item.get("game_day",0))!=GameState.current_day: continue
		if filter.selected==2 and not places.has(GameState.current_location): continue
		var place_names:=""
		for location in places: place_names+=TravelSystem.location_name(str(location))+" "
		var category:=preload("res://scripts/town_sound/data/SoundAtlas.gd").label(str(item.get("sound_kind","pulse")))
		if not search.text.is_empty() and not (str(item.name)+place_names+category).to_lower().contains(search.text.to_lower()): continue
		var button=preload("res://scripts/ui/components/solmere_button.gd").new(); button.variant="archive"; button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.text="%s\n%s · %.1f 秒%s"%[str(item.name).left(22),TravelSystem.location_name(str(item.get("location",""))),float(item.duration)," · 原文件缺失" if bool(item.missing) else ""]
		button.custom_minimum_size=Vector2(403,77); button.clip_text=true; button.tooltip_text=str(item.name); button.pressed.connect(show_item.bind(item)); rows.add_child(button); count+=1
	status.text="%d 段可见 / %d 段收藏 · 标题可搜索；声音与画面都保存在本机。"%[count,items.size()]
	if not store.last_error.is_empty(): status.text=store.last_error
	if selected.is_empty() and not items.is_empty(): show_item(items[0])
	if items.is_empty():
		selected={}; player.stop(); player.stream=null; picture.hide(); scrub.value=0
		name_input.text=""; detail.text="还没有收藏。收好面板，听听身边的风、脚步或翻页声。"
		play.disabled=true; remove.disabled=true; rename.disabled=true

func show_item(item:Dictionary) -> void:
	player.stop(); player.stream_paused=false; selected=item; listened=false; play.text="▶ 听一听"
	name_input.text=str(item.name); rename.disabled=false; remove.disabled=false
	player.stream=store.load_audio(item); play.disabled=player.stream==null
	var places:Array=item.get("locations",[item.get("location","")]); var names:PackedStringArray=[]
	for location in places: names.append(TravelSystem.location_name(str(location)))
	detail.text="第 %d 天 · %s · %s"%[int(item.get("game_day",0))," → ".join(names),"人声补录" if str(item.get("source_mode",""))=="microphone" else "游戏声音"]
	refreshing=true; scrub.max_value=maxf(.01,float(item.duration)); scrub.value=0; refreshing=false
	if player.stream==null:
		status.text=store.last_error; picture.hide(); return
	picture.show(); picture.model=Arrangement.new(); picture.model.add_sample(item,0,0); picture.configure(player.stream,"像素",int(item.get("mv_seed",23817)))

func _play() -> void:
	if player.stream==null: return
	if player.playing and not player.stream_paused: player.stream_paused=true; play.text="▶ 接着听"
	elif player.stream_paused: player.stream_paused=false; play.text="Ⅱ 暂停"
	else: player.play(0.0 if scrub.value>=scrub.max_value-.1 else scrub.value); play.text="Ⅱ 暂停"

func _process(_delta:float) -> void:
	if player!=null and player.playing and not player.stream_paused:
		refreshing=true; scrub.value=player.get_playback_position(); refreshing=false; listened=true

func _rename() -> void:
	if selected.is_empty(): return
	if RecordingSession.rename_sample(selected,name_input.text): selected.name=name_input.text.strip_edges().left(60); refresh(); status.text="名称已保存，手账和唱片店同步更新。"
	else: status.text=RecordingSession.message

func _delete() -> void:
	if selected.is_empty(): return
	var item:=selected.duplicate(true)
	var confirm=preload("res://scripts/ui/components/confirm_sheet.gd").new()
	confirm.heading="把这段声音放入回收袋？"; confirm.description="「%s」会从收藏移走。正在作品中使用的录音会保留。"%str(item.name); confirm.confirm_text="放入回收袋"; add_child(confirm)
	confirm.accepted.connect(func():
		player.stop()
		if RecordingSession.delete_sample(item): selected={}; refresh()
		else: status.text=RecordingSession.message
		confirm.queue_free())

func _close() -> void: player.stop(); closed.emit(); queue_free()
func _unhandled_input(event:InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): _close(); get_viewport().set_input_as_handled()
