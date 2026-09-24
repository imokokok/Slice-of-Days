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
		var end_y: = 674.0 if controller.under_tap() else 731.0
		draw_line(Vector2(200, 562), Vector2(200, end_y), Color("b3dbd1", 0.55 + controller.faucet_amount * 0.4), 2.5 + controller.faucet_amount * 3.0)
		for i in range(6):
			var y: = lerpf(562, end_y, fmod(controller.world._time * 2 + i / 6.0, 1))
			draw_line(Vector2(198, y), Vector2(202, y + 4), Color("f1f5db"), 2)
