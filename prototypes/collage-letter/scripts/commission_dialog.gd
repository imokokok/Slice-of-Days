extends Control
const PanelArt=preload("res://scripts/folio_panel.gd")
var g
var desk
var body: Label
var speaker: Label
var reply: Button
var choices: Control
var step: int=0
var char_clock:=0.0
var question_return:=false
var accepted:=false
var lines: Array=[]
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP;size=Vector2(1440,900)
	var card:=PanelArt.new();card.postal_trim=true;card.position=Vector2(378,165);card.size=Vector2(690,520);card.paper_color=Color("fae4ac");card.edge_color=Color("e7a780");card.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(card)
	var request: Dictionary=g.commissions[g.commission_index%g.commissions.size()]
	lines=request.get("dialogue_"+g.L.language,[])
	if lines.is_empty():lines=[{"speaker":"npc","text":request["request_"+g.L.language],"reply":desk.t("好的，请交给我。")},{"speaker":"player","text":desk.t("做好后，我会帮您寄出。"),"reply":"›"},{"speaker":"npc","text":desk.t("好的，麻烦您了。"),"reply":desk.t("开始拼贴") }]
	speaker=desk.label(request["name_"+g.L.language],Rect2(415,193,545,35),22,self)
	body=desk.label("",Rect2(416,246,594,204),22,self);body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	choices=Control.new();choices.mouse_filter=Control.MOUSE_FILTER_IGNORE;choices.position=Vector2(0,0);add_child(choices)
	for i in g.customer_material_ids().size():
		var id: int=g.customer_material_ids()[i]
		var photo:=TextureRect.new();photo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;photo.texture=g.get_material_texture(id);photo.position=Vector2(430+i*135,454);photo.size=Vector2(125,100);photo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;photo.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(photo)
	reply=desk.button("›",Rect2(720,608,291,42),advance,false,self)
	desk.button("稍后继续",Rect2(415,608,140,42),close,false,self)
	show_step()
func show_step() -> void:
	var line: Dictionary=lines[step]
	speaker.text=desk.t("我") if line.get("speaker","npc")=="player" else g.commissions[g.commission_index%g.commissions.size()]["name_"+g.L.language]
	body.text=str(line.text);body.visible_characters=0;char_clock=0;reply.text=desk.t("显示整段")
	body.add_theme_font_size_override("font_size",21 if g.L.language=="zh" else 19)
	for child in choices.get_children():child.queue_free()
func _process(dt: float) -> void:
	if body.visible_characters>=body.text.length():return
	char_clock+=dt
	while char_clock>=0.042 and body.visible_characters<body.text.length():
		char_clock-=0.042;body.visible_characters+=1
		if body.text.substr(body.visible_characters-1,1) in ["。","，","？","！",".",",","?","!"]:char_clock-=0.12;break
	if body.visible_characters>=body.text.length():finished_typing()
func finished_typing() -> void:
	for child in choices.get_children():choices.remove_child(child);child.queue_free()
	reply.text=desk.t("继续") if question_return else str(lines[step].get("reply",desk.t("继续")))
	if not question_return and lines[step].get("questions",false):
		for i in 2:
			var index: int=i;desk.button(["对方喜欢哪种风格？","有什么特别的回忆？"][i],Rect2(417+i*296,559,285,36),func():ask(index),false,choices)
func advance() -> void:
	if body.visible_characters<body.text.length():body.visible_characters=body.text.length();finished_typing();return
	if question_return:question_return=false;show_step();body.visible_characters=body.text.length();finished_typing();return
	if step<lines.size()-1:step+=1;show_step();g.audio.play("DIALOGUE_ADVANCE",0.45)
	else:
		g.accepted_commission=g.commission_index;g.shelf_open=true;g.drawer_group="客户";g.drawer_page=0;g.save_game();close()
func ask(index: int) -> void:
	var data: Dictionary=g.commissions[g.commission_index%g.commissions.size()]
	var answers: Array=data.get("answers_"+g.L.language,[])
	body.text=str(answers[index]) if answers.size()>index else data["request_"+g.L.language]
	speaker.text=data["name_"+g.L.language];body.visible_characters=0;char_clock=0;question_return=true
	for child in choices.get_children():child.queue_free()
func close() -> void:
	g.conversation_open=false;queue_free();g.build_ui()
func _draw() -> void:
	draw_rect(Rect2(0,0,1440,900),Color(0.29,0.25,0.18,0.14))
