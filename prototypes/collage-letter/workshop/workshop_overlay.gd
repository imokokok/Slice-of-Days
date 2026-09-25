extends Node2D

var workshop: Node2D

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var w=workshop
	if not is_instance_valid(w) or w.dock_open or w.notes_open or w.settings_open: return
	if w.mode==w.Mode.SCISSOR_CUTTING:
		var count:=maxi(2,int(w.cut_start.distance_to(w.cut_end)/14))
		for i in range(0,count,2):
			draw_line(w.cut_start.lerp(w.cut_end,float(i)/count),w.cut_start.lerp(w.cut_end,float(i+1)/count),Color("eee1c9"),2,true)
		draw_circle(w.cut_start,8,Color("a85f43"));draw_circle(w.cut_end,7,Color("d3ac77"))
		if w.cut_progress>0: draw_line(w.cut_start,w.cut_start.lerp(w.cut_end,w.cut_progress),Color("985b42"),2,true)
		var pivot: Vector2=w.cut_start.lerp(w.cut_end,w.cut_progress)
		var opening: float=0.12+absf(sin(w.scissor_phase))*0.16 if w.cutting else 0.19
		for half in 2:
			var side := 1 if half == 0 else -1
			draw_set_transform(pivot,(w.cut_end-w.cut_start).angle()+opening*side,Vector2.ONE)
			draw_colored_polygon(PackedVector2Array([Vector2(-8,0),Vector2(94,-3*side),Vector2(72,9*side),Vector2(-8,8*side)]),Color("d5d8cf"))
			draw_line(Vector2(-8,0),Vector2(-51,16*side),Color("31658b"),9,true)
			draw_arc(Vector2(-69,23*side),22,0,TAU,32,Color("31658b"),8,true)
		draw_set_transform(Vector2.ZERO)
		draw_circle(pivot,5,Color("d0a450"))
	if w.mode==w.Mode.KNIFE_CUTTING:
		if w.knife_path.size()>1: draw_polyline(w.knife_path,Color("a46548"),1.5,true)
		if w.sprites.has("knife"):
			draw_set_transform(w.pointer,w.knife_angle,Vector2.ONE)
			draw_texture_rect(w.sprites.knife,Rect2(-15,0,34,135),false)
			draw_set_transform(Vector2.ZERO)
	if w.mode==w.Mode.DRAWING:
		if w.sprites.has(w.tool): draw_texture_rect(w.sprites[w.tool],Rect2(w.pointer-Vector2(5,140),Vector2(33,150)),false)
	if w.mode==w.Mode.GLUE:
		draw_texture_rect(w.sprites.glue,Rect2(w.pointer-Vector2(16,15),Vector2(37,85)),false)
	if w.tape_pending or w.tape_pulling:
		draw_line(w.tape_start,w.tape_end,Color(0.65,0.75,0.73,0.65),26,true)
		var direction: Vector2=w.tape_end-w.tape_start
		var normal:=Vector2(-direction.y,direction.x).normalized()*12
		for i in range(0,int(direction.length()),15):
			var point: Vector2=w.tape_start+direction.normalized()*i
			draw_line(point-normal,point+normal,Color(0.94,0.88,0.7,0.55),2,true)
		if w.sprites.has("tape"):
			draw_set_transform(w.tape_end,w.tape_angle,Vector2.ONE)
			var roll_size: Vector2 = w.tape_roll.bounds.size
			draw_texture_rect(w.sprites.tape,Rect2(-roll_size * 0.5,roll_size),false)
			draw_set_transform(Vector2.ZERO)
	if not w.hovered_title.is_empty() and w.mode==w.Mode.DESK:
		var at: Vector2=w.pointer+Vector2(18,-20)
		at.x=clampf(at.x,20,1280);at.y=clampf(at.y,100,820)
		draw_style_box(w._paper_style(),Rect2(at-Vector2(8,21),Vector2(295,34)))
		draw_string(w.font,at,w.hovered_title,HORIZONTAL_ALIGNMENT_LEFT,280,14,w.INK)
