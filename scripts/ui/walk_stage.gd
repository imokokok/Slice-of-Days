extends Control
## Shared, directly controlled side-on stage for streets and interiors.
signal moved(world_x: float)

const SPEED := 300.0
const REACH := 85.0
const ACTOR_BASE_HEIGHT := 121.0
const OUTDOOR_ACTOR_HEIGHT := 184.0
const INDOOR_ACTOR_HEIGHT := 320.0
const Atlas = preload("res://scripts/ui/scene_atlas.gd")
const COAST_ART = preload("res://art/user_scenes/lookout_approach.png")
const CHESS_ART = preload("res://art/user_scenes/chess_stall.png")
const BUS_ART = preload("res://art/user_scenes/bus_stop.png")
var original_resident: Sprite2D
var player_x := 500.0
var world_width := 1800.0
var route_id := ""
var camera_x := 0.0
var composition_anchor := 710.0
var enabled := true
var indoor := false
var walking := false
var sitting := false
var facing := 1.0
var phase := 0.0
var velocity := 0.0
var gait_weight := 0.0
var places: Array[Dictionary] = []
var hotspots: Array[Dictionary] = []
var room_name := ""
var room_kind := ""
var walk_limit := INF
var visual_phase := -1
var lookout_was_open := false

func _ready() -> void:
	original_resident = preload("res://scripts/ui/original_resident.gd").new()
	add_child(original_resident)
	original_resident.hide()
	WorldSound.set_indoor(indoor)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	_sync_original_resident()
	var phase_now := Atlas.phase(GameState.current_minute)
	var lookout_open := GameState.current_minute >= WorldGraph.LOOKOUT_OPEN
	if phase_now != visual_phase or lookout_open != lookout_was_open:
		visual_phase = phase_now
		lookout_was_open = lookout_open
		queue_redraw()
	var previous_player_x := player_x
	var previous_camera_x := camera_x
	var previous_facing := facing
	var previous_gait := gait_weight
	var axis := 0.0
	if enabled and DisplayServer.window_is_focused():
		axis = _walk_axis()
	move_player(axis, delta, Input.is_action_pressed("move_fast"))
	if not is_equal_approx(previous_player_x, player_x) or not is_equal_approx(previous_camera_x, camera_x) or not is_equal_approx(previous_facing, facing) or not is_equal_approx(previous_gait, gait_weight):
		queue_redraw()

func _walk_axis() -> float:
	# SettingsSystem supplies the named actions.  The physical-key fallback keeps
	# the first playable frame responsive even if an old user configuration was
	# created before those actions existed.
	var axis := Input.get_axis("move_left", "move_right")
	if not is_zero_approx(axis):
		return axis
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		return -1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		return 1.0
	return 0.0

func move_player(axis: float, delta: float, hurry := false) -> void:
	var target := axis * SPEED * (1.6 if hurry else 1.0) if enabled and not sitting else 0.0
	if enabled and not is_zero_approx(axis) and not is_equal_approx(facing, signf(axis)):
		velocity = 0.0
		facing = move_toward(facing,signf(axis),delta*12.0)
		target = 0.0
	velocity = move_toward(velocity, target, (1150.0 if axis else 1800.0) * delta)
	if not enabled: velocity = 0.0
	walking = absf(velocity) > 1.0
	var previous := player_x
	player_x = clampf(player_x + velocity * delta, 80.0, minf(world_width - 80.0, walk_limit))
	var distance := absf(player_x - previous)
	var previous_step := int(phase / PI)
	# Tie the gait to distance instead of time so feet do not skate when the
	# character accelerates. A slightly longer step also keeps the walk relaxed.
	phase += distance / 42.0
	if int(phase / PI) != previous_step and enabled: WorldSound.play_footstep()
	gait_weight = move_toward(gait_weight, minf(absf(velocity) / SPEED, 1.0) if distance > 0.0 else 0.0, delta * 8.0)
	if distance > 0.0: moved.emit(player_x)
	var camera_target := clampf(player_x - composition_anchor, 0.0, maxf(0.0, world_width - 1600.0))
	camera_x = lerpf(camera_x, camera_target, 1.0 - exp(-5.0 * delta)) if delta > 0.0 else camera_target

func nearest() -> Dictionary:
	return nearest_of([])

func nearest_of(kinds: Array) -> Dictionary:
	var result: Dictionary = {}
	var distance := REACH
	for item in hotspots:
		if not kinds.is_empty() and str(item.get("kind", "")) not in kinds: continue
		var gap := absf(float(item.get("x", 0.0)) - player_x)
		# A pair can be addressed from beside them, without standing between them.
		if str(item.get("kind","")) == "argument": gap = maxf(0,gap-55)
		if gap < distance:
			distance = gap
			result = item
	return result

