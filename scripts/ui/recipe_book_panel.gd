extends Control
signal follow_recipe(recipe: Dictionary)
const BOOK = preload("res://scripts/core/recipe_book.gd")
const ART = preload("res://scripts/ui/components/handmade_assets.gd")
const P = preload("res://scripts/ui/components/interface_palette.gd")
var ingredients: Array=[]
var heat := 0.58
var section := "house"
var chosen: Dictionary={}
var body: Control
var message: Label
var drawing: Control
var title_field: LineEdit
var author_field: LineEdit
var notes_field: TextEdit
var editing := false

func _ready() -> void:
	add_to_group("meta_modal"); add_to_group("recipe_book")
	set_anchors_and_offsets_preset(PRESET_FULL_RECT); theme=P.theme_for_tools()
	var dim := ColorRect.new(); dim.color=Color("254b66",.82); dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT); add_child(dim)
	ART.picture(self,"recipe_book",Vector2(112,90),Vector2(1376,680),true)
	body=Control.new(); add_child(body)
	message=P.words(self,"朋友的菜谱可通过文件交换，导入后可以照着做。",Vector2(225,823),1190,20,P.CREAM)
	_build()

func _btn(text: String, at: Vector2, extent: Vector2, action: Callable, variant := "quiet") -> Button:
	var b := preload("res://scripts/ui/components/solmere_button.gd").new()
	b.text=text; b.position=at; b.size=extent; b.variant=variant; b.pressed.connect(action); body.add_child(b)
	return b

func _remember_draft() -> bool:
	if not editing: return true
	if not BOOK.save_draft(_draft()):
		message.text="草稿还没能保存，请稍后重试。"
		return false
	return true

func _draft() -> Dictionary:
	return {"id":chosen.get("id",""),"title":title_field.text,"author":author_field.text,"notes":notes_field.text,"ingredients":ingredients.duplicate(),"heat":heat,"strokes":drawing.strokes.duplicate(true)}

func _switch(next: String) -> void:
	if not _remember_draft(): return
	section=next; chosen={}; editing=false; _build()

func _close() -> void:
	if _remember_draft(): queue_free()

func _back() -> void:
	if not _remember_draft(): return
	editing=false; _build()

func _begin_draft() -> void:
	chosen=GameState.artifacts.get("recipe_draft",{}).duplicate(true)
	if not chosen.is_empty():
		ingredients=chosen.get("ingredients",[]).duplicate()
		heat=float(chosen.get("heat",.58))
	editing=true; _build()

func _build() -> void:
	for child in body.get_children(): body.remove_child(child); child.queue_free()
	for i in 3:
		var names := ["店主的菜谱","我的菜谱","朋友的菜谱"]
		var sections := ["house","mine","shared"]
		var tab := _btn(names[i],Vector2(165+i*211,36),Vector2(200,48),_switch.bind(sections[i]),"tab")
		tab.selected=section==sections[i]
	_btn("收起",Vector2(1330,35),Vector2(150,48),_close,"camera")
	if editing: _editor(); return
	_btn("导入朋友的菜谱",Vector2(860,35),Vector2(325,48),func():_file(true),"camera")
	P.words(body,"这一页的味道",Vector2(225,142),475,29)
	var entries := BOOK.entries(section)
	if chosen.is_empty() and not entries.is_empty(): chosen=entries[0]
	var scroll := ScrollContainer.new(); scroll.position=Vector2(221,209); scroll.size=Vector2(490,280); body.add_child(scroll)
	var rows := VBoxContainer.new(); rows.size_flags_horizontal=SIZE_EXPAND_FILL; rows.add_theme_constant_override("separation",22); scroll.add_child(rows)
	for row in entries:
		var button := preload("res://scripts/ui/components/solmere_button.gd").new()
		button.text=str(row.title)+"\n"+str(row.author); button.custom_minimum_size=Vector2(460,68); rows.add_child(button)
		button.selected=chosen.get("id","")==row.id
		button.pressed.connect(func(): chosen=row; _build())
	if entries.is_empty(): P.words(body,"这里还没有菜谱。\n写下自己的，或收下朋友的一页。",Vector2(225,227),470,21)
	if not chosen.is_empty():
		P.words(body,str(chosen.title),Vector2(852,143),515,30)
		P.words(body,"来自 "+str(chosen.author),Vector2(854,190),500,18,P.MUTED)
		for i in chosen.ingredients.size(): ART.picture(body,str(chosen.ingredients[i]),Vector2(852+i*167,234),Vector2(147,117))
		var notes_scroll := ScrollContainer.new(); notes_scroll.position=Vector2(853,367); notes_scroll.size=Vector2(512,118); notes_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; body.add_child(notes_scroll)
		var note := P.words(notes_scroll,str(chosen.get("notes","")),Vector2.ZERO,495,21)
		note.size_flags_horizontal=SIZE_EXPAND_FILL
		drawing=preload("res://scripts/ui/components/recipe_drawing.gd").new(); drawing.position=Vector2(854,490); drawing.size=Vector2(500,103); drawing.strokes=chosen.get("strokes",[]).duplicate(true); drawing.editable=false; body.add_child(drawing)
		_btn("照着这一页做",Vector2(844,752),Vector2(290,48),func(): follow_recipe.emit(chosen); queue_free(),"camera")
		_btn("导出给朋友",Vector2(1150,752),Vector2(255,48),func(): _file(false),"camera")
		if section=="shared":
			var reactions := BOOK.appreciations(str(chosen.id))
			var like := _btn("喜欢这个做法 · %d"%reactions.size(),Vector2(860,626),Vector2(480,48),func():
				message.text=str(BOOK.appreciate(str(chosen.id)).message); _build(),"paper")
			like.name="AppreciateRecipe"
			like.disabled=reactions.has(GameState.current_role) or str(chosen.get("role",""))==GameState.current_role
		if section=="mine":
			_btn("编辑这一页",Vector2(225,494),Vector2(225,43),func():
				if not GameState.artifacts.get("recipe_draft",{}).is_empty():
					message.text="先继续并保存已有草稿，再编辑另一页。"; return
				ingredients=chosen.ingredients.duplicate(); heat=float(chosen.heat); editing=true; _build())
			_btn("放进公共菜谱",Vector2(454,494),Vector2(256,43),func(): message.text=str(BOOK.save_recipe(chosen,true).message))
	var new_label := "继续未写完的草稿" if not GameState.artifacts.get("recipe_draft",{}).is_empty() else "记下手边这道菜"
	_btn(new_label,Vector2(223,752),Vector2(340,48),_begin_draft,"camera")

