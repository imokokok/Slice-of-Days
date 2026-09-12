extends Node2D
var controller: Node2D
func _draw() -> void :


	# The detailed faucet and lower handle are already part of the sink art.
	# This layer only draws water, so no schematic duplicate can overlap it.
	if controller.faucet_on and controller.world.controls_enabled:
		var end_y: = 700.0
		draw_line(Vector2(211, 610), Vector2(211, end_y), Color("b3dbd1", 0.55 + controller.faucet_amount * 0.4), 2.5 + controller.faucet_amount * 3.0)
		for i in range(6):
			var y: = lerpf(610, end_y, fmod(controller.world._time * 2 + i / 6.0, 1))
			draw_line(Vector2(209, y), Vector2(213, y + 4), Color("f1f5db"), 2)
