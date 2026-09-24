extends Control
const PAPER = preload("res://scripts/residency/living_objects.gd")
const HUD = preload("res://scripts/ui/components/interface_palette.gd")
const PROMPT_OUTLINE := Color("173c5d")
var host: Control
var stage: Control
var clock_label: Label
var folder: Button
var hints: Control
var hint_label: RichTextLabel
var overlay: Control
var tool: Control
var context_id := ""
var hint_age := 0.0
var last_location := ""
var hint_debug: Dictionary = {"context":"","actions":[],"fade":"entry"}
var focus_opening := false
var last_material_count := 0
var flash_tween: Tween
var was_walking := false
var next_button: Button
var guidance_tick := 0.0
var last_time_period := ""
var time_notice_age := 8.0

var switch_button: Button
var clock_back: Panel
var pocket_objects: Array[Button] = []

func _ready() -> void:
	name = "GameplayShell"
	add_child(preload("res://scripts/ui/components/guidance_toasts.gd").new())
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	host = get_parent()
	stage = host.get("street") if host.get("street") != null else host.get("stage")
	var hud_font := SystemFont.new()
	hud_font.font_names = PackedStringArray(["Hiragino Sans GB", "PingFang SC", "Noto Sans CJK SC", "Microsoft YaHei UI", "Microsoft YaHei", "sans-serif"])
	hud_font.allow_system_fallback = true
	# Old labels remain available to legacy refresh routines, but no longer cover the world.
	for child in host.get_children():
		if child == self or child == stage or not child is CanvasItem: continue
		if child is Label or child is Button or child is TextureRect: child.hide()
		elif child is Panel and child != host.get("room_dialogue"): child.hide()
	_build_pocket_objects()
	clock_back=Panel.new(); clock_back.name="ClockBackdrop"; clock_back.add_to_group("solid_hud"); clock_back.position=Vector2(30,23); clock_back.size=Vector2(215,47); clock_back.mouse_filter=MOUSE_FILTER_IGNORE
	var clock_face := HUD.face(HUD.SPEECH,7,0); clock_face.set_border_width_all(1); clock_face.border_color=HUD.PAPER_EDGE; clock_back.add_theme_stylebox_override("panel",clock_face); add_child(clock_back)
	clock_label = Label.new()
	clock_label.position = Vector2(42,30)
	clock_label.size = Vector2(330,32)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	clock_label.add_theme_font_override("font",hud_font)
	clock_label.add_theme_font_size_override("font_size",18)
	clock_label.add_theme_color_override("font_color",HUD.SPEECH_INK)
	clock_label.add_theme_color_override("font_outline_color",PROMPT_OUTLINE)
	clock_label.add_theme_constant_override("outline_size",0)
	clock_label.add_theme_color_override("font_shadow_color",Color("254552",0.8))
	clock_label.add_theme_constant_override("shadow_offset_x",0)
	clock_label.add_theme_constant_override("shadow_offset_y",0)
	clock_label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(clock_label)
	next_button = preload("res://scripts/ui/components/direction_card.gd").new()
	next_button.position = Vector2(1155,35)
	next_button.size = Vector2(395,110)
	next_button.flat = false
	next_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	next_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	next_button.add_theme_font_override("font",hud_font)
	next_button.add_theme_font_size_override("font_size",20)
	next_button.add_theme_color_override("font_color",Color("fff6df"))
	next_button.add_theme_color_override("font_outline_color",PROMPT_OUTLINE)
	next_button.add_theme_constant_override("outline_size",0)
	next_button.add_theme_color_override("font_shadow_color",Color("254552"))
	next_button.add_theme_constant_override("shadow_offset_y",0)
	next_button.pressed.connect(_open_active_direction)
	GuidanceSystem.updated.connect(_update_active_direction)
	add_child(next_button)
	# The readable prompt is also the mouse/controller route to the same action.
	hints = preload("res://scripts/ui/components/solmere_button.gd").new()
	hints.variant = "paper"
	hints.name = "ContextHints"
	hints.position = Vector2(480,825)
	hints.size = Vector2(640,49)
	hints.pressed.connect(_activate_context)
	add_child(hints)
	hint_label = RichTextLabel.new()
	hint_label.bbcode_enabled = true
	hint_label.scroll_active = false
	hint_label.position = Vector2(18,10)
	hint_label.size = Vector2(604,32)
	hint_label.add_theme_font_override("normal_font",hud_font)
	hint_label.add_theme_font_size_override("normal_font_size",20)
	hint_label.add_theme_color_override("default_color",HUD.SPEECH_INK)
	hint_label.add_theme_color_override("default_outline_color",PROMPT_OUTLINE)
	hint_label.add_theme_constant_override("outline_size",0)
	hint_label.add_theme_color_override("font_shadow_color",Color("203945",0.9))
	hint_label.add_theme_constant_override("shadow_offset_x",0)
	hint_label.add_theme_constant_override("shadow_offset_y",0)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.mouse_filter = MOUSE_FILTER_IGNORE
	hints.add_child(hint_label)
	ResidencySystem.changed.connect(_papers_changed)
	last_material_count = ResidencySystem.state().materials.size()
	switch_button=preload("res://scripts/ui/components/solmere_button.gd").new()
	switch_button.variant="outlined"; switch_button.position=Vector2(265,23); switch_button.size=Vector2(190,47)
	switch_button.pressed.connect(func(): open_paper("day_schedule"))
	add_child(switch_button)

