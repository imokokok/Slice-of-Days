extends CanvasLayer

signal compose_requested(parent: Dictionary)
signal closed
var client: Node
var font: Font
var root: Control
var message: Label
var letters_box: VBoxContainer
var detail_box: VBoxContainer
var address: LineEdit
var nickname: LineEdit
var debt_label: Label
var write_button: Button
var network_buttons: Array[Button] = []
var view := "ocean"
var before = null
var cursors: Array = []
var next_before = null
var active := false
var in_flight := false

func open() -> void:
	active=true
	layer=20
	root=Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color=Color("e6e0ce")
	root.add_child(background)
	var shell := VBoxContainer.new()
	shell.position=Vector2(50,30)
	shell.size=Vector2(1340,820)
	shell.add_theme_constant_override("separation",12)
	root.add_child(shell)
	var top := HBoxContainer.new()
	shell.add_child(top)
	var title:=add_label(top,"漂流瓶邮局 / 海上的回声",32)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	add_button(top,"回到桌边",func(): close(),false)
	add_label(shell,"在海里捡一封旧信，也留一封属于自己的。发出新信后，先回一封，再继续发信。",18)
	var connection:=HBoxContainer.new()
	shell.add_child(connection)
	connection.visible=client.token.is_empty()
	add_button(top,"邮局设置",func(): connection.visible=not connection.visible,false)
	address=LineEdit.new()
	address.text=client.base_url
	address.custom_minimum_size=Vector2(465,42)
	connection.add_child(address)
	nickname=LineEdit.new()
	nickname.text=client.display_name
	nickname.placeholder_text="你的署名"
	nickname.max_length=24
	nickname.custom_minimum_size=Vector2(210,42)
	connection.add_child(nickname)
	add_button(connection,"连接邮局",connect_now)
	debt_label=add_label(shell,"尚未连接。使用同一个邮局地址的玩家可以互相收信。",19)
	var tabs:=HBoxContainer.new()
	shell.add_child(tabs)
	for item in [["海上来信","ocean"],["我的漂流瓶","mine"],["收到的回复","inbox"]]:
		var kind: String=item[1]
		add_button(tabs,item[0],func(): view=kind; before=null; cursors.clear(); refresh())
	write_button=add_button(tabs,"写一封自己的信",compose_new)
	var columns:=HBoxContainer.new()
	columns.add_theme_constant_override("separation",22)
	columns.size_flags_vertical=Control.SIZE_EXPAND_FILL
	shell.add_child(columns)
	var list_scroll:=ScrollContainer.new()
	list_scroll.custom_minimum_size=Vector2(410,500)
	list_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	columns.add_child(list_scroll)
	letters_box=VBoxContainer.new()
	letters_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list_scroll.add_child(letters_box)
	var detail_scroll:=ScrollContainer.new()
	detail_scroll.custom_minimum_size=Vector2(850,500)
	detail_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	columns.add_child(detail_scroll)
	detail_box=VBoxContainer.new()
	detail_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(detail_box)
	add_label(detail_box,"连接后，选择左边的一封信。\n原信与所有回复会保留，后来的人仍然可以读到。",22)
	var paging:=HBoxContainer.new()
	shell.add_child(paging)
	add_button(paging,"上一页",func():
		if not cursors.is_empty():
			before=cursors.pop_back(); refresh())
	add_button(paging,"下一页",func():
		if next_before!=null:
			cursors.append(before); before=next_before; refresh())
	message=add_label(shell,"作品只会在你点击最终「寄出」时上传到所连接的邮局。",16)
	apply_theme(root)
	if not client.token.is_empty():
		connect_now()

func add_label(parent: Node, text: String, size: int = 20) -> Label:
	var label:=Label.new()
	label.text=text
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("354a43"))
	parent.add_child(label)
	return label

func add_button(parent: Node, text: String, action: Callable, network: bool = true) -> Button:
	var button:=Button.new()
	button.text=text
	button.custom_minimum_size=Vector2(120,42)
	button.pressed.connect(action)
	parent.add_child(button)
	apply_theme(button)
	if network:
		network_buttons.append(button)
		button.disabled=in_flight
	return button

func apply_theme(node: Node) -> void:
	if node is Control:
		node.add_theme_font_override("font",font)
		if not node is Label:
			node.add_theme_font_size_override("font_size",18)
		if node is Button:
			for state in ["normal","hover","pressed","disabled"]:
				var style:=StyleBoxFlat.new()
				style.bg_color=Color("c8b897") if state=="normal" else Color("b9a787")
				style.set_corner_radius_all(5)
				style.content_margin_left=12
				style.content_margin_right=12
				style.content_margin_top=8
				style.content_margin_bottom=8
				node.add_theme_stylebox_override(state,style)
			node.add_theme_color_override("font_color",Color("354a43"))
	for child in node.get_children():
		apply_theme(child)