func _draw() -> void:
	var night := GameState.current_minute >= 1080
	draw_rect(Rect2(0, 0, 1600, 900), Color("111c2c") if night else Color("687b83"))
	# The lighthouse panorama is a rear layer.  Buildings and trees draw above
	# it, while the road draws last beneath the people in the foreground.
	var illustrated := _draw_atlas() if indoor else true
	if not indoor:
		_draw_global_coast()
		_draw_street_middle()
		_draw_foreground_road()
	var ground := _ground_at(player_x)
	if illustrated:
		pass
	elif indoor:
		_draw_room()
	else:
		_draw_street(night)
	if not illustrated:
		draw_rect(Rect2(0, 718, 1600, 182), Color("d2c29e"))
		for i in range(5):
			draw_line(Vector2(0, 750 + i * 36), Vector2(1600, 750 + i * 36), Color("819084", 0.16), 1)
		draw_line(Vector2(0, 718), Vector2(1600, 718), Color("8d9b96"), 2)
	for item in hotspots:
		var x := float(item.get("x", 0)) - camera_x
		if x < -120 or x > 1720:
			continue
		var kind := str(item.get("kind", ""))
		if kind == "person" or kind == "event" or kind == "shopkeeper":
			if str(item.get("id", "")) == "zhou_xiaoliu": continue
			var shades := [Color("324b62"),Color("567363"),Color("76554c"),Color("ada16b")]
			var shade: Color = shades[absi(str(item.get("id", "")).hash()) % shades.size()]
			_draw_person(Vector2(x, _ground_at(float(item.x))), shade, 0.0, 0.0, -1.0)
		elif kind == "argument":
			_draw_person(Vector2(x-46,ground),Color("718573"),0,0,1)
			_draw_person(Vector2(x+46,ground),Color("a07757"),0,0,-1)
		elif kind == "echo" and not illustrated:
			draw_rect(Rect2(x-55,572,110,118),Color("4c4937"))
			draw_rect(Rect2(x-49,580,98,102),Color("203f43"))
			draw_string(ThemeDB.fallback_font,Vector2(x-35,615),LocalizationSystem.text("今日的菜"),HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("f1e6c6"))
		elif kind == "wait_open" or (kind == "bench" and not illustrated):
			draw_rect(Rect2(x - 40, 679, 80, 8), Color("9a7e60"))
			draw_line(Vector2(x - 30, 687), Vector2(x - 30, 715), Color("776b5f"), 4)
			draw_line(Vector2(x + 30, 687), Vector2(x + 30, 715), Color("776b5f"), 4)
		elif indoor and kind == "object" and not illustrated:
			_draw_furniture(x, str(item.get("prop", "table")))
	_draw_person(Vector2(player_x - camera_x, ground), Color("48535c") if GameState.current_role == "A" else Color("5e9999"), phase, gait_weight, facing, sitting, GameState.current_role)
	if is_finite(walk_limit) and not illustrated:
		var gate_x := walk_limit - camera_x + 18
		draw_line(Vector2(gate_x, 640), Vector2(gate_x, 718), Color("40544e"), 7)
		draw_line(Vector2(gate_x, 655), Vector2(gate_x + 145, 680), Color("c6b798"), 4)

func _draw_atlas() -> bool:
	if indoor:
		var texture := Atlas.plate(Atlas.room(room_kind))
		if texture == null: return false
		draw_texture_rect(texture,Rect2(0,0,1600,900),false)
		return true
	if places.is_empty(): return false
	if route_id == "lookout_route":
		_draw_lookout_approach()
		return true
	for i in places.size():
		var place: Dictionary = places[i]
		var block_width := float(place.get("width", 1600))
		var left := float(place.x) - block_width / 2.0 - camera_x
		if left > 1600 or left + block_width < 0: continue
		if str(place.id) == "chess_stall":
			_draw_chess_stall(left, block_width)
			continue
		if str(place.id) == "bus_stop":
			_draw_bus_stop(left, block_width)
			continue
		var texture := Atlas.plate(Atlas.street(str(place.id)))
		if texture == null: continue
		# Each plate owns one opaque world rectangle. Crop its overscan rather
		# than dissolving two buildings together into a double image.
		var overscan := 80.0 / (block_width + 160.0)
		draw_texture_rect_region(texture, Rect2(left,0,block_width,900),
			Rect2(texture.get_width()*overscan,0,texture.get_width()*(1.0-2.0*overscan),texture.get_height()))
	# A crisp planted divider gives each join a physical edge in the scene.
	# It remains behind the player and never blocks horizontal movement.
	for i in places.size():
		if i == 0 and route_id != "lookout_route": continue
		var seam_x := float(places[i].x) - float(places[i].get("width",1600)) / 2.0 - camera_x
		if seam_x < -90 or seam_x > 1690: continue
		_draw_street_divider(seam_x)
	return true

