extends Node2D

var tool: Node2D

func paint(target: Node2D) -> void :


	# Draw the front lip inside the existing bowl.  The former filled crescent
	# extended below the sprite and looked like a detached, cracked half.
	var center: = Vector2(-23, -1)
	var rim: = PackedVector2Array()
	for i in range(17):
		var angle: = lerpf(0.14, PI - 0.14, float(i) / 16.0)
		rim.append(center + Vector2(cos(angle) * 17.0, sin(angle) * 6.0))
	target.draw_polyline(rim, Color("936039"), 2.5, true)

func _draw() -> void :
	paint(self)
