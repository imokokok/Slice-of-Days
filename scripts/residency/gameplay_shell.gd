extends Control
const PAPER = preload("res://scripts/residency/paper_overlay.gd")
var host: Control
var stage: Control
var clock_label: Label
var folder: Button
var hints: Panel
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

func _ready() -> void:
	name = "GameplayShell"
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	host = get_parent()
	stage = host.get("street") if host.get("street") != null else host.get("stage")
	# Old labels remain available to legacy refresh routines, but no longer cover the world.
	for child in host.get_children():
		if child == self or child == stage or not child is CanvasItem: continue
		if child is Label or child is Button or child is TextureRect: child.hide()
		elif child is Panel and child != host.get("room_dialogue"): child.hide()
	folder = Button.new()
	folder.position = Vector2(25,25)
	folder.size = Vector2(109,61)
	folder.text = "RP-07"
	folder.tooltip_text = "F · 居住档案"
	folder.add_theme_font_size_override("font_size",22)
	folder.add_theme_color_override("font_color",Color("495955"))
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("e7dab3",0.96)
	paper.set_corner_radius_all(3)
	folder.add_theme_stylebox_override("normal",paper)
	folder.pressed.connect(func() -> void: open_paper("dossier"))
	add_child(folder)
	clock_label = Label.new()
	clock_label.position = Vector2(1240,27)
	clock_label.size = Vector2(330,50)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock_label.add_theme_font_size_override("font_size",25)
	clock_label.add_theme_color_override("font_color",Color("fff6df"))
	clock_label.add_theme_color_override("font_shadow_color",Color("254552",0.8))
	clock_label.add_theme_constant_override("shadow_offset_x",1)
	clock_label.add_theme_constant_override("shadow_offset_y",2)
	clock_label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(clock_label)
	next_button = Button.new()
	next_button.position = Vector2(1120,78)
	next_button.size = Vector2(450,80)
	next_button.flat = true
	next_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	next_button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	next_button.add_theme_font_size_override("font_size",18)
	next_button.add_theme_color_override("font_color",Color("fff6df"))
	next_button.add_theme_color_override("font_shadow_color",Color("254552"))
	next_button.add_theme_constant_override("shadow_offset_y",2)
	next_button.pressed.connect(func() -> void: open_paper("today"))
	add_child(next_button)
	hints = Panel.new()
	hints.position = Vector2(1160,175)
	hints.size = Vector2(410,100)
	hints.mouse_filter = MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff7e8",0.9)
	style.set_corner_radius_all(4)
	hints.add_theme_stylebox_override("panel",style)
	add_child(hints)
	hint_label = RichTextLabel.new()
	hint_label.bbcode_enabled = true
	hint_label.scroll_active = false
	hint_label.position = Vector2(15,8)
	hint_label.size = Vector2(380,87)
	hint_label.add_theme_font_size_override("normal_font_size",18)
	hint_label.add_theme_color_override("default_color",Color("456a76"))
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.mouse_filter = MOUSE_FILTER_IGNORE
	hints.add_child(hint_label)
	ResidencySystem.changed.connect(_papers_changed)
	last_material_count = ResidencySystem.state().materials.size()

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
	var count := mini(4,last_material_count/4)
	for i in count: draw_line(Vector2(35+i*2,21-i*3),Vector2(117+i*2,21-i*3),Color("fbefcd"),3)

func _blocked() -> bool:
	return is_instance_valid(host.get("conversation")) or not get_tree().get_nodes_in_group("meta_dialogue").is_empty() or MetaExperience.modal_open() or SceneRouter.transitioning or is_instance_valid(host.get("pocket_panel")) or (host.get("event_overlay") != null and host.event_overlay.visible) or (host.get("room_dialogue") != null and host.room_dialogue.visible)

func blocks_walking() -> bool:
	if is_instance_valid(tool) and tool.get("focus_active") != null: return focus_opening or bool(tool.focus_active)
	return focus_opening or (is_instance_valid(tool) and not tool.is_in_group("mobile_recorder"))

func finish_recording_for_exit() -> bool:
	if is_instance_valid(tool) and tool.is_in_group("mobile_recorder"):
		return tool.finish_for_exit()
	return true

func _process(delta: float) -> void:
	clock_label.text = "DAY %02d   %s" % [GameState.current_day,GameState.clock_text()]
	guidance_tick -= delta
	if guidance_tick <= 0:
		guidance_tick = 1.0
		next_button.text = "NEXT  "+str(GuidanceSystem.next_step().text)+"\nT · 今日"
	next_button.visible = not _blocked() and not is_instance_valid(tool)
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
		for line in str(context.text).split("\n"):
			var parts := str(line).split("  ",true,1)
			lines.append("[bgcolor=#a8cedb][color=#354c56] "+str(parts[0])+" [/color][/bgcolor] "+(str(parts[1]) if parts.size()>1 else ""))
		hint_label.text = "\n".join(lines)
		hint_debug.context = id
		hint_debug.actions = str(context.text).split("\n")
	hint_age += delta
	hints.visible = not _blocked() and not is_instance_valid(tool)
	hints.modulate.a = minf(hint_age/0.2,1.0) if hint_age < 2.7 else clampf(1.0-(hint_age-2.7)/0.35,0,1)
	hint_debug.fade = "in" if hint_age < .2 else "hold" if hint_age < 2.7 else "out" if hint_age < 3.05 else "hidden"

