extends Control
const PanelArt=preload("res://scripts/folio_panel.gd")
const Item=preload("res://scripts/folio_item.gd")
const DeskObject=preload("res://scripts/desk_object.gd")
const Tool=preload("res://scripts/journal_tool.gd")
var g
var shelf: Control
var kit: Control
var drag_id: int=-1
var drag_origin:=Vector2.ZERO
var drag_at:=Vector2.ZERO
var dragging_item:=false
var handle_side:=""
var handle_was_open:=false
var handle_fraction:=0.0
var preview_id: int=-1
var overlay: Control
var pigment_level: Label
var blind_drag:=false
var blind_start:=0.0
var blind_origin:=0.0
var writing: TextEdit
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;size=Vector2(1440,900)
	shelf=PanelArt.new();shelf.size=Vector2(366,626);shelf.position=Vector2(38 if g.shelf_open else -380,142);add_child(shelf)
	shelf.g=g;shelf.mouse_filter=Control.MOUSE_FILTER_IGNORE
	kit=PanelArt.new();kit.size=Vector2(360,626);kit.position=Vector2(1039 if g.tools_open else 1454,142);add_child(kit)
	build_shelf();build_kit()
	# Real objects occupy the sides; all remain clear of the A4 writing area.
	object("folio","素材夹" if g.L.language=="zh" else "Materials",Rect2(84,278,245,278),func():toggle("shelf"))
	object("tools","文具" if g.L.language=="zh" else "Tools",Rect2(1110,358,209,247),func():toggle("tools"))
	object("pen","写信" if g.L.language=="zh" else "Write",Rect2(946,423,78,229),func():g.set_tool("write"))
	var mission:=object("envelope","来信委托" if g.L.language=="zh" else "Your request",Rect2(90,179,212,89),g.open_commission);mission.visible=g.letter_mode=="npc"
	var history:=object("notebook","对话记录" if g.L.language=="zh" else "Conversation",Rect2(1117,187,208,150),g.open_commission_history);history.visible=g.letter_mode=="npc"
	object("tray","海上来信" if g.L.language=="zh" else "Letters from the sea",Rect2(89,641,243,137),g.open_bottles)
	object("envelope","折好寄出" if g.L.language=="zh" else "Fold & post",Rect2(1102,679,228,112),g.complete_letter)
	if g.tool=="write":build_writing()
	for side in ["shelf","tools"]:
		var h:=Item.new();h.name="Handle_"+side;h.desk=self;h.handle=side;h.position=Vector2(391 if side=="shelf" else 997,270);h.size=Vector2(50,58);h.text="▤" if side=="shelf" else "✎";h.tooltip_text=t("拉出素材夹" if side=="shelf" else "拉出工具盒");style(h);add_child(h)
	var cord:=Control.new();cord.name="BlindCord";cord.position=Vector2(1009,12);cord.size=Vector2(34,131);cord.mouse_default_cursor_shape=Control.CURSOR_VSIZE;cord.tooltip_text="向下拉绳升起百叶窗，向上推绳放下" if g.L.language=="zh" else "Pull down to raise the blind; move up to lower it";add_child(cord)
	cord.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
			blind_drag=true;blind_start=g.blinds_open;blind_origin=get_global_mouse_position().y;accept_event())
	button("English" if g.L.language=="zh" else "Chinese",Rect2(1218,35,150,32),g.switch_language)
	button("声音" if not g.audio.muted else "静音",Rect2(1095,35,100,32),func():g.audio.toggle();g.build_ui())
	g.status_label=label(g.hint,Rect2(449,826,565,44),14);g.status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label("海盐书信事务所",Rect2(51,33,358,44),25)
	label("给某个人的一封信" if g.L.language=="zh" else "A letter for someone",Rect2(53,79,358,28),14)
	# Objects sit beneath the opened drawers, without invisible click areas above them.
	move_child(shelf,get_child_count()-1);move_child(kit,get_child_count()-1)
func object(kind: String, title: String, rect: Rect2, action: Callable) -> Button:
	var b:=DeskObject.new();b.kind=kind;b.caption=title;b.font=g.font;b.name="Object_"+kind;b.tooltip_text=title;b.position=rect.position;b.size=rect.size;b.pressed.connect(action);add_child(b);return b

