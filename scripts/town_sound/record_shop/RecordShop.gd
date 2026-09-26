extends Control
const Atlas = preload("res://scripts/town_sound/data/SoundAtlas.gd")
var body: VBoxContainer
var info: Label
var modal: Control
var radio: AudioStreamPlayer
var monitor_locked:=false
var step_grid: GridContainer
var quest_grid: GridContainer
var stations: GridContainer
var samples: Array[Dictionary] = []
var records: Array[Dictionary] = []

func _ready() -> void:
	add_to_group("meta_modal")
	add_to_group("town_sound_workspace")
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme=preload("res://scripts/ui/components/interface_palette.gd").theme_for_tools()
	if GameState.current_location != "record_store": queue_free(); return
	WorldSound.lock_monitor(true)
	monitor_locked=true
	var paper := ColorRect.new(); paper.color=Color("eee7d7"); paper.mouse_filter=MOUSE_FILTER_IGNORE
	paper.set_anchors_and_offsets_preset(PRESET_FULL_RECT); add_child(paper)
	var scroll := ScrollContainer.new(); scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT); add_child(scroll)
	var margin := MarginContainer.new(); margin.size_flags_horizontal=SIZE_EXPAND_FILL
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,36)
	scroll.add_child(margin)
	body=VBoxContainer.new(); body.add_theme_constant_override("separation",18); margin.add_child(body)
	radio=AudioStreamPlayer.new(); radio.bus="Music"; radio.volume_db=-18; add_child(radio)
	resized.connect(_fit_cards)
	refresh()

func label(text: String, font_size:=20) -> Label:
	var node:=Label.new(); node.text=text; node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size",font_size); return node

func button(text: String, action: Callable) -> Button:
	var node:=preload("res://scripts/ui/components/solmere_button.gd").new()
	node.text=text; node.variant="paper"; node.custom_minimum_size.y=48; node.pressed.connect(action); return node

func refresh() -> void:
	for child in body.get_children(): body.remove_child(child); child.queue_free()
	samples=SampleStore.new().list_samples().filter(func(item:Dictionary): return not bool(item.get("missing",true)) and float(item.get("signal_peak",1))>.0001)
	records=LocalRecordLibrary.new().list_records().filter(func(item:Dictionary): return str(item.get("origin",""))!="preset")
	var header:=HBoxContainer.new(); body.add_child(header)
	var heading:=label("LOCAL RECORDS / 街角唱片店",34); heading.size_flags_horizontal=SIZE_EXPAND_FILL; header.add_child(heading)
	header.add_child(button("回到店内",func(): queue_free()))
	body.add_child(label("Xanni：先听、再收集，把路上的声音做成一张真正可以带走的唱片。",21))
	step_grid=GridContainer.new(); step_grid.add_theme_constant_override("h_separation",14); step_grid.add_theme_constant_override("v_separation",10); body.add_child(step_grid)
	for words in ["01  在路上\n录一段，收进口袋","02  坐下来\n剪掉多余，留住喜欢的","03  留个画面\n从 MV 或相册选封面","04  亲手完成\n压制、装袋，签下名字"]:
		var card:=PanelContainer.new(); card.size_flags_horizontal=SIZE_EXPAND_FILL; step_grid.add_child(card)
		card.add_theme_stylebox_override("panel",card_style()); card.add_child(label(words,18))
	stations=GridContainer.new(); stations.add_theme_constant_override("h_separation",18); stations.add_theme_constant_override("v_separation",14); body.add_child(stations)
	for item in [["collection","带来的声音","打开磁带盒，听听路上的收藏"],["desk","声音手作桌","把今天剪贴成一张唱片"],["shelf","我的唱片架","取下一张，听完它的故事"]]:
		var station=preload("res://scripts/town_sound/record_shop/ShopStation.gd").new()
		station.kind=item[0]; station.caption=item[1]; station.detail=item[2]; stations.add_child(station)
		if item[0]=="collection": station.pressed.connect(func(): open_recorder(false))
		elif item[0]=="desk": station.pressed.connect(func(): open_recorder(true))
		else: station.pressed.connect(open_shelf)
	var radio_button:=button("♫ 听听店里的唱片",toggle_radio); radio_button.size_flags_horizontal=SIZE_SHRINK_BEGIN; body.add_child(radio_button)
	info=label("已保存 %d 段声音 · 已制作 %d 张唱片。%s" % [samples.size(),records.size(),"先去街上留下一段声音，再回来剪贴。" if samples.is_empty() else "素材已够用，可以开始制作第一张。"],18); body.add_child(info)
	var gate:=GameplayModuleSystem.entry_check("sound_sampling",60)
	if not bool(gate.ok):
		body.add_child(label("制作时间："+str(gate.reason),18))
		var merge:=GameState.flexible_merge_preview()
		if not merge.is_empty():
			body.add_child(button("将私人整理从 %02d:%02d 延后到 %02d:%02d，为制作腾出时间" % [int(merge.start)/60,int(merge.start)%60,int(merge.moved_to)/60,int(merge.moved_to)%60],func():
				if GameState.combine_flexible_time(): refresh()
				else: info.text="日程未能保存，安排保持原样。"))
	body.add_child(label("店里的小委托 / 可选挑战",26))
	var grid:=GridContainer.new(); quest_grid=grid; grid.columns=2; grid.add_theme_constant_override("h_separation",20); grid.add_theme_constant_override("v_separation",14); body.add_child(grid)
	for quest in Atlas.QUESTS:
		var matching:=records.filter(func(item:Dictionary): return Atlas.meets(quest,item) and FileAccess.file_exists(str(item.get("final_audio_path",""))))
		var card:=PanelContainer.new(); card.custom_minimum_size=Vector2(280,125); card.size_flags_horizontal=SIZE_EXPAND_FILL; grid.add_child(card)
		card.add_theme_stylebox_override("panel",card_style())
		var column:=VBoxContainer.new(); card.add_child(column)
		column.add_child(label(("✓ 已验收 · " if not matching.is_empty() else "○ 待制作 · ")+str(quest.title),22))
		column.add_child(label(str(quest.brief),18))
		var kinds:=Atlas.kinds_in(samples)
		var collected:=0
		for kind in quest.required:
			if kinds.has(kind): collected+=1
		column.add_child(label("声音类型 %d / %d · 时长至少 %d 秒" % [mini(kinds.size(),int(quest.kinds)),quest.kinds,int(quest.seconds)] if quest.required.is_empty() else "目标声源 %d / %d 已收集" % [collected,quest.required.size()],17))
	body.add_child(label("声音图鉴 · 去对应地点录制并保存即可收集",23))
	var collection:=HFlowContainer.new(); collection.add_theme_constant_override("h_separation",15); body.add_child(collection)
	var found:=Atlas.kinds_in(samples)
	for kind in Atlas.KINDS:
		var entry:=label(("● " if found.has(kind) else "○ ")+Atlas.label(kind),17)
		entry.autowrap_mode=TextServer.AUTOWRAP_OFF
		entry.custom_minimum_size=Vector2(170,30)
		collection.add_child(entry)
	body.add_child(label("试听曲：Lofi Hip Hop Loop — OMF-Games / CC0 · 声源与 UI 素材：AntumDeluge、Luke.RUSTLTD、Kenney / CC0。",14))

	_fit_cards()