func _draw_global_coast() -> bool:
	# The panorama is exactly the width of the joined street at this scale
	# (9600×1080 becomes 8000×900).  Moving the camera reveals it naturally and
	# avoids stretching, repeated buildings, or a second background layer.
	var art_width := 900.0 * COAST_ART.get_width() / COAST_ART.get_height()
	var art_rect := Rect2(-camera_x, 0, art_width, 900)
	draw_texture_rect(COAST_ART, art_rect, false, _scene_art_tint())
	return true

func _draw_street_divider(x: float) -> void:
	var ground_offset := _ground_at(x + camera_x) - 713.0
	draw_set_transform(Vector2(0,ground_offset))
	var night := GameState.current_minute >= 1140
	var leaves := Color("344843") if night else Color("596749")
	var leaves_light := Color("42594b") if night else Color("738050")
	draw_rect(Rect2(x-9,570,18,143),Color("4c5142"))
	draw_colored_polygon(PackedVector2Array([Vector2(x,72),Vector2(x-13,200),Vector2(x-31,314),Vector2(x-42,477),Vector2(x-38,605),Vector2(x+23,617),Vector2(x+43,515),Vector2(x+31,348),Vector2(x+13,208)]),leaves)
	draw_colored_polygon(PackedVector2Array([Vector2(x,80),Vector2(x+12,221),Vector2(x+28,392),Vector2(x+23,544),Vector2(x+4,595),Vector2(x-4,403)]),leaves_light)
	draw_rect(Rect2(x-54,675,108,38),Color("7c8070") if night else Color("cabf9e"))
	draw_rect(Rect2(x-59,671,118,8),Color("919381") if night else Color("e2d7b6"))
	draw_set_transform(Vector2.ZERO)

func _ground_at(world_x: float) -> float:
	return 713.0

func _draw_lookout_approach() -> void:
	# One full-height original panorama. Horizontal camera movement reveals it;
	# no replacement sky, road patch, stretched proportions, or overlaid plates.
	var area := coast_art_rect()
	draw_texture_rect(COAST_ART,area,false,_scene_art_tint())

func coast_art_rect() -> Rect2:
	var art_width := 900.0 * COAST_ART.get_width() / COAST_ART.get_height()
	var world_width := float(WorldGraph.config.segments.filter(func(s: Dictionary)->bool:return s.id=="lookout_route")[0].width)
	var progress := clampf(camera_x/maxf(1,world_width-1600),0,1)
	return Rect2(-progress*(art_width-1600),0,art_width,900)

func _scene_art_tint() -> Color:
	match Atlas.phase(GameState.current_minute):
		2: return Color("596c89")
		1: return Color("edc6a4")
	return Color.WHITE

func _sync_original_resident() -> void:
	if not is_instance_valid(original_resident): return
	original_resident.hide()
	for item in hotspots:
		if str(item.get("id","")) != "zhou_xiaoliu": continue
		var at := Vector2(float(item.x)-camera_x,_ground_at(float(item.x)))
		original_resident.stand_at(at,_actor_height(),player_x > float(item.x),_scene_art_tint())
		original_resident.visible = at.x > -120 and at.x < 1720
		break

func _draw_bus_stop(left: float, width: float) -> void:
	var tint := _scene_art_tint()
	draw_rect(Rect2(left,0,width,900),Color("88bcd1") * tint)
	# Preserve PNG transparency and align the shelter feet with the walk line.
	var art_height := width * BUS_ART.get_height() / BUS_ART.get_width()
	var art_top := 713.0 - art_height * (920.0 / 1080.0)
	draw_texture_rect(BUS_ART,Rect2(left,art_top,width,art_height),false,tint)

func _draw_chess_stall(left: float, width: float) -> void:
	# The user's PNG has real transparency: keep the cloth and branches intact,
	# with the same walk line and actor scale as the rest of the cultural street.
	var tint := _scene_art_tint()
	draw_rect(Rect2(left,0,width,900),Color("b8d8db") * tint)
	draw_rect(Rect2(left,440,width,273),Color("729ea2") * tint)
	draw_rect(Rect2(left,580,width,133),Color("c0c6af") * tint)
	draw_rect(Rect2(left,713,width,187),Color("d2c29e") * tint)
	var art_size := Vector2(1120,630)
	var art_origin := Vector2(left+(width-art_size.x)*0.5,713-art_size.y*0.95)
	draw_texture_rect(CHESS_ART,Rect2(art_origin,art_size),false,tint)

func _draw_street(night: bool) -> void:
	_draw_sea(night)
	_draw_street_middle()
	_draw_foreground_road()