func build_writing() -> void:
	writing=TextEdit.new();writing.name="LetterWriting";writing.position=g.LETTER.position+Vector2(28,35);writing.size=g.LETTER.size-Vector2(56,70)
	writing.text=g.letter_text;writing.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;writing.add_theme_font_override("font",g.font);writing.add_theme_font_size_override("font_size",19);writing.add_theme_constant_override("line_spacing",5)
	writing.add_theme_color_override("font_color",Color("465951"));writing.add_theme_color_override("caret_color",Color("465951"))
	writing.placeholder_text="亲爱的＿＿：\n\n想对你说的话，慢慢写在这里。\n\n\n你的＿＿" if g.L.language=="zh" else "Dear …,\n\nTake your time. What would you like to tell them?\n\n\nWith love, …"
	for state in ["normal","focus","read_only"]:writing.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	writing.caret_blink=true;writing.caret_blink_interval=0.65
	add_child(writing)
	if not g.conversation_open:writing.grab_focus()
	writing.focus_exited.connect(func():g.save_game())
	writing.text_changed.connect(func():g.letter_text=writing.text;g.letter_text_node.text=writing.text;g.audio.play("TYPE_KEY",0.28);g.queue_redraw())
func t(text: String) -> String:return g.L.t(text)
func style(b: Button, active: bool=false) -> void:
	b.add_theme_font_override("font",g.font);b.add_theme_font_size_override("font_size",14);b.add_theme_color_override("font_color",Color("46685d"));b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus"]:
		var skin:=StyleBoxFlat.new();skin.bg_color=Color("c1c6af") if active or state!="normal" else Color("ebddbf");skin.border_color=Color("ad9e83");skin.set_border_width_all(1);skin.set_corner_radius_all(4);skin.set_content_margin_all(5);b.add_theme_stylebox_override(state,skin)
func button(text: String, rect: Rect2, action: Callable, active: bool=false, parent: Control=self) -> Button:
	var b:=Tool.new();b.text=t(text);b.position=rect.position;b.size=rect.size;style(b,active);b.clip_text=true;b.pressed.connect(action);parent.add_child(b);b.size=rect.size;return b
func label(text: String, rect: Rect2, font_size: int=16, parent: Control=self) -> Label:
	var l:=Label.new();l.text=t(text);l.position=rect.position;l.size=rect.size;l.clip_text=true;l.mouse_filter=Control.MOUSE_FILTER_IGNORE;l.add_theme_font_override("font",g.font);l.add_theme_font_size_override("font_size",font_size);l.add_theme_color_override("font_color",Color("4c5d4e"));parent.add_child(l);return l
