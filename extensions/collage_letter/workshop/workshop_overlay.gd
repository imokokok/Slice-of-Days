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
		if w.sprites.has("scissors"):
			var texture: Texture2D=w.sprites.scissors
			var pivot: Vector2=w.cut_start.lerp(w.cut_end,w.cut_progress)
			var turn:=sin(w.elapsed*22)*0.10 if w.cutting else 0.0
			var dimensions:=texture.get_size()
			# Animate the two scissor halves independently around the screw.
			for half in 2:
				var angle: float=(w.cut_end-w.cut_start).angle()+turn*(1 if half==0 else -1)
				draw_set_transform(pivot,angle,Vector2.ONE)
				var region:=Rect2(0,half*dimensions.y*0.5,dimensions.x,dimensions.y*0.5)
				draw_texture_rect_region(texture,Rect2(-105,-61+half*61,210,61),region)
			draw_set_transform(Vector2.ZERO)
	if w.mode==w.Mode.KNIFE_CUTTING:
		if w.knife_path.size()>1: draw_polyline(w.knife_path,Color("a46548"),1.5,true)
		if w.sprites.has("knife"): draw_texture_rect(w.sprites.knife,Rect2(w.pointer-Vector2(7,105),Vector2(34,115)),false)
	if w.mode==w.Mode.DRAWING:
		if w.sprites.has("pen"): draw_texture_rect(w.sprites.pen,Rect2(w.pointer-Vector2(5,140),Vector2(33,150)),false)
	if w.tape_pending or w.tape_pulling:
		draw_line(w.tape_start,w.tape_end,Color(0.65,0.75,0.73,0.65),26,true)
		var direction: Vector2=w.tape_end-w.tape_start
		var normal:=Vector2(-direction.y,direction.x).normalized()*12
		for i in range(0,int(direction.length()),15):
			var point: Vector2=w.tape_start+direction.normalized()*i
			draw_line(point-normal,point+normal,Color(0.94,0.88,0.7,0.55),2,true)
		if w.sprites.has("tape"):
			draw_set_transform(w.tape_end,w.tape_angle,Vector2.ONE)
			draw_texture_rect(w.sprites.tape,Rect2(-32,-30,64,60),false)
			draw_set_transform(Vector2.ZERO)
	if not w.hovered_title.is_empty() and w.mode==w.Mode.DESK:
		var at: Vector2=w.pointer+Vector2(18,-20)
		at.x=clampf(at.x,20,1280);at.y=clampf(at.y,100,820)
		draw_style_box(w._paper_style(),Rect2(at-Vector2(8,21),Vector2(295,34)))
		draw_string(w.font,at,w.hovered_title,HORIZONTAL_ALIGNMENT_LEFT,280,14,w.INK)