func _draw_street_middle() -> void:
	for i in places.size():
		var place: Dictionary = places[i]
		var x := float(place.x) - camera_x
		if x < -700 or x > 2300: continue
		if not bool(place.get("interior", true)):
			_draw_outdoor(x, str(place.get("kind", "street")))
			continue
		_draw_facade(x, str(place.get("kind", "")), str(place.get("name", "")))
		if i % 2 == 0: _draw_tree(x + 370, 718, 0.72)
	# Low foreground grasses pass faster than the distant coastal scenery.
	for i in range(7):
		var x := float(i) * 290.0 - fmod(camera_x * 1.08, 290.0)
		draw_line(Vector2(x, 718), Vector2(x - 15, 696), Color("455d55"), 2)
		draw_line(Vector2(x, 718), Vector2(x + 11, 692), Color("455d55"), 2)

func _draw_foreground_road() -> void:
	# A dedicated foreground road hides the bottom of the middle layer and
	# keeps the player's feet anchored to one continuous walk surface.
	draw_rect(Rect2(0, 718, 1600, 182), Color("202120", 0.96))
	draw_line(Vector2(0, 718), Vector2(1600, 718), Color("e3bd59", 0.85), 3)
	for i in range(9):
		var x := fmod(float(i) * 235.0 - camera_x * 0.12, 1880.0) - 120.0
		draw_line(Vector2(x, 806), Vector2(x + 126, 806), Color("a38b5b", 0.18), 2)

func _draw_sea(night: bool) -> void:
	var sky := Color("3862d0") if not night else Color("243647")
	draw_rect(Rect2(0, 70, 1600, 648), sky)
	var offset := fmod(camera_x * 0.018, 110.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-150 - offset, 470), Vector2(190 - offset, 299), Vector2(351 - offset, 312), Vector2(479 - offset, 416), Vector2(719 - offset, 349), Vector2(950 - offset, 423), Vector2(1148 - offset, 248), Vector2(1360 - offset, 254), Vector2(1690 - offset, 459), Vector2(1690, 610), Vector2(-150, 610)]), Color("85bac6") if not night else Color("354e60"))
	draw_colored_polygon(PackedVector2Array([Vector2(-100, 500), Vector2(125, 463), Vector2(390, 487), Vector2(730, 415), Vector2(910, 479), Vector2(1190, 426), Vector2(1680, 509), Vector2(1680, 622), Vector2(-100, 622)]), Color("4d9fab"))
	draw_rect(Rect2(0, 511, 1600, 207), Color("267fb0") if not night else Color("365e75"))
	for i in range(16):
		var x := float(i) * 118 - fmod(camera_x * 0.028, 118.0)
		var y := 551 + i % 4 * 28
		draw_line(Vector2(x, y), Vector2(x + 54, y), Color("cad4c9", 0.36), 2)
	# A small distant settlement remains scenery, never an extra playable location.
	for i in range(8):
		var x := 1020 + i * 32.0 - offset
		var y := 476 - i % 4 * 13.0
		draw_rect(Rect2(x, y - 27, 27, 34), Color("b5b39b"))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 2, y - 27), Vector2(x + 13, y - 40), Vector2(x + 30, y - 27)]), Color("8c8172"))
	draw_rect(Rect2(0, 705, 1600, 13), Color("efdfb5"))

