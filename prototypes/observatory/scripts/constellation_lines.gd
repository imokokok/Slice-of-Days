extends Control
var camera: Camera3D
var data: ConstellationData
var strength := 0.0
var reveal_progress := 0.0
func _draw() -> void:
 if not camera or not data or strength <= 0.001: return
 var count := int(data.lines.size() / 2)
 for segment in count:
  var a := data.positions[data.lines[segment*2]]
  var b := data.positions[data.lines[segment*2+1]]
  var progress := clampf(reveal_progress*count-float(segment),0,1)
  if progress <= 0 or camera.is_position_behind(a) or camera.is_position_behind(b): continue
  var start := camera.unproject_position(a)
  var finish := start.lerp(camera.unproject_position(b),progress)
  draw_line(start,finish,Color(0.35,0.58,1.0,strength*0.07),9.0,true)
  draw_line(start,finish,Color(0.47,0.72,1.0,strength*0.2),4.0,true)
  draw_line(start,finish,Color(0.83,0.94,1.0,strength*0.85),1.3,true)
 for p in data.positions:
  if camera.is_position_behind(p): continue
  var center := camera.unproject_position(p)
  draw_circle(center,8.0,Color(0.5,0.72,1.0,strength*0.055))
  draw_circle(center,4.0,Color(0.63,0.82,1.0,strength*0.16))
  draw_circle(center,1.5,Color(0.9,0.97,1.0,strength*0.9))
