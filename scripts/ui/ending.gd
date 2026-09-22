extends Control
const INK := Color("31658b")
const BACKGROUND=preload("res://art/ui/title-screen-background.png")
func _ready() -> void:
	if not bool(ChapterSystem.story().reveal_completed): SceneRouter.town_day(); return
	_label(self,"在同一座小镇，留下不同的日子",Vector2(180,150),Vector2(1200,80),38,INK)
	var rows := VBoxContainer.new(); rows.position=Vector2(240,300); rows.size=Vector2(1120,360); rows.add_theme_constant_override("separation",22); add_child(rows)
	for trace in GameState.shared_state.get("public_traces",{}).values():
		var line := Label.new(); line.text="Day %02d · %s · %s"%[int(trace.day),str(trace.owner),str(trace.title)]; line.add_theme_font_size_override("font_size",25); line.add_theme_color_override("font_color",INK); rows.add_child(line)
	var back := preload("res://scripts/ui/components/solmere_button.gd").new(); back.text="返回主菜单"; back.position=Vector2(670,760); back.size=Vector2(260,55); back.pressed.connect(SceneRouter.main_menu); add_child(back); back.grab_focus()
func _draw() -> void:
	draw_texture_rect(BACKGROUND,Rect2(Vector2.ZERO,size),false)
	draw_rect(Rect2(Vector2.ZERO,size),Color("faf7ee",.88))
func _label(parent: Node, text_value: String, at: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = LocalizationSystem.text(text_value)
	label.position = at
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