func _draw_facade(x: float, kind: String, title: String) -> void:
	var wall := Color("eee0b9")
	if kind in ["post", "restaurant", "records"]: wall = Color("cd9374")
	elif kind in ["bookstore", "tarot"]: wall = Color("82bdb1")
	var height := 333.0 if kind in ["home_a", "home_b", "community"] else 288.0
	var roof := 718 - height
	draw_rect(Rect2(x - 290, roof, 580, height), wall)
	draw_rect(Rect2(x + 251, roof, 39, height), wall.darkened(0.13))
	draw_colored_polygon(PackedVector2Array([Vector2(x - 310, roof), Vector2(x - 270, roof - 35), Vector2(x + 266, roof - 35), Vector2(x + 308, roof)]), Color("526360"))
	draw_rect(Rect2(x - 283, roof + 9, 570, 8), Color("d0c4a7"))
	if kind in ["home_a", "home_b", "community"]:
		for side in [-1, 1]:
			var wx: float = x + side * 137
			draw_rect(Rect2(wx - 32, roof + 37, 64, 76), Color("697f7b"))
			draw_rect(Rect2(wx - 45, roof + 37, 10, 76), Color("52675e"))
			draw_rect(Rect2(wx + 35, roof + 37, 10, 76), Color("52675e"))
	for side in [-1, 1]:
		var wx: float = x + side * 160
		draw_rect(Rect2(wx - 67, 558, 134, 132), Color("247d87"))
		draw_colored_polygon(PackedVector2Array([Vector2(wx - 59, 565), Vector2(wx + 59, 565), Vector2(wx + 59, 623), Vector2(wx - 59, 678)]), Color("c8b98f", 0.7))
		draw_line(Vector2(wx, 557), Vector2(wx, 690), wall.darkened(0.2), 7)
		draw_line(Vector2(wx - 67, 622), Vector2(wx + 67, 622), wall.darkened(0.2), 5)
		draw_rect(Rect2(wx - 74, 690, 148, 7), Color("d0c4a7"))
		draw_rect(Rect2(wx - 32, 664, 64, 5), Color("626354"))
		if kind == "records":
			for k in range(3): draw_circle(Vector2(wx - 38 + k * 38, 651), 13, Color("334949"))
		elif kind == "bookstore":
			for k in range(5): draw_rect(Rect2(wx - 44 + k * 19, 639 - k % 2 * 6, 15, 25 + k % 2 * 6), Color("b49c76"))
	draw_rect(Rect2(x - 48, 560, 96, 158), Color("205867"))
	draw_rect(Rect2(x - 36, 573, 72, 115), Color("398d9b"))
	draw_line(Vector2(x + 23, 641), Vector2(x + 23, 664), Color("d8c49d"), 3)
	draw_rect(Rect2(x - 149, 508, 298, 36), Color("cec0a0"))
	draw_string(ThemeDB.fallback_font, Vector2(x - 144, 533), LocalizationSystem.text(title), HORIZONTAL_ALIGNMENT_CENTER, 288, 22, Color("3d5551"))
	if kind in ["restaurant", "grocery", "records"]:
		draw_colored_polygon(PackedVector2Array([Vector2(x - 258, 544), Vector2(x + 258, 544), Vector2(x + 278, 562), Vector2(x - 278, 562)]), Color("a5ad60"))
	if kind == "post":
		draw_rect(Rect2(x + 250, 632, 37, 80), Color("9a715d"))
		draw_rect(Rect2(x + 255, 648, 27, 5), Color("3e5450"))
	# A single lighting vocabulary across every facade.
	for side in [-1, 1]:
		var lx: float = x + side * 268
		draw_line(Vector2(lx, 521), Vector2(lx, 560), Color("405651"), 3)
		draw_colored_polygon(PackedVector2Array([Vector2(lx - 8, 558), Vector2(lx + 8, 558), Vector2(lx + 6, 580), Vector2(lx - 6, 580)]), Color("d9c494"))

func _draw_tree(x: float, ground: float, scale_value: float) -> void:
	draw_set_transform(Vector2(x, ground), 0, Vector2.ONE * scale_value)
	draw_colored_polygon(PackedVector2Array([Vector2(-20, 0), Vector2(12, 0), Vector2(5, -150), Vector2(30, -267), Vector2(10, -271), Vector2(-13, -163)]), Color("3e5a51"))
	draw_line(Vector2(-8, -155), Vector2(-80, -251), Color("3e5a51"), 11)
	draw_colored_polygon(PackedVector2Array([Vector2(-157, -251), Vector2(-107, -357), Vector2(-14, -373), Vector2(67, -343), Vector2(125, -237), Vector2(65, -204), Vector2(-61, -212)]), Color("797831"))
	draw_colored_polygon(PackedVector2Array([Vector2(-107, -357), Vector2(-14, -373), Vector2(67, -343), Vector2(13, -281), Vector2(-81, -275)]), Color("9a9947"))
	draw_set_transform(Vector2.ZERO)

func _draw_room() -> void:
	draw_rect(Rect2(0, 100, 1600, 618), Color("51564f"))
	draw_rect(Rect2(90, 160, 1420, 480), Color("e2c59b"))
	for x in [300, 1100]:
		draw_rect(Rect2(x, 250, 210, 225), Color("7bb9bd"))
		draw_rect(Rect2(x + 8, 260, 194, 207), Color("314855"))
		draw_line(Vector2(x + 105, 250), Vector2(x + 105, 475), Color("a5a18d"), 7)
		draw_line(Vector2(x, 365), Vector2(x + 210, 365), Color("a5a18d"), 7)
		draw_colored_polygon(PackedVector2Array([Vector2(x + 210, 475), Vector2(x, 475), Vector2(x - 130, 718), Vector2(x + 330, 718)]), Color("dcceb0", 0.07))
	draw_rect(Rect2(55, 540, 65, 178), Color("18282e"))
	draw_string(ThemeDB.fallback_font, Vector2(160, 202), LocalizationSystem.text(room_name), HORIZONTAL_ALIGNMENT_LEFT, 1000, 30, Color("dac9aa"))
	draw_line(Vector2(800, 100), Vector2(800, 325), Color("18282e"), 3)
	draw_colored_polygon(PackedVector2Array([Vector2(770, 350), Vector2(790, 325), Vector2(810, 325), Vector2(830, 350)]), Color("d0b585"))
	_draw_room_details()