func _build_pocket_objects() -> void:
	var titles := ["随身本","档案","相机","录音机","背包","地图"]
	var actions := ["open_notebook","open_archive","open_camera","open_recorder","open_bag","open_map"]
	var modes := ["notebook","dossier","camera","recorder","bag","map"]
	for i in 6:
		var item=preload("res://scripts/ui/components/pocket_object_button.gd").new()
		item.name="Pocket_"+modes[i]; item.title=titles[i]; item.action=actions[i]; item.object_index=i
		item.size=Vector2(100,100) if i<4 else Vector2(86,88)
		item.pressed.connect(open_tool.bind(modes[i]) if i in [2,3] else open_paper.bind(modes[i]))
		pocket_objects.append(item); add_child(item)
	folder=pocket_objects[1]

func _papers_changed() -> void:
	var count := int(ResidencySystem.state().materials.size())
	if count <= last_material_count: return
	last_material_count = count
	if flash_tween: flash_tween.kill()
	if not SettingsSystem.reduced_motion():
		folder.pivot_offset = folder.size*0.5
		flash_tween = create_tween()
		flash_tween.tween_property(folder,"rotation",-0.045,0.13)
		flash_tween.tween_property(folder,"rotation",0.035,0.13)
		flash_tween.tween_property(folder,"rotation",0,0.18)
	queue_redraw()

func _draw() -> void:
	var count := 0
	for i in count: draw_line(Vector2(35+i*2,21-i*3),Vector2(117+i*2,21-i*3),Color("fbefcd"),3)

func _blocked() -> bool:
	return is_instance_valid(host.get("conversation")) or not get_tree().get_nodes_in_group("meta_dialogue").is_empty() or MetaExperience.modal_open() or SceneRouter.transitioning or is_instance_valid(host.get("pocket_panel")) or (host.get("event_overlay") != null and host.event_overlay.visible) or (host.get("room_dialogue") != null and host.room_dialogue.visible)

func blocks_walking() -> bool:
	if not bool(UIStateSystem.policy().move): return true
	if is_instance_valid(tool) and tool.get("focus_active") != null: return focus_opening or bool(tool.focus_active)
	return focus_opening or (is_instance_valid(tool) and not tool.is_in_group("mobile_recorder"))

func finish_recording_for_exit() -> bool:
	if is_instance_valid(tool) and tool.is_in_group("mobile_recorder"):
		return tool.finish_for_exit()
	return true

