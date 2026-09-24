extends Button
## The board is a real preparation control. Dedicated prepared art is preserved
## intact; only ingredients without a prepared drawing use the fallback split.
signal prepared(item_id: String)
signal stroke(item_id: String, done: int, needed: int)
const KIT = preload("res://art/ui/pocket_doodles/kitchen_objects.png")
const ART = preload("res://scripts/ui/components/cooking_ingredients.gd")
var items: Array[String]=[]
var cuts: Dictionary={}
var target_id := ""
var target_option := ""
var strokes := 0
var strokes_needed := 3
var knife_drop := 0.0
var motion: Tween

func _ready() -> void:
	name="ChoppingBoard"; focus_mode=FOCUS_ALL; mouse_default_cursor_shape=CURSOR_POINTING_HAND
	accessibility_name="切菜板"
	for state in ["normal","hover","pressed","disabled","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for s in [mouse_entered,mouse_exited,focus_entered,focus_exited]: s.connect(queue_redraw)
	pressed.connect(_cut)

func begin(id: String, option: String, needed := 3) -> void:
	target_id=id; target_option=option; strokes=0; strokes_needed=maxi(1,needed)
	accessibility_name="处理%s，已完成 0 / %d 下" % [id,strokes_needed]
	queue_redraw()

func clear_target() -> void:
	target_id=""; target_option=""; strokes=0
	accessibility_name="切菜板"
	queue_redraw()

func _cut() -> void:
	if disabled or target_id.is_empty() or not items.has(target_id): return
	strokes+=1
	WorldSound.play_ui("cut")
	if motion and motion.is_valid(): motion.kill()
	knife_drop=0.0
	if not SettingsSystem.reduced_motion():
		motion=create_tween()
		motion.tween_method(func(v: float): knife_drop=v; queue_redraw(),0.0,1.0,0.08)
		motion.tween_method(func(v: float): knife_drop=v; queue_redraw(),1.0,0.0,0.13)
	accessibility_name="处理%s，已完成 %d / %d 下" % [target_id,strokes,strokes_needed]
	stroke.emit(target_id,strokes,strokes_needed)
	if strokes>=strokes_needed:
		cuts[target_id]=target_option
		var finished := target_id
		clear_target()
		prepared.emit(finished)
	queue_redraw()

func _draw() -> void:
	draw_texture_rect_region(KIT,Rect2(0,-32,size.x,size.y+55),Rect2(0,0,512,512))
	for i in items.size():
		var id := items[i]
		var done := cuts.has(id)
		var texture := ART.texture(id,done)
		var center := Vector2(82+i*102,119)
		var dimensions := texture.get_size()*minf(83.0/texture.get_width(),116.0/texture.get_height())
		var rect := Rect2(center-dimensions*.5,dimensions)
		if done: ART.draw_prepared(self,id,str(cuts[id]),rect)
		else: draw_texture_rect(texture,rect,false)
		if id==target_id:
			draw_arc(center,55.0,0.0,TAU,32,Color("e6bf71",0.82),2.0,true)
			for mark in strokes_needed:
				var x := center.x-27.0+mark*25.0
				draw_line(Vector2(x,191),Vector2(x+12,191),Color("f1d68c") if mark<strokes else Color("705d47",0.45),4.0,true)
			for cut_index in strokes:
				var cut_x := rect.position.x+rect.size.x*(float(cut_index+1)/float(strokes_needed+1))
				draw_line(Vector2(cut_x,rect.position.y+10),Vector2(cut_x-4,rect.end.y-8),Color("fff2d8",0.8),2.0,true)
	var knife_x := 192.0
	if not target_id.is_empty(): knife_x=82.0+items.find(target_id)*102.0+53.0
	draw_texture_rect_region(KIT,Rect2(knife_x-72,146+knife_drop*13,145,115),Rect2(0,512,512,512))
	if has_focus() or is_hovered(): draw_line(Vector2(45,size.y-9),Vector2(size.x-45,size.y-11),Color("e6bf71"),3,true)
