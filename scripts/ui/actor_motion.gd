extends RefCounted
## Temporary animation adapter. Replace WALK with final authored frames later.
const WALK := [preload("res://art/characters/temporary_walk/step_00.png"), preload("res://art/characters/temporary_walk/step_01.png"), preload("res://art/characters/temporary_walk/step_02.png"), preload("res://art/characters/temporary_walk/step_03.png")]

static func frame_at(distance_phase: float) -> int:
	return posmod(int(floor(distance_phase / (PI * .5))), WALK.size())

static func pose_point(uv: Vector2, size: Vector2, time: float, seed_value: int) -> Vector2:
	# Ankles remain fixed. Only upper-body weight and breathing move, at a
	# different rhythm for each resident; no whole-sprite floating or pulsing.
	var upper := pow(1.0 - uv.y, 2.0)
	var lean := sin(time * .75 + float(seed_value % 29)) * 1.1
	var breath := sin(time * 1.45 + float(seed_value % 17)) * .0018
	return Vector2((uv.x - .5) * size.x + upper * lean, (uv.y - 1.0) * size.y * (1.0 + breath * upper))

static func draw_standing(canvas: CanvasItem, art: Texture2D, extent: Vector2, time: float, seed_value: int) -> void:
	for row in 8:
		var top := float(row) / 8.0
		var bottom := float(row + 1) / 8.0
		var uv := PackedVector2Array([Vector2(0,top),Vector2(1,top),Vector2(1,bottom),Vector2(0,bottom)])
		var points := PackedVector2Array()
		for point in uv: points.append(pose_point(point,extent,time,seed_value))
		canvas.draw_polygon(points,PackedColorArray([Color.WHITE]),uv,art)