func _process(delta: float) -> void:
	switch_button.visible=CharacterSystem.switch_unlocked()
	switch_button.disabled=_blocked() or is_instance_valid(overlay) or is_instance_valid(tool)
	switch_button.text=LocalizationSystem.text_with_values("日程与视角 · %s", [GameState.current_role])
	var minute := GameState.current_minute
	var period := "Morning" if minute < 720 else "Afternoon" if minute < 960 else "Late Afternoon" if minute < 1140 else "Evening"
	var period_key := str(GameState.current_day)+period
	if last_time_period != period_key:
		last_time_period=period_key; time_notice_age=0
		clock_label.text=CoreLoopSystem.day_stamp()+"   "+GameState.clock_text()
	time_notice_age+=delta
	var clear_view := not is_instance_valid(overlay) and not is_instance_valid(tool) and not _blocked()
	for i in pocket_objects.size():
		var item := pocket_objects[i]
		item.visible=clear_view
		item.position=Vector2((size.x-400)*.5+i*100,8) if i<4 else Vector2(size.x-196+(i-4)*94,size.y-112)
		item.disabled=(i==2 and not FilmSystem.camera_available(false)) or not bool(UIStateSystem.policy().notebook)
		item.tooltip_text=item.title+" · "+SettingsSystem.binding_text(item.action)
		if i==2 and item.disabled: item.tooltip_text="先在杂货店取得相机"
	clock_label.visible=clear_view
	clock_back.visible=clear_view
	clock_label.modulate.a=1.0
	guidance_tick -= delta
	if guidance_tick <= 0:
		guidance_tick = 1.0
		clock_label.text=CoreLoopSystem.day_stamp()+"   "+GameState.clock_text()
		_update_active_direction()
	next_button.visible = clear_view and not next_button.text.is_empty()
	if last_location != GameState.current_location:
		last_location = GameState.current_location
		ResidencySystem.visit(last_location)
	if not is_instance_valid(stage): return
	_service_points()
	if blocks_walking() and not MetaExperience.modal_open() and DisplayServer.window_is_focused():
		# TownDay / InteractiveSpace own the movement gate.  Keeping this shell
		# read-only prevents a closed panel from leaving the player frozen.
		GameState.advance_world_clock(delta)
	var context := _context()
	var id := str(context.id)
	var walking := absf(stage.velocity)>1.0
	if not _blocked() and not is_instance_valid(overlay): GuidanceSystem.idle_tick(delta,walking)
	if was_walking and not walking: hint_age = 0
	was_walking = walking
	if id != context_id:
		context_id = id
		hint_age = 0
		var lines: Array[String] = []
		for line in LocalizationSystem.text(str(context.text)).split("\n"):
			var parts := str(line).split("  ",true,1)
			lines.append(str(parts[0])+" "+(str(parts[1]) if parts.size()>1 else ""))
		hint_label.text = "\n".join(lines)
		hint_debug.context = id
		hint_debug.actions = str(context.text).split("\n")
	hint_age += delta
	hints.visible = clear_view and not id.is_empty()
	hints.size.y=72 if hint_label.text.contains("\n") else 49
	hint_label.size.y=hints.size.y-18
	hints.position = Vector2((size.x-hints.size.x)*.5,size.y-hints.size.y-26)
	next_button.position=Vector2(size.x-next_button.size.x-36,35)
	hints.modulate.a = 1.0
	hint_debug.fade = "in" if hint_age < .2 else "hold" if hints.visible else "hidden"
	hints.tooltip_text = hint_label.get_parsed_text()
	hint_label.add_theme_color_override("default_color",HUD.SPEECH_INK)

func _activate_context() -> void:
	if not bool(UIStateSystem.policy().notebook) or _blocked() or is_instance_valid(overlay) or is_instance_valid(tool) or focus_opening: return
	if str(_context().id).begins_with("work_"): open_paper("map"); return
	var special := _special()
	if not special.is_empty():
		_activate_special(special); return
	if not stage.nearest_interactable().is_empty() and host.has_method("_interact"):
		host.call("_interact"); return
	if _talk_to_context(): return
	if host.has_method("_interact"): host.call("_interact")

