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
var action_verb := "切配"
var action_sound := "cut"
var knife_drop := 0.0
var knife_angle := 0.0
var drag_origin := Vector2.ZERO
var drag_handled := false
var suppress_next_press := false
var motion: Tween

func _ready() -> void:
	name="ChoppingBoard"; focus_mode=FOCUS_ALL; mouse_default_cursor_shape=CURSOR_POINTING_HAND
	accessibility_name="切菜板"
	for state in ["normal","hover","pressed","disabled","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for s in [mouse_entered,mouse_exited,focus_entered,focus_exited]: s.connect(queue_redraw)
	pressed.connect(_cut)

func begin(id: String, option: String, needed := 3, verb := "切配", sound := "cut") -> void:
	target_id=id; target_option=option; strokes=0; strokes_needed=maxi(1,needed)
	action_verb=verb; action_sound=sound
	knife_angle=0.0; drag_handled=false; suppress_next_press=false
	accessibility_name="%s%s，已完成 0 / %d 下" % [action_verb,id,strokes_needed]
	queue_redraw()

func clear_target() -> void:
	target_id=""; target_option=""; strokes=0
	accessibility_name="备料案板"
	queue_redraw()

func _cut() -> void:
	if suppress_next_press:
		suppress_next_press=false
		return
	if disabled or target_id.is_empty() or not items.has(target_id): return
	strokes+=1
	WorldSound.play_kind("water" if action_sound=="water" else "wood",-20.0,.3)
	if motion and motion.is_valid(): motion.kill()
	knife_drop=0.0
	if not SettingsSystem.reduced_motion():
		motion=create_tween()
		motion.tween_method(func(v: float): knife_drop=v; queue_redraw(),0.0,1.0,0.08)
		motion.tween_method(func(v: float): knife_drop=v; queue_redraw(),1.0,0.0,0.13)
	accessibility_name="%s%s，已完成 %d / %d 下" % [action_verb,target_id,strokes,strokes_needed]
	stroke.emit(target_id,strokes,strokes_needed)
	if strokes>=strokes_needed:
		cuts[target_id]=target_option
		var finished := target_id
		clear_target()
		prepared.emit(finished)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if disabled or target_id.is_empty(): return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			drag_origin=event.position
			drag_handled=false
			suppress_next_press=false
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not drag_handled:
		drag_stroke(drag_origin,event.position)

func drag_stroke(start: Vector2, finish: Vector2) -> bool:
	if disabled or target_id.is_empty(): return false
	var movement := finish-start
	if movement.length()<32.0: return false
	var center := Vector2(82+items.find(target_id)*102,119)
	var t := clampf((center-start).dot(movement)/movement.length_squared(),0.0,1.0)
	if (center-(start+movement*t)).length()>55.0: return false
	drag_handled=true
	suppress_next_press=true
	knife_angle=clampf(atan2(movement.y,movement.x),-0.65,0.65)
	_cut_drag()
	return true

func _cut_drag() -> void:
	# A drag is one deliberate stroke; the button's release signal is ignored.
	suppress_next_press=false
	_cut()
	suppress_next_press=true

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
		elif id==target_id and strokes>0:
			ART.draw_prepared(self,id,target_option,rect,Color(1,1,1,0.38+0.62*float(strokes)/float(strokes_needed)))
		else: ART.draw_raw(self,id,rect)
		if id==target_id:
			draw_arc(center,55.0,0.0,TAU,32,Color("e6bf71",0.82),2.0,true)
			for mark in strokes_needed:
				var x := center.x-27.0+mark*25.0
				draw_line(Vector2(x,191),Vector2(x+12,191),Color("f1d68c") if mark<strokes else Color("705d47",0.45),4.0,true)
			if action_verb=="切配":
				for cut_index in strokes:
					var cut_x := rect.position.x+rect.size.x*(float(cut_index+1)/float(strokes_needed+1))
					draw_line(Vector2(cut_x,rect.position.y+10),Vector2(cut_x-4,rect.end.y-8),Color("fff2d8",0.8),2.0,true)
	var knife_x := 192.0
	if not target_id.is_empty(): knife_x=82.0+items.find(target_id)*102.0+53.0
	if target_id.is_empty() or action_verb=="切配":
		draw_set_transform(Vector2(knife_x,200+knife_drop*13),knife_angle,Vector2.ONE)
		draw_texture_rect_region(KIT,Rect2(-72,-54,145,115),Rect2(0,512,512,512))
		draw_set_transform(Vector2.ZERO)
	else:
		var gesture_center := Vector2(knife_x-3,196+knife_drop*10)
		draw_circle(gesture_center,17,Color("e2b988",0.85))
		draw_arc(gesture_center,22,PI*0.1,PI*0.9,20,Color("fff0d4",0.8),3,true)
	if has_focus() or is_hovered(): draw_line(Vector2(45,size.y-9),Vector2(size.x-45,size.y-11),Color("e6bf71"),3,true)