func build_shelf() -> void:
	label("素材夹",Rect2(24,20,260,31),22,shelf)
	button("‹",Rect2(303,19,39,34),func():toggle("shelf"),false,shelf)
	var groups: Array=["图案","纸张","文字","票据","乐谱","广告","字母","画作","照片","客户"]
	for i in groups.size():
		var group: String=groups[i]
		button(group,Rect2(25+(i%5)*65,63+(i/5)*36,60,31),func():change_book_group(group),g.drawer_group==group,shelf)
	if g.source_preview_id>=0:
		preview_id=g.source_preview_id
		shelf.preview_id=preview_id
		label(g.materials[preview_id].title,Rect2(26,151,310,28),16,shelf)
		# The source is rendered in the world layer, aligned with this cut window.
		label("在素材上拖动裁剪，或用水粉笔做旧",Rect2(27,422,310,42),13,shelf)
		for i in 3:
			var id: String=["rect","free","brush"][i]
			button(["方框裁剪","自由裁剪","水粉笔"][i],Rect2(22+i*110,478,103,43),func():
				if id=="brush":g.paint.scope="material";g.tools_open=true
				g.set_tool(id),g.tool==id,shelf)
		button("拿取整张",Rect2(23,535,150,40),func():g.take_material_whole(preview_id,Vector2(710,400)),false,shelf)
		button("返回素材夹",Rect2(182,535,160,40),func():g.source_preview_id=-1;g.build_ui(),false,shelf)
		var preview_ids: Array=group_material_ids()
		var previous:=button("‹",Rect2(25,585,47,30),func():turn_preview(-1),false,shelf);previous.name="PreviewPrevious";previous.disabled=preview_ids.size()<2
		var counter:=label("%d / %d" % [preview_ids.find(preview_id)+1,preview_ids.size()],Rect2(88,586,192,27),15,shelf);counter.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var next:=button("›",Rect2(294,585,47,30),func():turn_preview(1),false,shelf);next.name="PreviewNext";next.disabled=preview_ids.size()<2
		return
	var ids: Array=group_material_ids()
	var pages:=maxi(1,ceili(ids.size()/12.0));g.drawer_page=posmod(g.drawer_page,pages)
	for n in mini(12,maxi(0,ids.size()-g.drawer_page*12)):
		var id: int=ids[g.drawer_page*12+n]
		var card:=Item.new();card.name="Material_"+str(id);card.desk=self;card.material_id=id;card.position=Vector2(24+n%3*107,156+n/3*92);card.size=Vector2(99,83);card.icon=g.get_material_texture(id);card.expand_icon=true;card.add_theme_constant_override("icon_max_width",90);card.tooltip_text=g.materials[id].title;style(card);var blank:=StyleBoxEmpty.new();card.add_theme_stylebox_override("normal",blank);shelf.add_child(card)
	var prev:=button("‹",Rect2(25,544,47,36),func():turn_book_page(-1),false,shelf);prev.name="BookPrevious";prev.disabled=pages<2
	label("%d / %d · %d" % [g.drawer_page+1,pages,ids.size()],Rect2(88,548,192,27),15,shelf)
	var next:=button("›",Rect2(294,544,47,36),func():turn_book_page(1),false,shelf);next.name="BookNext";next.disabled=pages<2
	label("拖到信纸 · 点击可裁剪或上色",Rect2(24,590,321,24),12,shelf)
func group_material_ids() -> Array:
	var ids: Array=[]
	for i in g.materials.size():
		if g.drawer_group=="客户":
			if i in g.customer_material_ids():ids.append(i)
		elif g.materials[i].kind==g.MATERIAL_TYPES.get(g.drawer_group,""):ids.append(i)
	return ids
func turn_preview(direction: int) -> void:
	var ids: Array=group_material_ids()
	if ids.size()<2:return
	var old_leaf:=capture_leaf()
	var index: int=posmod(ids.find(g.source_preview_id)+direction,ids.size())
	g.source_preview_id=ids[index];g.drawer_page=index/12
	g.cutting_source=-1;g.path.clear()
	finish_book_turn(old_leaf,direction)