func _talk_to_context() -> bool:
	var near: Dictionary = stage.nearest_of(["person", "npc", "resident", "shopkeeper", "invitation"])
	if near.is_empty(): return false
	if host.has_method("_talk_to_nearest"): host.call("_talk_to_nearest")
	elif host.has_method("_start_conversation") and str(near.get("kind", "")) == "person": host.call("_start_conversation", str(near.get("id", "")))
	else: return false
	return true

func _activate_special(special: String) -> void:
	if special == "residence": GameState.message_posted.emit(ResidencySystem.residence_proof()); open_paper("fieldbook")
	else: open_paper(special)

func _context() -> Dictionary:
	var commitment := GameState.next_commitment()
	if not commitment.is_empty() and not bool(commitment.get("auto_advance",false)):
		var due := int(commitment.get("return_by",commitment.get("start",0)))
		var travel := WorldGraph.walk_minutes(GameState.current_location,str(commitment.get("location","dorm")))+5
		if due-GameState.current_minute <= travel and due+10 >= GameState.current_minute and GameState.current_location != str(commitment.get("location","dorm")):
			return {"id":"work_"+str(commitment.get("id","")),"text":SettingsSystem.binding_text("open_map")+"  %02d:%02d 前回家工作" % [due/60,due%60]}
	var special := _special()
	if not special.is_empty(): return {"id":special,"text":SettingsSystem.binding_text("interact")+"  "+str({"counter":"资料领取 / 提交","organize":"整理桌上的材料","proofs":"领取工作证明","residence":"居住确认"}.get(special,special))+"\n"+SettingsSystem.binding_text("open_archive")+"  居住档案"}
	var physical: Dictionary=stage.nearest_interactable()
	if not physical.is_empty(): return {"id":str(physical),"text":SettingsSystem.binding_text("interact")+"  "+str(physical.get("label","互动"))}
	var talk_near: Dictionary = stage.nearest_of(["person", "npc", "resident", "shopkeeper", "invitation"])
	if not talk_near.is_empty():
		var tracked := GuidanceSystem.tracked_lead()
		var relevant := str(tracked.get("source",""))==str(talk_near.get("id","")) or str(tracked.get("location",""))==GameState.current_location
		return {"id":str(talk_near)+str(relevant),"text":("[color=#eed577]—[/color] " if relevant else "")+GuidanceSystem.source_name(str(talk_near.get("id","")))+"  ·  "+SettingsSystem.binding_text("talk")+" 交谈"}
	var near: Dictionary = stage.nearest()
	if not near.is_empty():
		var text := SettingsSystem.binding_text("interact")+"  "+str(near.get("label","互动"))
		return {"id":str(near),"text":text}
	return {"id":"","text":""}

func _special() -> String:
	if not stage.indoor: return ""
	var space := SceneRouter.active_space_id
	if space in ["home_a","home_b"]: return ""
	var service := ""
	var at := 0.0
	if space == "print_studio" and absf(stage.player_x-450)<95: service="counter"; at=450
	if space == ("home_a" if GameState.current_role == "A" else "home_b"):
		if absf(stage.player_x-460)<95: service="organize"; at=460
		if absf(stage.player_x-680)<70: service="residence"; at=680
	if space in ["restaurant","letter_office","record_shop","home_b"] and absf(stage.player_x-1250)<90: service="proofs"; at=1250
	# A service cannot hijack the prompt for a closer, visible room object.
	var object: Dictionary=stage.nearest_of(["object"])
	if not object.is_empty() and absf(float(object.x)-stage.player_x)<=absf(at-stage.player_x): return ""
	return service

func _service_points() -> void:
	if not stage.indoor: return
	var points: Array = []
	var space := SceneRouter.active_space_id
	if space in ["home_a","home_b"]: return
	if space == "print_studio": points.append({"x":450,"kind":"residency","label":"社区资料柜台"})
	if space == ("home_a" if GameState.current_role == "A" else "home_b"):
		points.append({"x":460,"kind":"residency","label":"整理桌上的材料"})
		points.append({"x":680,"kind":"residency","label":"居住确认"})
	if space in ["restaurant","letter_office","record_shop","home_b"]: points.append({"x":1250,"kind":"residency","label":"领取工作证明"})
	for point in points:
		if not stage.hotspots.any(func(h: Dictionary) -> bool: return str(h.get("kind","")) == "residency" and int(h.x) == int(point.x)): stage.hotspots.append(point)

