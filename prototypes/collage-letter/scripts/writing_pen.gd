extends Control
## One original 2D pen follows the editor's rendered caret, without consuming input.
var editor: TextEdit
var resting_object: CanvasItem
var paper_bounds: Rect2
var ink:=Color("465951")
var stroke_left:=0.0
var life_left:=0.0
var rhythm:=0.0
var target_tip:=Vector2.ZERO
var has_position:=false
var committed_strokes:=0
var resting_mouse_filter:=Control.MOUSE_FILTER_STOP
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=5;modulate.a=0
	if resting_object is Control:resting_mouse_filter=resting_object.mouse_filter
func committed(characters: int) -> void:
	if characters<=0:return
	stroke_left=clampf(0.16+characters*0.025,0.19,0.42)
	life_left=0.85;committed_strokes+=1;modulate.a=1
func caret_tip() -> Vector2:
	# Godot reports the caret bottom, including font descent; the nib touches the baseline.
	var descent:=editor.get_theme_font("font").get_descent(editor.get_theme_font_size("font_size"))
	var tip:=editor.position+editor.get_caret_draw_pos()+Vector2(3,-descent)
	var safe:=paper_bounds.grow(-7)
	return tip.clamp(safe.position,safe.end)
func _process(dt: float) -> void:
	if not is_instance_valid(editor):return
	rhythm+=dt;stroke_left=maxf(0,stroke_left-dt);life_left=maxf(0,life_left-dt)
	# IME candidate text is not ink. Keep the nib lifted until committed text arrives.
	if editor.has_ime_text() or not editor.has_focus() or not editor.is_visible_in_tree():
		stroke_left=0;modulate.a=move_toward(modulate.a,0,dt*8);update_resting_pen();queue_redraw();return
	target_tip=caret_tip()
	if not has_position or position.distance_to(target_tip)>110:
		position=target_tip;has_position=true
	else:position=position.lerp(target_tip,1.0-exp(-dt*48.0))
	var opacity:=1.0 if stroke_left>0 else clampf(life_left/0.5,0,1)
	modulate.a=move_toward(modulate.a,opacity,dt*12)
	update_resting_pen()
	queue_redraw()
func update_resting_pen() -> void:
	if is_instance_valid(resting_object):
		resting_object.modulate.a=1.0-modulate.a
		if resting_object is Control:resting_object.mouse_filter=Control.MOUSE_FILTER_IGNORE if modulate.a>0.05 else resting_mouse_filter
func _exit_tree() -> void:
	if is_instance_valid(resting_object):
		resting_object.modulate.a=1.0
		if resting_object is Control:resting_object.mouse_filter=resting_mouse_filter
func _draw() -> void:
	if modulate.a<0.01:return
	var touching:=stroke_left>0
	var lift:=0.0 if touching else -7.0*(1.0-clampf(life_left/0.7,0,1))
	var wobble:=sin(rhythm*42.0)*0.016 if touching else 0.0
	var offset:=Vector2(sin(rhythm*35.0)*0.65,cos(rhythm*29.0)*0.45) if touching else Vector2.ZERO
	# The narrow barrel leans into the empty space beyond the caret, leaving words readable.
	draw_set_transform(offset+Vector2(4,3-lift*0.4),0.57+wobble)
	draw_line(Vector2(0,-17),Vector2(0,-83),Color(0.20,0.16,0.12,0.17),11,true)
	draw_set_transform(offset+Vector2(0,lift),0.57+wobble)
	var barrel:=PackedVector2Array([Vector2(-4,-29),Vector2(-5,-74),Vector2(-3,-83),Vector2(2,-86),Vector2(5,-79),Vector2(5,-30)])
	draw_colored_polygon(barrel,ink.darkened(0.10))
	draw_polyline(PackedVector2Array([Vector2(-2,-33),Vector2(-2,-73),Vector2(0,-81)]),ink.lightened(0.35),1.5,true)
	draw_line(Vector2(-4,-32),Vector2(4,-32),Color("c7a76d"),2,true)
	draw_line(Vector2(3,-78),Vector2(3,-62),Color("c7a76d"),1.4,true)
	draw_colored_polygon(PackedVector2Array([Vector2(-4,-29),Vector2(4,-29),Vector2(3,-16),Vector2(-3,-16)]),Color("404a43"))
	var nib:=PackedVector2Array([Vector2(-3,-17),Vector2(3,-17),Vector2(4,-11),Vector2(0,0),Vector2(-4,-11)])
	draw_colored_polygon(nib,Color("d5b87e"))
	draw_line(Vector2(0,-14),Vector2(0,-1),Color("67523b"),0.8,true)
	draw_circle(Vector2(0,-12),1,Color("67523b"))
	draw_set_transform(Vector2.ZERO)