func capture_leaf() -> ImageTexture:
	var image:=get_viewport().get_texture().get_image()
	# The captured viewport may be scaled by window size; normalize to game coordinates.
	if image.get_size()!=Vector2i(1440,900):image.resize(1440,900,Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(image.get_region(Rect2i(shelf.global_position+Vector2(25,140),Vector2i(317,441))))
func finish_book_turn(old_leaf: ImageTexture, direction: int) -> void:
	var game=g
	game.audio.play("PAGE_TURN",0.65);game.build_ui()
	var leaf=preload("res://scripts/book_turn.gd").new();leaf.name="TurningLeaf";leaf.leaf=old_leaf;leaf.direction=direction;leaf.position=Vector2(25,140);leaf.size=Vector2(317,441)
	game.desk.shelf.add_child(leaf)
func turn_book_page(direction: int) -> void:
	var old_leaf:=capture_leaf()
	g.drawer_page+=direction
	finish_book_turn(old_leaf,direction)
func change_book_group(group: String) -> void:
	if g.drawer_group==group:return
	var old_leaf:=capture_leaf()
	g.drawer_group=group;g.drawer_page=0;g.source_preview_id=-1
	finish_book_turn(old_leaf,1)
func build_kit() -> void:
	label("文具盒",Rect2(25,20,250,33),22,kit)
	button("›",Rect2(303,19,37,34),func():toggle("tools"),false,kit)
	var ids: Array=["move","rect","free","tape","pen","brush","glue","write"]
	var names: Array=["移动","方框裁剪","自由裁剪","胶带","涂鸦笔","水粉笔","胶棒","写信" if g.L.language=="zh" else "Write"]
	for i in ids.size():
		var id: String=ids[i]
		var b:=button(names[i],Rect2(23+i%4*81,64+i/4*70,74,63),func():g.set_tool(id),g.tool==id,kit);b.tool_id=id;b.add_theme_font_size_override("font_size",11)
		for state in ["normal","hover","pressed","focus"]:b.get_theme_stylebox(state).content_margin_top=34
		b.size=Vector2(74,63)
	if g.tool=="pen":
		label("涂鸦笔",Rect2(26,224,300,29),18,kit)
		for i in 4:
			var ink: Color=[Color("40566b"),Color("915942"),Color("4b6354"),Color("443a32")][i]
			var swatch:=button("●",Rect2(27+i*81,268,70,43),func():g.pen_color=ink;g.build_ui(),g.pen_color==ink,kit);swatch.add_theme_color_override("font_color",ink)
		label("在信纸上按住鼠标涂鸦",Rect2(28,330,300,80),15,kit)
	elif g.tool=="tape":
		for i in 8:
			var index: int=i;var b:=button("",Rect2(29,224+i*38,304,30),func():g.tape_style=index;g.build_ui(),g.tape_style==i,kit);b.sample_style=i
	elif g.tool=="brush":
		label("先蘸颜料，再落笔",Rect2(26,214,307,31),18,kit)
		for i in g.paint.COLORS.size():
			var index: int=i;var b:=button("",Rect2(27+i%4*81,250+i/4*52,70,43),func():g.paint.dip(index);g.build_ui(),g.paint.color_index==i,kit);b.pigment_color=g.paint.COLORS[i];b.show_pigment=true
		button("整页涂色",Rect2(25,375,145,36),func():g.paint.scope="page";g.build_ui(),g.paint.scope=="page",kit)
		button("只涂素材",Rect2(182,375,151,36),func():g.paint.scope="material";g.build_ui(),g.paint.scope=="material",kit)
		for i in 3:
			var radius: float=[8.0,18.0,32.0][i];button(["细笔","中笔","宽笔"][i],Rect2(26+i*105,430,97,34),func():g.paint.radius=radius;g.build_ui(),g.paint.radius==radius,kit)
		button("清水晕染" if not g.paint.dilute else "浓颜料",Rect2(25,484,307,37),func():g.paint.dilute=not g.paint.dilute;g.build_ui(),false,kit)
		button("撤回这一笔",Rect2(25,535,307,37),func():g.paint.undo(),false,kit)
		pigment_level=label(t("余量")+" %d%%" % int(g.paint.load_amount*100),Rect2(28,589,300,24),13,kit)
	elif g.tool in ["move","glue"] and is_instance_valid(g.selected):
		label("素材调整" if g.L.language=="zh" else "Arrange material",Rect2(26,224,300,29),18,kit)
		button("−",Rect2(25,270,145,40),func():g.transform_selected(1.0/1.12,0),false,kit)
		button("+",Rect2(182,270,151,40),func():g.transform_selected(1.12,0),false,kit)
		button("↶",Rect2(25,324,145,40),func():g.transform_selected(1,-PI/12),false,kit)
		button("↷",Rect2(182,324,151,40),func():g.transform_selected(1,PI/12),false,kit)
		if g.selected.source_id>=0:
			var face_text: String=("揭起并翻背面" if g.L.language=="zh" else "Peel and turn over") if g.selected.is_glued else (("翻回正面放下" if g.L.language=="zh" else "Turn face up and place") if g.selected.back_visible else ("翻到背面涂胶" if g.L.language=="zh" else "Turn over to glue"))
			button(face_text,Rect2(25,387,307,44),g.turn_selected,false,kit)
		var help: String="滚轮缩放 · Q / E 旋转\n先翻到背面刷胶，再翻回正面固定。\n已粘好的素材需先揭起。" if g.L.language=="zh" else "Wheel to resize · Q / E to rotate\nTurn over, brush glue on the back, then place face up. Peel attached pieces before adjusting."
		var note:=label(help,Rect2(27,455,301,115),15,kit);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		button("收起选择" if g.L.language=="zh" else "Deselect",Rect2(25,579,307,35),func():g.select(null);g.build_ui(),false,kit)
	else:
		label("信纸",Rect2(26,224,300,29),18,kit)
		for i in g.LetterPaper.NAMES.size():
			var index: int=i;var sample:=button("",Rect2(25+i%4*80,268+i/4*49,70,40),func():g.choose_letter_paper(index),g.letter_paper_style==i,kit);sample.paper_style_index=i;sample.tooltip_text=t(g.LetterPaper.NAMES[i]);sample.name="LetterPaper_"+str(i)
		label(g.LetterPaper.NAMES[g.letter_paper_style],Rect2(27,592,300,26),14,kit)
func begin_material_drag(id: int, point: Vector2) -> void:drag_id=id;drag_origin=point;drag_at=point;dragging_item=false
func begin_handle_drag(side: String, point: Vector2) -> void:handle_side=side;drag_origin=point;handle_was_open=g.shelf_open if side=="shelf" else g.tools_open
func toggle(side: String) -> void:
	var node: Control=shelf if side=="shelf" else kit
	if side=="shelf":g.shelf_open=not g.shelf_open
	else:g.tools_open=not g.tools_open
	var target: float=(38 if g.shelf_open else -380) if side=="shelf" else (1039 if g.tools_open else 1454)
	create_tween().tween_property(node,"position:x",target,0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT);g.audio.play("PAPER_MOVE")
func _input(event: InputEvent) -> void:
	if g.conversation_open:return
	var input_viewport:=get_viewport()
	if blind_drag:
		if event is InputEventMouseMotion:g.blinds_open=clampf(blind_start+(event.position.y-blind_origin)/100.0,0,1);g.queue_redraw();input_viewport.set_input_as_handled();return
		if event is InputEventMouseButton and not event.pressed:blind_drag=false;g.audio.play("PAPER_MOVE",0.25);g.save_game();input_viewport.set_input_as_handled();return
	if event is InputEventMouseMotion:
		drag_at=event.position
		if drag_id>=0 and drag_at.distance_to(drag_origin)>9:dragging_item=true;queue_redraw();get_viewport().set_input_as_handled()
		if not handle_side.is_empty():
			var direction: float=1.0 if handle_side=="shelf" else -1.0
			if handle_was_open:direction*=-1
			var distance: float=(event.position.x-drag_origin.x)*direction;handle_fraction=clampf(distance/200,0,1)
			var node: Control=shelf if handle_side=="shelf" else kit
			var closed: float=-380 if handle_side=="shelf" else 1454;var opened: float=38 if handle_side=="shelf" else 1039
			node.position.x=lerpf(opened if handle_was_open else closed,closed if handle_was_open else opened,handle_fraction);get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		if not handle_side.is_empty():
			var side:=handle_side
			var click: bool=event.position.distance_to(drag_origin)<9
			var wanted: bool=not handle_was_open if click or handle_fraction>=0.25 else handle_was_open
			if side=="shelf":g.shelf_open=not wanted
			else:g.tools_open=not wanted
			handle_side="";handle_fraction=0;toggle(side);input_viewport.set_input_as_handled()
		if drag_id>=0:
			var id:=drag_id;drag_id=-1
			var moved: bool=dragging_item or event.position.distance_to(drag_origin)>9
			if moved and g.LETTER.has_point(event.position):g.take_material_whole(id,event.position)
			elif not moved:g.source_preview_id=id;g.build_ui()
			dragging_item=false;queue_redraw();input_viewport.set_input_as_handled()
func _process(_dt: float) -> void:
	for child in get_children():
		if child is DeskObject:
			var covered:bool=(child.position.x<400 and g.shelf_open) or (child.position.x>1040 and g.tools_open)
			child.visible=not covered and not (child.kind=="notebook" and g.letter_mode!="npc") and not (child.kind=="envelope" and child.position.x<400 and g.letter_mode!="npc")
	if is_instance_valid(pigment_level):pigment_level.text=t("余量")+" %d%%" % int(g.paint.load_amount*100)
	if preview_id>=0:
		g.sources[preview_id]=Rect2(shelf.position+Vector2(33,181),Vector2(300,240));g.queue_redraw()
		shelf.queue_redraw()
func _draw() -> void:
	if dragging_item and drag_id>=0:draw_texture_rect(g.get_material_texture(drag_id),Rect2(drag_at-Vector2(90,72),Vector2(180,144)),false,Color(1,1,1,0.8))
