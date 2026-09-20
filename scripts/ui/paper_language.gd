extends Node
## Shared visual grammar for controls created by every scene and extension.
const BLUE := Color("31658b")
const WHITE := Color("faf7ee")
const YELLOW := Color("eed577")
const MUTED := Color("698594")
var handwriting := SystemFont.new()

func _ready() -> void:
	handwriting.font_names=PackedStringArray(["KaiTi","Microsoft YaHei","Noto Sans CJK SC"])
	get_tree().node_added.connect(_added)

func _added(node: Node) -> void:
	if node is Control and not _context(node,["workshop.gd"]):
		# Controls may be removed before the deferred style pass runs.
		_style_id.call_deferred(node.get_instance_id())

func _style_id(instance_id: int) -> void:
	var node=instance_from_id(instance_id)
	if node is Control: _style(node)

func _context(node: Node, names: Array) -> bool:
	var at := node
	while is_instance_valid(at):
		if at.get_script()!=null:
			var path: String = at.get_script().resource_path
			for name in names:
				if path.ends_with(str(name)): return true
		at=at.get_parent()
	return false

func speech(node: Node) -> bool:
	var at := node
	while is_instance_valid(at):
		if at.is_in_group("scene_speech"): return true
		at=at.get_parent()
	return _context(node,["conversation_panel.gd","ask_panel.gd","memory_view.gd"])

func button_style(button: Button, in_scene := false) -> void:
	for state in ["normal","hover","pressed","focus","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color=Color.TRANSPARENT if state in ["normal","disabled","focus"] else Color(YELLOW,.18 if in_scene else .7)
		style.border_width_bottom=1 if state in ["hover","pressed","focus"] else 0
		style.border_color=YELLOW if in_scene else BLUE
		style.content_margin_left=10; style.content_margin_right=10
		style.content_margin_top=5; style.content_margin_bottom=5
		button.add_theme_stylebox_override(state,style)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		button.add_theme_color_override(state,WHITE if in_scene else BLUE)
	button.add_theme_color_override("font_disabled_color",Color(MUTED,.55))
	if DisplayServer.get_name()!="headless": button.add_theme_font_override("font",handwriting)
	button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	if in_scene:
		button.add_theme_color_override("font_outline_color",Color("173c5d",.9))
		button.add_theme_constant_override("outline_size",3)

func _style(node: Control) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree() or node.is_queued_for_deletion(): return
	if _context(node,["main_menu.gd","living_objects.gd","runtime_debug.gd","flowing_thought.gd","workshop.gd"]): return
	if speech(node): return
	if node is Button:
		button_style(node,speech(node))
		if node.has_meta("paper_selected") and bool(node.get_meta("paper_selected")): selected_button(node,true)
	elif node is Panel or node is PanelContainer:
		var current := node.get_theme_stylebox("panel")
		var paper := StyleBoxFlat.new()
		if current is StyleBoxFlat:
			paper=current.duplicate()
		paper.shadow_size=0; paper.shadow_offset=Vector2.ZERO
		paper.set_corner_radius_all(3); paper.set_border_width_all(1)
		paper.border_color=Color(BLUE,.32)
		paper.bg_color=WHITE
		if speech(node): paper.bg_color=Color.TRANSPARENT; paper.set_border_width_all(0)
		node.add_theme_stylebox_override("panel",paper)
		if not speech(node) and not node.has_node("PaperGrain"):
			var grain := preload("res://scripts/ui/paper_grain.gd").new()
			grain.name="PaperGrain"; node.add_child(grain)
	elif node is LineEdit or node is TextEdit:
		for state in ["normal","focus","read_only"]:
			var sheet := StyleBoxFlat.new()
			sheet.bg_color=Color(WHITE,.7); sheet.border_width_bottom=1; sheet.border_color=Color(BLUE,.35)
			node.add_theme_stylebox_override(state,sheet)
		node.add_theme_color_override("font_color",BLUE)
		node.add_theme_color_override("font_placeholder_color",MUTED)
		node.add_theme_color_override("caret_color",BLUE)
		node.add_theme_color_override("selection_color",Color(YELLOW,.65))
	elif node is Label:
		if DisplayServer.get_name()!="headless":
			node.add_theme_font_override("font",handwriting)
		var color := node.get_theme_color("font_color")
		if color.a==0: return
		if speech(node):
			node.add_theme_color_override("font_color",WHITE)
			node.add_theme_color_override("font_outline_color",Color("173c5d",.9)); node.add_theme_constant_override("outline_size",3)
		elif _has_paper_parent(node) or color.r<.75 or color.g<.75 or color.b<.75:
			node.add_theme_color_override("font_color",Color(BLUE,color.a))
	elif node is ColorRect and node.color.a<.8 and node.size.x>800 and node.size.y>400:
		node.color=Color("234d68",minf(node.color.a,.24))

func _has_paper_parent(node: Node) -> bool:
	var at := node.get_parent()
	while is_instance_valid(at):
		if at is Panel or at is PanelContainer: return true
		at=at.get_parent()
	return false

func near_actor(_stage: Node, extent: Vector2, _world_x: float = -1.0) -> Vector2:
	return Vector2((1600-extent.x)*.5,900-extent.y-28)

func selected_button(button: Button, selected: bool) -> void:
	button.set_meta("paper_selected",selected)
	button_style(button,speech(button))
	if selected:
		var face := StyleBoxFlat.new()
		face.bg_color=Color(YELLOW,.48); face.border_width_bottom=2; face.border_color=BLUE
		face.content_margin_left=10; face.content_margin_top=5; face.content_margin_bottom=5
		button.add_theme_stylebox_override("normal",face)
