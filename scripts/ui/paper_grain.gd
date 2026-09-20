extends Control
## Quiet deterministic paper fibres; never intercepts the object's controls.
func _ready() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	resized.connect(queue_redraw)
func _draw() -> void:
	if size.x<120 or size.y<80: return
	var rng := RandomNumberGenerator.new(); rng.seed=73
	for i in mini(1500,int(size.x*size.y/360)):
		var p := Vector2(rng.randf_range(3,size.x-3),rng.randf_range(3,size.y-3))
		draw_line(p,p+Vector2(rng.randf_range(.5,2.5),.3),Color("31658b",.035),.7,true)
	var points := PackedVector2Array()
	for i in 25: points.append(Vector2(3+(size.x-6)*i/24.0,3+sin(i*2.7)*.65))
	draw_polyline(points,Color("31658b",.14),.8,true)