func _input(event: InputEvent) -> void:
	_handle_shortcut(event)

func _unhandled_input(event: InputEvent) -> void:
	_handle_shortcut(event)

func _handle_shortcut(event: InputEvent) -> void:
	if not bool(UIStateSystem.policy().notebook): return
	if not event.is_pressed() or event.is_echo() or _blocked() or is_instance_valid(tool) or focus_opening: return
	if get_viewport().gui_get_focus_owner() is TextEdit or get_viewport().gui_get_focus_owner() is LineEdit: return
	var modes := {"open_map":"map","open_plan":"today","open_album":"gallery","open_bag":"bag","open_archive":"dossier","open_home":"home","open_notebook":"notebook","ui_cancel":"pause"}
	for action in modes:
		if event.is_action_pressed(action):
			open_paper(str(modes[action])); get_viewport().set_input_as_handled(); return
	if event.is_action_pressed("open_camera"): open_tool("camera")
	elif event.is_action_pressed("open_recorder"): open_tool("recorder")
	elif event.is_action_pressed("talk"):
		if not _talk_to_context(): return
	elif event.is_action_pressed("interact") and not _special().is_empty():
		_activate_special(_special())
	else: return
	get_viewport().set_input_as_handled()

func open_paper(mode: String) -> void:
	if is_instance_valid(overlay) or _blocked() or is_instance_valid(tool): return
	WorldSound.play_ui("paper")
	var paper := PAPER.new()
	paper.mode = mode
	if mode == "dossier":
		paper.tab = "packet"
		paper.show_dossier_reference = false
	paper.tool_requested.connect(func(request: String) -> void:
		call_deferred("open_tool",request))
	overlay = paper
	add_child(paper)

func open_tool(mode: String) -> void:
	if is_instance_valid(tool) or is_instance_valid(overlay) or _blocked(): return
	if mode == "recorder":
		tool = load("res://scripts/residency/recorder_lite.gd").new()
		add_child(tool)
		return
	if not FilmSystem.camera_available(): return
	tool = load("res://scripts/town_sound/PocketCamera.gd").new()
	tool.gallery_requested.connect(_show_camera_gallery)
	tool.source_provider = _camera_source
	tool.context = {"location":GameState.current_location,"title":TravelSystem.location_name(GameState.current_location),"day":GameState.current_day,"role":GameState.current_role,"game_minute":GameState.current_minute}
	add_child(tool)

func show_recording_library() -> void:
	if not finish_recording_for_exit(): return
	# queue_free is applied after deferred calls. Wait for actual retirement so
	# the library is not rejected as a second simultaneous tool.
	await get_tree().process_frame
	open_paper("sound_library")

func _show_camera_gallery() -> void:
	await get_tree().process_frame
	open_paper("gallery")

func _camera_source() -> Image:
	focus_opening = true
	var hidden: Array[CanvasItem] = []
	for child in host.get_children():
		if child != stage and child is CanvasItem and child.visible: hidden.append(child); child.hide()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	for child in hidden:
		if is_instance_valid(child): child.show()
	focus_opening = false
	return image

func _update_active_direction() -> void:
	if not is_instance_valid(next_button): return
	var next := GuidanceSystem.next_step()
	next_button.present(next)
func _open_active_direction() -> void:
	var next := GuidanceSystem.next_step()
	if next.is_empty(): return
	if str(next.get("action",""))=="day_schedule": open_paper("day_schedule"); return
	if str(next.get("action",""))=="evening" and GameState.current_location==CoreLoopSystem.home(): CoreLoopSystem.open_evening(); return
	open_paper("notebook")
	if is_instance_valid(overlay): overlay._guidance_action(next)