func _draw_outdoor(x: float, kind: String) -> void:
	var wood := Color("48554e")
	match kind:
		"chess":
			# Composition from the supplied sketch: trees, suspended board-cloths, low table.
			draw_colored_polygon(PackedVector2Array([Vector2(x - 350, 718), Vector2(x - 260, 718), Vector2(x - 300, 535), Vector2(x - 348, 420), Vector2(x - 355, 225), Vector2(x - 376, 208), Vector2(x - 370, 450)]), wood)
			draw_line(Vector2(x - 335, 425), Vector2(x + 310, 460), wood, 12)
			draw_line(Vector2(x - 350, 397), Vector2(x - 442, 286), wood, 9)
			draw_line(Vector2(x + 300, 718), Vector2(x + 325, 355), wood, 10)
			for i in range(3):
				var left := x - 220 + i * 160
				var top := 440.0 + i * 16
				var cloth := Color("d7d0b8") if i == 2 else (Color("52665e") if i == 0 else Color("b0b9a4"))
				draw_colored_polygon(PackedVector2Array([Vector2(left, top), Vector2(left + 225, top + 13), Vector2(left + 237, top + 187), Vector2(left - 8, top + 175)]), cloth)
				for line in range(7):
					draw_line(Vector2(left + 20 + line * 30, top + 20), Vector2(left + 25 + line * 30, top + 163), Color("7b8978"), 2)
					draw_line(Vector2(left + 15, top + 22 + line * 23), Vector2(left + 210, top + 33 + line * 23), Color("7b8978"), 2)
			draw_rect(Rect2(x - 105, 684, 210, 15), wood)
			draw_rect(Rect2(x - 84, 699, 12, 19), wood)
			draw_rect(Rect2(x + 72, 699, 12, 19), wood)
			draw_rect(Rect2(x - 171, 702, 44, 14), Color("71674f"))
			draw_rect(Rect2(x + 127, 702, 44, 14), Color("71674f"))
		"bus":
			for i in range(4):
				var post := x - 190 + i * 133.0
				draw_line(Vector2(post, 452), Vector2(post, 718), wood, 7)
				if i < 3: draw_rect(Rect2(post + 12, 475, 109, 210), Color("c0cfcc", 0.32))
			draw_colored_polygon(PackedVector2Array([Vector2(x - 224, 456), Vector2(x - 195, 424), Vector2(x + 210, 424), Vector2(x + 236, 456)]), Color("c6c4ab"))
			for line in range(3): draw_rect(Rect2(x - 161, 639 + line * 16, 330, 9), wood)
			draw_rect(Rect2(x - 180, 687, 367, 11), wood)
			draw_line(Vector2(x - 145, 690), Vector2(x - 145, 718), wood, 8)
			draw_line(Vector2(x + 145, 690), Vector2(x + 145, 718), wood, 8)
			draw_line(Vector2(x - 304, 464), Vector2(x - 304, 718), wood, 5)
			draw_circle(Vector2(x - 304, 437), 34, Color("647c79"))
			draw_string(ThemeDB.fallback_font, Vector2(x - 325, 445), "BUS", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("f0e3c8"))
			draw_rect(Rect2(x - 259, 653, 38, 65), Color("788478"))
			# The Solmere direction sign belongs beside the station, on its right.
			var sign_post_x := x + 284.0
			draw_rect(Rect2(sign_post_x, 500, 9, 218), wood)
			draw_rect(Rect2(x + 244, 516, 304, 55), Color("b5a27a"))
			draw_string(ThemeDB.fallback_font, Vector2(x + 266, 553), "SOLMERE   →", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("3e5350"))
		"street":
			pass
		"lookout":
			for i in range(8): draw_line(Vector2(x - 340 + i * 96, 613), Vector2(x - 340 + i * 96, 715), wood, 5)
			draw_line(Vector2(x - 350, 626), Vector2(x + 350, 626), wood, 6)
			draw_line(Vector2(x, 658), Vector2(x - 45, 718), wood, 5)
			draw_line(Vector2(x, 658), Vector2(x + 45, 718), wood, 5)
			draw_line(Vector2(x - 30, 651), Vector2(x + 30, 622), Color("b7aa8b"), 19)
		"produce":
			for side in [-1, 1]: draw_line(Vector2(x + side * 180, 487), Vector2(x + side * 180, 718), wood, 6)
			draw_colored_polygon(PackedVector2Array([Vector2(x - 215, 511), Vector2(x - 170, 455), Vector2(x + 170, 455), Vector2(x + 215, 511)]), Color("b0875c"))
			draw_rect(Rect2(x - 188, 654, 376, 64), Color("a18c68"))
			for i in range(12):
				var px := x - 166 + i * 29
				if i < 7: draw_circle(Vector2(px, 643), 13, Color("839657") if i % 2 == 0 else Color("b17c4c"))
				else: draw_rect(Rect2(px, 624, 20, 30), Color("abb4a1"))
		"parking":
			for side in [-1, 1]:
				var px: float = x + side * 190
				draw_rect(Rect2(px - 110, 636, 220, 60), Color("829695") if side == -1 else Color("ae977c"))
				draw_colored_polygon(PackedVector2Array([Vector2(px - 90, 636), Vector2(px - 55, 597), Vector2(px + 50, 597), Vector2(px + 94, 636)]), Color("8b9e9f"))
				for wheel in [-1, 1]: draw_circle(Vector2(px + wheel * 69, 701), 16, Color("364345"))
		_:
			pass