func _context() -> Dictionary:
	var commitment := GameState.next_commitment()
	if not commitment.is_empty() and not bool(commitment.get("auto_advance",false)):
		var due := int(commitment.get("return_by",commitment.get("start",0)))
		var travel := WorldGraph.walk_minutes(GameState.current_location,str(commitment.get("location","dorm")))+5
		if due-GameState.current_minute <= travel and due+10 >= GameState.current_minute and GameState.current_location != str(commitment.get("location","dorm")):
			return {"id":"work_"+str(commitment.get("id","")),"text":"Tab  %02d:%02d 前回家工作\nH  随身物品" % [due/60,due%60]}
	var special := _special()
	if not special.is_empty(): return {"id":special,"text":"E  "+str({"counter":"资料领取 / 提交","organize":"整理桌上的材料","proofs":"领取工作证明","residence":"居住确认"}.get(special,special))+"\nF  居住档案"}
	var near: Dictionary = stage.nearest()
	if not near.is_empty():
		var text := "E  "+str(near.get("label","互动"))
		if str(near.get("kind","")) in ["person","npc","resident","shopkeeper"]: text = "E  聊一会 · %d 分钟 · %s结束\n1  问点事 · %d 分钟" % [int(MetaExperience.catalog.timing.chat_minutes),GuidanceSystem.time_text(GameState.current_minute+int(MetaExperience.catalog.timing.chat_minutes)),int(MetaExperience.catalog.timing.ask_minutes)]
		return {"id":str(near),"text":text}
	return {"id":"walk_"+last_location,"text":"A / D  走走\nTab  去社区中心" if not ResidencySystem.state().packet else "A / D  走走\nTab  地图    T  今日"}

func _special() -> String:
	if not stage.indoor: return ""
	var space := SceneRouter.active_space_id
	if space == "print_studio" and absf(stage.player_x-450)<95: return "counter"
	if space == ("home_a" if GameState.current_role == "A" else "home_b"):
		if absf(stage.player_x-460)<95: return "organize"
		if absf(stage.player_x-680)<70: return "residence"
	if space in ["restaurant","letter_office","record_shop","home_b"] and absf(stage.player_x-1250)<90: return "proofs"
	return ""

func _service_points() -> void:
	if not stage.indoor: return
	var points: Array = []
	var space := SceneRouter.active_space_id
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
	if not event is InputEventKey or not event.pressed or event.echo or _blocked() or is_instance_valid(tool) or focus_opening: return
	if get_viewport().gui_get_focus_owner() is TextEdit or get_viewport().gui_get_focus_owner() is LineEdit: return
	var key: int = event.physical_keycode
	var modes := {KEY_TAB:"map",KEY_T:"today",KEY_G:"gallery",KEY_B:"fieldbook",KEY_F:"dossier",KEY_H:"home",KEY_J:"notebook",KEY_ESCAPE:"pause"}
	if modes.has(key): open_paper(str(modes[key]))
	elif key == KEY_C: open_tool("camera")
	elif key == KEY_R: open_tool("recorder")
	elif key == KEY_E and not _special().is_empty():
		var special := _special()
		if special == "residence": GameState.message_posted.emit(ResidencySystem.residence_proof()); open_paper("fieldbook")
		else: open_paper(special)
	else: return
	get_viewport().set_input_as_handled()

func open_paper(mode: String) -> void:
	if is_instance_valid(overlay) or _blocked() or is_instance_valid(tool): return
	var paper := PAPER.new()
	paper.mode = mode
	if mode == "dossier":
		paper.tab = "days"
		paper.show_dossier_reference = true
	paper.tool_requested.connect(func(request: String) -> void:
		call_deferred("open_tool",request))
	overlay = paper
	add_child(paper)

func open_tool(mode: String) -> void:
	if is_instance_valid(tool) or _blocked(): return
	if mode == "recorder":
		tool = load("res://scripts/residency/recorder_lite.gd").new()
		add_child(tool)
		return
	if not FilmSystem.camera_available(): return
	tool = load("res://scripts/town_sound/PocketCamera.gd").new()
	tool.source_provider = _camera_source
	tool.context = {"location":GameState.current_location,"title":TravelSystem.location_name(GameState.current_location),"day":GameState.current_day,"role":GameState.current_role,"game_minute":GameState.current_minute}
	add_child(tool)

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
