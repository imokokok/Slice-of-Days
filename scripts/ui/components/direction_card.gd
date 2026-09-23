extends Button
## A single sourced suggestion; clicking follows the existing map/action handler.
const PALETTE = preload("res://scripts/ui/components/interface_palette.gd")
var heading: Label
var title: Label
var context: Label
var route: Label
var entry: Dictionary={}
var transition: Tween
var signature := ""
func _ready() -> void:
	add_to_group("solid_hud"); name="CurrentDirection"
	focus_mode=FOCUS_ALL; mouse_default_cursor_shape=CURSOR_POINTING_HAND
	clip_text=true; flat=false; autowrap_mode=TextServer.AUTOWRAP_OFF
	for state in ["normal","hover","pressed","disabled","focus"]:
		var color := PALETTE.DEEP if state=="normal" else Color("356580") if state=="hover" else Color("183d56")
		var frame := PALETTE.face(color,8,0)
		if state=="focus": frame.bg_color=Color.TRANSPARENT; frame.set_border_width_all(2); frame.border_color=PALETTE.LEMON
		add_theme_stylebox_override(state,frame)
		add_theme_color_override("font_"+("color" if state=="normal" else state+"_color"),Color.TRANSPARENT)
	heading=PALETTE.words(self,"",Vector2(16,10),288,15,PALETTE.LEMON); heading.hide()
	title=PALETTE.words(self,"",Vector2(16,12),288,22,PALETTE.CREAM)
	context=PALETTE.words(self,"",Vector2(16,73),288,18,Color("d8e5e9"))
	for words in [title,context]:
		words.max_lines_visible=2 if words==title else 1; words.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	route=PALETTE.words(self,"",Vector2(16,112),288,17,PALETTE.CREAM)
	for signal_name in ["mouse_entered","mouse_exited","focus_entered","focus_exited","button_down","button_up"]: connect(signal_name,queue_redraw)

func present(value: Dictionary) -> void:
	entry=value.duplicate(true); title.text=LocalizationSystem.text(str(value.get("text",""))); text=title.text.replace("\n"," ")
	var urgent := str(value.get("priority",""))=="critical"
	heading.text=LocalizationSystem.text("先确认一下" if urgent else "你正在留意" if str(value.get("priority",""))=="personal" else "故事有了下文" if str(value.get("priority",""))=="connection" else "接下来，可以…")
	var detail := LocalizationSystem.text(str(value.get("context","")))
	context.text=detail; context.visible=not detail.is_empty()
	var location := str(value.get("location",""))
	var place := LocalizationSystem.text(TravelSystem.location_name(location) if not location.is_empty() else "随身本")
	var action := str(value.get("action",""))
	var destination := LocalizationSystem.text("日程与视角" if action=="day_schedule" else "整理今天" if action=="evening" and location==GameState.current_location else "查看记录" if action in ["portfolio","final","personal"] else "查看路线")
	route.text=(LocalizationSystem.text("就在这里")+" · " if location==GameState.current_location else place+" · ")+destination+"  ›"
	size=Vector2(320,144)
	tooltip_text=text+"\n"+detail+"\n"+SettingsSystem.binding_text("open_map")+" "+LocalizationSystem.text("地图")+" · "+SettingsSystem.binding_text("open_notebook")+" "+LocalizationSystem.text("随身本")
	var key := str(value.get("id",text))+detail
	if key!=signature:
		signature=key
		if transition: transition.kill()
		modulate.a=1
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(route): return
	draw_line(Vector2(24,route.position.y-9),Vector2(size.x-24,route.position.y-9),Color("c8dbe3",.24),1,true)
	draw_line(Vector2(0,20),Vector2(0,52),PALETTE.LEMON,3,true)
	if has_focus() or is_hovered(): draw_circle(Vector2(size.x-22,28),3,PALETTE.LEMON)