func _editor() -> void:
	P.words(body,"把这道菜留下来",Vector2(225,143),475,31)
	title_field=LineEdit.new(); title_field.placeholder_text="菜名"; title_field.text=str(chosen.get("title","")); title_field.position=Vector2(225,212); title_field.size=Vector2(475,50); title_field.max_length=48; body.add_child(title_field)
	author_field=LineEdit.new(); author_field.placeholder_text="署名"; author_field.text=str(chosen.get("author",GameState.current_role)); author_field.position=Vector2(225,280); author_field.size=Vector2(475,50); author_field.max_length=40; body.add_child(author_field)
	# Leave the printed botanical corner below y=525 unobstructed.
	notes_field=TextEdit.new(); notes_field.name="RecipeNotes"; notes_field.placeholder_text="食材顺序、火候、想留给做菜人的话……"; notes_field.text=str(chosen.get("notes","")); notes_field.position=Vector2(225,350); notes_field.size=Vector2(475,165); notes_field.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY; body.add_child(notes_field)
	notes_field.text_changed.connect(func():
		if notes_field.text.length()>1600: notes_field.text=notes_field.text.left(1600))
	for i in ingredients.size(): ART.picture(body,str(ingredients[i]),Vector2(851+i*165,150),Vector2(145,110))
	P.words(body,"在这里画下你的菜",Vector2(853,282),500,22,P.MUTED)
	drawing=preload("res://scripts/ui/components/recipe_drawing.gd").new(); drawing.position=Vector2(852,326); drawing.size=Vector2(511,270); drawing.strokes=chosen.get("strokes",[]).duplicate(true); body.add_child(drawing)
	_btn("撤回一笔",Vector2(846,752),Vector2(225,48),func():
		if not drawing.strokes.is_empty(): drawing.strokes.pop_back(); drawing.queue_redraw(),"camera")
	_btn("保存这一页",Vector2(1100,752),Vector2(294,48),_save,"camera")
	_btn("收好草稿并返回",Vector2(223,752),Vector2(330,48),_back,"camera")
	P.words(body,"当前食材 %d / 3 · 火候 %d%%" % [ingredients.size(),roundi(heat*100)],Vector2(242,710),452,18,P.CREAM)
	message.text="翻页或收起时会保存草稿；写好菜名和署名后，可保存为正式菜谱。"

func _save() -> void:
	var result := BOOK.save_recipe(_draft(),false,true)
	message.text=str(result.message)
	if result.ok: chosen=result.recipe; section="mine"; editing=false; _build()

func _file(importing: bool) -> void:
	var dialog := FileDialog.new(); dialog.use_native_dialog=true; dialog.access=FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE if importing else FileDialog.FILE_MODE_SAVE_FILE
	dialog.filters=PackedStringArray(["*.solmere-recipe;Solmere 菜谱"])
	dialog.current_file="recipe.solmere-recipe" if not importing else ""
	add_child(dialog)
	dialog.file_selected.connect(func(path: String):
		if importing:
			var result := BOOK.import_recipe(path); message.text=str(result.message)
			if result.ok: chosen=result.recipe; section="shared"; _build()
		else: message.text="已导出，可把菜谱文件交给朋友。" if BOOK.export_recipe(chosen,path) else "导出失败，原菜谱仍保留。"
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free); dialog.popup_centered(Vector2i(900,600))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if editing: _back()
		else: _close()
		get_viewport().set_input_as_handled()
