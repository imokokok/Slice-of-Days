extends Node2D

var world: Node2D

func _draw() -> void :
	if is_instance_valid(world):
		world._draw_dispensing_stream(self)
