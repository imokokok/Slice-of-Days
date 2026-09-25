extends Node2D
var controller: Node2D
const HANDLE_RECT := Rect2(158, 593, 66, 52)
func _draw() -> void :
	# One angular blue-grey faucet, matching the supplied reference.
	draw_rect(Rect2(125, 612, 35, 35), Color("526471"))
	draw_rect(Rect2(132, 552, 22, 67), Color("536978"))
	draw_colored_polygon(PackedVector2Array([Vector2(132,552),Vector2(202,533),Vector2(202,551),Vector2(154,565)]), Color("637989"))
	draw_line(Vector2(135,552), Vector2(198,535), Color("8495a0"), 3, true)
	draw_rect(Rect2(193, 545, 13, 17), Color("3f535f"))
	var pivot := Vector2(158, 618)
	var tip := pivot + Vector2(40, 0).rotated(controller.faucet_amount * PI * 0.42)
	draw_line(pivot, tip, Color("344b58"), 11, true)
	draw_line(pivot + Vector2(0,-2), tip + Vector2(0,-2), Color("8293a0"), 3, true)
	if controller.faucet_on and controller.world.controls_enabled:
		var catch_pan: bool = controller.under_tap()
		var geometry = preload("res://modules/restaurant/world/pan_geometry.gd")
		var end_y: float = controller.point(geometry.water_center(controller.world.pan_fill_ratio())).y if catch_pan else 731.0
		end_y = maxf(580.0, end_y)
		draw_line(Vector2(200, 562), Vector2(200, end_y), Color("b3dbd1", 0.55 + controller.faucet_amount * 0.4), 2.5 + controller.faucet_amount * 3.0)
		for i in range(6):
			var y: = lerpf(562, end_y, fmod(controller.world._time * 2 + i / 6.0, 1))
			draw_line(Vector2(198, y), Vector2(202, y + 4), Color("f1f5db"), 2)
		if controller.overflowing and catch_pan:
			# Water leaves the low outside edges of the pan and drops into the
			# basin below. Only the accepted volume remains in the pan.
			for side in [-1.0, 1.0]:
				var lip: Vector2 = controller.point(geometry.CENTER + Vector2(side * 111.0, 19.0))
				var drain := Vector2(lip.x - side * 22.0, maxf(741.0, lip.y + 18.0))
				draw_line(lip, drain, Color("9dd7d1", 0.82), 3.0, true)
				draw_arc(drain, 7.0, PI * 0.1, PI * 0.9, 10, Color("b7e2d5", 0.7), 1.7, true)
