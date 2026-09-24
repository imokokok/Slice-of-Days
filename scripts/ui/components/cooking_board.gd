extends Button
## The board is a real preparation control. Dedicated prepared art is preserved
## intact; only ingredients without a prepared drawing use the fallback split.
signal prepared(item_id: String)
const KIT = preload("res://art/ui/pocket_doodles/kitchen_objects.png")
const ART = preload("res://scripts/ui/components/cooking_ingredients.gd")
var items: Array[String]=[]
var cuts: Dictionary={}
var knife_drop := 0.0
var motion: Tween

func _ready() -> void:
	name="ChoppingBoard"; focus_mode=FOCUS_ALL; mouse_default_cursor_shape=CURSOR_POINTING_HAND
	accessibility_name="切菜板，按下切一份食材"
	for state in ["normal","hover","pressed","disabled","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for s in [mouse_entered,mouse_exited,focus_entered,focus_exited]: s.connect(queue_redraw)
	pressed.connect(_cut)

func _cut() -> void:
	if disabled: return
	for id in items:
		if cuts.has(id): continue
		cuts[id]=true
		prepared.emit(id)
		WorldSound.play_ui("cut")
		if motion: motion.kill()
		knife_drop=0
		motion=create_tween(); motion.tween_method(func(v: float): knife_drop=v; queue_redraw(),0.0,1.0,.1)
		motion.tween_method(func(v: float): knife_drop=v; queue_redraw(),1.0,0.0,.14)
		return

func _draw() -> void:
	draw_texture_rect_region(KIT,Rect2(0,-32,size.x,size.y+55),Rect2(0,0,512,512))
	for i in items.size():
		var texture := ART.texture(items[i],cuts.has(items[i]))
		var center := Vector2(82+i*102,119)
		var dimensions := texture.get_size()*minf(83.0/texture.get_width(),116.0/texture.get_height())
		var has_prepared_drawing := ART.prepared_texture(items[i])!=null
		var prep_option := str(cuts.get(items[i],""))
		if cuts.has(items[i]) and ART.has_distinct_prep_drawing(items[i],prep_option):
			ART.draw_prepared(self,items[i],prep_option,Rect2(center-dimensions*.5,dimensions))
		elif cuts.has(items[i]) and ART.can_cut(items[i]) and not has_prepared_drawing and items[i] not in ["tomato","herbs","bread","lemon"]:
			for part in 3:
				var source := Rect2(part*texture.get_width()/3.0,0,texture.get_width()/3.0,texture.get_height())
				var dest := Rect2(center-dimensions*.5+Vector2(part*(dimensions.x/3+5),0),Vector2(dimensions.x/3,dimensions.y))
				draw_texture_rect_region(texture,dest,source)
		else: draw_texture_rect(texture,Rect2(center-dimensions*.5,dimensions),false)
	draw_texture_rect_region(KIT,Rect2(192,146+knife_drop*13,145,115),Rect2(0,512,512,512))
	if has_focus() or is_hovered(): draw_line(Vector2(45,size.y-9),Vector2(size.x-45,size.y-11),Color("e6bf71"),3,true)