func _draw_room_details() -> void:
	if room_kind in ["record_shop", "public_archive", "grocery", "letter_office"]:
		for row in range(3):
			var y := 395 + row * 69
			draw_rect(Rect2(570, y + 48, 450, 9), Color("685c48"))
			for col in range(12):
				var x := 578 + col * 36
				if room_kind == "record_shop":
					draw_rect(Rect2(x, y + 7, 31, 39), Color("b8a984"))
					draw_circle(Vector2(x + 15, y + 26), 12, Color("344743"))
					draw_circle(Vector2(x + 15, y + 26), 4, Color("cbb183"))
				else:
					draw_rect(Rect2(x, y + col % 3 * 5, 28, 46 - col % 3 * 5), [Color("718275"), Color("b48865"), Color("c1b18b")][col % 3])
	elif room_kind in ["home_a", "home_b"]:
		for i in range(5):
			var x := 595 + i * 57
			var y := 456 + (i % 3 * 19 if room_kind == "home_a" else 0)
			draw_rect(Rect2(x, y, 42, 39), Color("ddceaa"))
			draw_line(Vector2(x + 8, y + 15), Vector2(x + 33, y + 15), Color("94a48f"), 3)
	elif room_kind == "restaurant":
		draw_rect(Rect2(576, 412, 447, 188), Color("86785d"))
		for i in range(6):
			draw_line(Vector2(610 + i * 68, 440), Vector2(610 + i * 68, 475), Color("cab996"), 2)
			draw_circle(Vector2(610 + i * 68, 499), 22, Color("566961"))
	else:
		draw_rect(Rect2(600, 411, 366, 194), Color("c6b68e"))
		for i in range(5): draw_rect(Rect2(622 + i * 61, 448 + i % 2 * 29, 47, 67), Color("8c9a7e"))

func _draw_furniture(x: float, prop: String) -> void:
	if prop == "bed":
		draw_rect(Rect2(x - 94, 662, 188, 31), Color("c0b298"))
		draw_rect(Rect2(x - 84, 650, 42, 13), Color("e6d9b9"))
		draw_rect(Rect2(x - 34, 659, 130, 34), Color("638386"))
	elif prop == "computer":
		draw_rect(Rect2(x - 70, 647, 140, 12), Color("a89576"))
		draw_rect(Rect2(x - 45, 585, 90, 58), Color("27363a"))
		draw_rect(Rect2(x - 38, 592, 76, 43), Color("78a8aa"))
		draw_rect(Rect2(x - 24, 659, 82, 10), Color("c8b99a"))
	else:
		draw_rect(Rect2(x - 60, 647, 120, 12), Color("a89576"))
		draw_rect(Rect2(x - 26, 623, 48, 24), Color("bdae8f"))
	for side in [-1, 1]:
		draw_line(Vector2(x + side * 50, 657), Vector2(x + side * 50, 718), Color("272c2d"), 6)

func _actor_height() -> float:
	# Interior plates use a much closer camera than the joined outdoor world.
	# Give every actor in the room the same larger scale so they read as adults
	# beside the authored chairs and tables, while streets keep their wide-shot
	# proportions.
	return INDOOR_ACTOR_HEIGHT if indoor else OUTDOOR_ACTOR_HEIGHT