func lock(value: bool) -> void:
	in_flight=value
	for button in network_buttons:
		if is_instance_valid(button):
			button.disabled=value
	if is_instance_valid(write_button):
		write_button.disabled=value or client.player.is_empty() or client.player.get("reply_required",false)
	if is_instance_valid(address):
		address.editable=not value
		nickname.editable=not value

func connect_now() -> void:
	if in_flight:
		return
	lock(true)
	message.text="正在连接海岸邮局……"
	var result: Dictionary=await client.connect_service(address.text,nickname.text)
	if not active:
		return
	lock(false)
	if not result.ok:
		message.text=result.get("error","连接失败。")
		return
	await refresh()

func refresh() -> void:
	if in_flight:
		return
	if client.token.is_empty():
		message.text="请先连接邮局。"
		return
	lock(true)
	var path: String="/v1/letters?view="+view
	if before!=null:
		path+="&before="+str(before)
	var result: Dictionary=await client.request(path)
	if not active:
		return
	lock(false)
	if not result.ok:
		message.text=result.get("error","暂时没有收到邮局的回应。")
		return
	clear(letters_box)
	next_before=result.get("next_before")
	debt_label.text="待完成：回复一封来信，才能再次自由发信。" if client.player.get("reply_required",false) else "可以自由发信，也可以继续回复海上的旧信。"
	for letter in result.get("letters",[]):
		var id: int=int(letter.id)
		var label: String="#%d  %s\n%s · %d 封回复" % [id,letter.title,letter.name,int(letter.reply_count)]
		var b:=add_button(letters_box,label,func(): show_letter(id))
		b.custom_minimum_size=Vector2(385,83)
		b.alignment=HORIZONTAL_ALIGNMENT_LEFT
		b.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	if result.get("letters",[]).is_empty():
		add_label(letters_box,"暂时没有信件。",20)
	message.text="每封信会留在邮局。起航信是事务所准备的，不冒充玩家来信。"
	lock(false)

func show_letter(id: int) -> void:
	if in_flight:
		return
	lock(true)
	var result: Dictionary=await client.request("/v1/letters/"+str(id))
	if not active:
		return
	lock(false)
	if not result.ok:
		message.text=result.get("error","打开失败。")
		return
	clear(detail_box)
	var letter: Dictionary=result.letter
	add_label(detail_box,"#%d  %s" % [int(letter.id),letter.title],26)
	add_label(detail_box,letter.name+ (" · 事务所起航信" if letter.is_seed else " · 玩家来信"),16)
	if not letter.is_own and not letter.get("already_replied",false):
		add_button(detail_box,"回到桌边，回复这封信",func(): compose_requested.emit(letter); close())
	if not str(letter.get("art_png","")).is_empty():
		var image:=Image.new()
		if image.load_png_from_buffer(Marshalls.base64_to_raw(letter.art_png))==OK:
			var art:=TextureRect.new()
			art.texture=ImageTexture.create_from_image(image)
			art.custom_minimum_size=Vector2(560,430)
			art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			detail_box.add_child(art)
	var caption:=add_label(detail_box,letter.caption,22)
	caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	caption.custom_minimum_size.x=650
	if letter.get("already_replied",false):
		add_label(detail_box,"你已回复过这封信，可以阅读后续回信。",17)
	if letter.parent!=null:
		var parent_id:=int(letter.parent)
		add_button(detail_box,"读原信 #"+str(parent_id),func(): show_letter(parent_id))
	add_label(detail_box,"回声 / 最新回复",20)
	for reply in result.get("replies",[]):
		var reply_id:=int(reply.id)
		add_button(detail_box,"#%d  %s / %s" % [reply_id,reply.title,reply.name],func(): show_letter(reply_id))
	if result.get("replies",[]).is_empty():
		add_label(detail_box,"还没有回信。",17)

func compose_new() -> void:
	if client.player.is_empty() or client.player.get("reply_required",false):
		message.text="请先回复一封来信。"
		return
	compose_requested.emit({})
	close()

func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func close() -> void:
	active=false
	closed.emit()
	if is_instance_valid(root):
		root.queue_free()
	# Let any awaited HTTP response finish before this controller is freed.
	get_tree().create_timer(13).timeout.connect(queue_free)