func _fit_cards() -> void:
	if not is_instance_valid(step_grid): return
	step_grid.columns=4 if size.x>=1360 else 2
	stations.columns=3 if size.x>=1060 else 1
	quest_grid.columns=2 if size.x>=1180 else 1
	var width:=maxf(280,(size.x-116-20*(quest_grid.columns-1))/quest_grid.columns)
	for card in quest_grid.get_children(): card.custom_minimum_size.x=width

func can_edit_here() -> bool:
	return GameState.current_location=="record_store"

func open_recorder(studio: bool, library_only := false) -> void:
	if not studio and not library_only and not CharacterSystem.owns_pocket_item("recorder"): return
	if is_instance_valid(modal): return
	if not RecordingSession.finish_for_exit(): GlobalRecorder.open_recorder(); return
	radio.stop()
	# The recorder owns the Studio lifecycle, existing autosaves and delivery rules.
	modal=load("res://scenes/town_sound/Recorder.tscn").instantiate(); modal.shop_mode=true
	modal.set_anchors_and_offsets_preset(PRESET_FULL_RECT); add_child(modal)
	WorldSound.lock_monitor(false)
	monitor_locked=false
	modal.tree_exited.connect(func():
		modal=null
		if is_inside_tree() and not is_queued_for_deletion():
			WorldSound.lock_monitor(true); monitor_locked=true; refresh())
	if studio: modal._open_studio()

func open_shelf() -> void:
	open_recorder(false,true)
	if is_instance_valid(modal): modal._open_record_shelf()

func toggle_radio() -> void:
	if radio.playing: radio.stop(); info.text="试听已停止。"; return
	radio.stream=load("res://art/town_sound_cc0/shop_lofi.ogg")
	if radio.stream != null and AudioServer.get_driver_name()!="Dummy": radio.play()
	info.text="试听：Lofi Hip Hop Loop — OMF-Games · CC0，可用于商业游戏；试听不会写入玩家录音。"

func _exit_tree() -> void:
	if monitor_locked: WorldSound.lock_monitor(false)

func card_style() -> StyleBoxTexture:
	var style:=StyleBoxTexture.new()
	style.texture=preload("res://art/town_sound_cc0/card.png")
	for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:
		style.set_texture_margin(side,6); style.set_content_margin(side,16)
	return style