func _draw_person(at: Vector2, coat: Color, gait_phase: float, gait_strength: float, direction: float, seated := false, role := "") -> void:
	var actor_scale := _actor_height() / ACTOR_BASE_HEIGHT
	var strength := clampf(gait_strength, 0.0, 1.0)
	var bob := (1.0 - absf(cos(gait_phase))) * 0.7 * strength
	var facing_sign := 1.0 if direction >= 0 else -1.0
	draw_set_transform(at, 0, Vector2.ONE * actor_scale)
	draw_colored_polygon(PackedVector2Array([Vector2(-19,1),Vector2(-11,-1),Vector2(19,0),Vector2(25,4),Vector2(9,6),Vector2(-17,4)]),Color("112630",0.23))
	var origin := at + Vector2(0, (-bob + (15.0 if seated else 0.0)) * actor_scale)
	draw_set_transform(origin, 0, Vector2(facing_sign * lerpf(0.72, 1.0, absf(direction)), 1) * actor_scale)
	var cloth := Color("39484e") if role == "A" else Color("648180") if role == "B" else coat.darkened(0.2)
	var shadow := cloth.darkened(0.2)
	var trousers := Color("29383e")
	var skin := Color("9b9d8c")
	var hair := Color("29383b")
	# Long, quiet shapes: adult proportions and no eyes, mouth or nose details.
	if seated:
		_draw_jointed_limb(Vector2(-4,-49),Vector2(22,-45),Vector2(26,-16),6.5,trousers.darkened(0.12))
		_draw_shoe(Vector2(26,-15),1,Color("223137"))
		_draw_jointed_limb(Vector2(4,-49),Vector2(29,-43),Vector2(34,-16),7,trousers)
		_draw_shoe(Vector2(34,-15),1,Color("223137"))
	else:
		_draw_walking_leg(gait_phase + PI,strength,-4,trousers.darkened(0.12),Color("223137"))
		_draw_walking_leg(gait_phase,strength,4,trousers,Color("223137"))
	var swing := sin(gait_phase) * 8.0 * strength if not seated else -10.0
	_draw_jointed_limb(Vector2(-7,-88),Vector2(-8-swing*0.4,-69),Vector2(-5-swing,-51),5.5,shadow)
	draw_rect(Rect2(-4,-103,6,13),skin.darkened(0.16))
	draw_colored_polygon(PackedVector2Array([Vector2(-6,-95),Vector2(-12,-88),Vector2(-11,-69),Vector2(-14,-44 if role == "A" else -51),Vector2(12,-46 if role == "A" else -51),Vector2(9,-73),Vector2(10,-89),Vector2(3,-95)]),cloth)
	draw_colored_polygon(PackedVector2Array([Vector2(-10,-88),Vector2(-5,-90),Vector2(-4,-49),Vector2(-13,-46 if role == "A" else -51)]),shadow)
	# A's satchel and B's small backpack distinguish the two silhouettes.
	if role == "A":
		draw_line(Vector2(5,-92),Vector2(-12,-58),Color("8d7860"),1.8,true)
		draw_colored_polygon(PackedVector2Array([Vector2(-19,-65),Vector2(-8,-65),Vector2(-8,-49),Vector2(-20,-50)]),Color("75614c"))
	elif role == "B":
		draw_colored_polygon(PackedVector2Array([Vector2(-13,-88),Vector2(-20,-83),Vector2(-20,-63),Vector2(-11,-59)]),Color("34474c"))
	var hand := Vector2(8+swing,-52)
	_draw_jointed_limb(Vector2(6,-88),Vector2(7+swing*0.35,-70),hand,5.8,cloth.lightened(0.035))
	draw_line(hand,hand+Vector2(0,4),skin,3.5,true)
	draw_colored_polygon(PackedVector2Array([Vector2(-7,-117),Vector2(-2,-121),Vector2(5,-119),Vector2(8,-112),Vector2(7,-104),Vector2(2,-100),Vector2(-5,-104),Vector2(-8,-111)]),skin)
	draw_colored_polygon(PackedVector2Array([Vector2(-8,-111),Vector2(-7,-118),Vector2(-2,-122),Vector2(5,-120),Vector2(7,-116),Vector2(-1,-117),Vector2(-3,-108),Vector2(-5,-104)]),hair)
	draw_set_transform(Vector2.ZERO)

func _draw_walking_leg(cycle: float, strength: float, hip_x: float, trouser: Color, shoe: Color) -> void:
	var swing := sin(cycle) * 12.0 * strength
	var lift := maxf(0, cos(cycle)) * 4.5 * strength
	var hip := Vector2(hip_x,-49)
	var foot := Vector2(hip_x+swing,-lift)
	var knee := Vector2(hip_x+swing*0.4+2,-26-lift*0.2)
	_draw_jointed_limb(hip,knee,foot,7.0,trouser)
	_draw_shoe(foot,1.0-lift/22.0,shoe)

func _draw_jointed_limb(start: Vector2, joint: Vector2, finish: Vector2, width: float, color: Color) -> void:
	draw_line(start,joint,color,width,true)
	draw_circle(joint,width*0.5,color)
	draw_line(joint,finish,color,width*0.85,true)

func _draw_shoe(at: Vector2, flatten: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([at+Vector2(-3,-3*flatten),at+Vector2(3,-3*flatten),at+Vector2(8,0),at+Vector2(7,2),at+Vector2(-3,2)]),color)
