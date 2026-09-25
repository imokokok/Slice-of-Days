extends SceneTree
const Thermal=preload("res://modules/restaurant/domain/food_thermal.gd")
const Appearance=preload("res://modules/restaurant/assets/cooking_appearance.gd")
func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	root.size=Vector2i(1260,920)
	root.content_scale_size=Vector2i(1260,920)
	var bg:=ColorRect.new()
	bg.size=Vector2(1260,920);bg.color=Color("f9edcf")
	root.add_child(bg)
	var defs: Array=JSON.parse_string(FileAccess.get_file_as_string("res://modules/restaurant/data/ingredients.json"))
	var ids: Array=["tofu","mushroom","butter","cheese","tomato"]
	var titles: Array=["原料","刚接触 / 开始受热","搅拌 / 持续加热","混匀 / 充分受热"]
	for c in 4: label(titles[c],Vector2(195+c*260,25),24)
	for r in ids.size():
		var definition: Dictionary={}
		for d in defs:
			if d.id==ids[r]: definition=d
		label(definition.name,Vector2(30,110+r*162),24)
		for c in 4:
			var state:=Thermal.make_state(definition,0.1,0.3)
			var coating: Dictionary={}
			if r<2:
				if c>0: coating={"volume_ml":4.0,"composition_ml":{"ketchup":4.0} if r==0 else {"soy_sauce":4.0},"spread":[0.0,0.0,0.42,1.0][c],"origin":[0.45,0.3]}
				if c==3:
					for i in 1500: Thermal.advance(state,definition,1.0/60.0,160.0,22.0,false,0.1-float(state.evaporated_kg))
			else:
				for i in [0,180,660,1800][c]:
					if r==4 and i%30==0: Thermal.stir(state,0.3,false)
					Thermal.advance(state,definition,1.0/60.0,170.0,22.0,false,0.1-float(state.evaporated_kg))
			var art=preload("res://modules/restaurant/assets/food_art.gd").new()
			art.definition=definition;art.thermal=state;art.coating=coating
			art.heat=Thermal.legacy_heat(state);art.shadows=false
			art.scale=Vector2.ONE*1.5*Thermal.shape(state,definition)
			art.position=Vector2(255+c*260,112+r*162)
			root.add_child(art)
			if r>=2: label("同源液相 %.0f%%"%(float(state.liquid_kg)*1000.0),Vector2(190+c*260,164+r*162),17)
	label("实际状态模型与原食材渲染 · 二维近似 · 不替换为预制菜品图",Vector2(215,876),20)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var result:=root.get_texture().get_image()
	var distinct:=true
	for r in 5:
		var first:=result.get_region(Rect2i(165,60+r*162,180,104)).get_data()
		var last:=result.get_region(Rect2i(945,60+r*162,180,104)).get_data()
		distinct=distinct and first!=last
	var args:=OS.get_cmdline_user_args()
	var error:=result.save_png(args[0] if not args.is_empty() else "user://reactions.png")
	print("%s: rendered reaction progression, 5 material comparisons"%["PASS" if distinct and error==OK else "FAIL"])
	quit(0 if distinct and error==OK else 1)
func label(text: String,p: Vector2,size: int) -> void:
	var node:=Label.new()
	node.text=text;node.position=p
	node.add_theme_font_override("font",preload("res://modules/restaurant/ui/paper_ink.gd").font())
	node.add_theme_font_size_override("font_size",size)
	node.add_theme_color_override("font_color",Color("695343"))
	root.add_child(node)
