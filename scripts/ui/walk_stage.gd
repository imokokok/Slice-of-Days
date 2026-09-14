extends Control
## Shared, directly controlled side-on stage for streets and interiors.
signal moved(world_x: float)

const SPEED := 300.0
const REACH := 85.0
const ACTOR_BASE_HEIGHT := 121.0
const Atlas = preload("res://scripts/ui/scene_atlas.gd")
var player_x := 500.0
var world_width := 1800.0
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

func _ready() -> void:
	WorldSound.set_indoor(indoor)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	var axis := 0.0
	if enabled and DisplayServer.window_is_focused():
		axis = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	move_player(axis, delta, Input.is_physical_key_pressed(KEY_SHIFT))
	queue_redraw()

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
	phase += distance / 30.0
	if int(phase / PI) != previous_step and enabled: WorldSound.play_footstep()
	gait_weight = move_toward(gait_weight, minf(absf(velocity) / SPEED, 1.0) if distance > 0.0 else 0.0, delta * 8.0)
	if distance > 0.0: moved.emit(player_x)
	var camera_target := clampf(player_x - composition_anchor, 0.0, maxf(0.0, world_width - 1600.0))
	camera_x = lerpf(camera_x, camera_target, 1.0 - exp(-5.0 * delta)) if delta > 0.0 else camera_target

func nearest() -> Dictionary:
	var result: Dictionary = {}
	var distance := REACH
	for item in hotspots:
		var gap := absf(float(item.get("x", 0.0)) - player_x)
		if gap < distance:
			distance = gap
			result = item
	return result

func _draw() -> void:
	var night := GameState.current_minute >= 1080
	draw_rect(Rect2(0, 0, 1600, 900), Color("111c2c") if night else Color("687b83"))
	var illustrated := _draw_atlas()
	var ground := 805.0 if not indoor and GameState.current_location == "park" and GameState.current_minute >= 1260 else 713.0
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
		if kind == "person" or kind == "event":
			var shades := [Color("324b62"),Color("567363"),Color("76554c"),Color("ada16b")]
			var shade: Color = shades[absi(str(item.get("id", "")).hash()) % shades.size()]
			_draw_person(Vector2(x, ground), shade, 0.0, -1.0)
		elif kind == "echo" and not illustrated:
			draw_rect(Rect2(x-55,572,110,118),Color("4c4937"))
			draw_rect(Rect2(x-49,580,98,102),Color("203f43"))
			draw_string(ThemeDB.fallback_font,Vector2(x-35,615),"今日的菜",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("f1e6c6"))
		elif kind == "roads" and not illustrated:
			draw_line(Vector2(x, 625),Vector2(x,715),Color("557052"),5)
			draw_colored_polygon(PackedVector2Array([Vector2(x-45,627),Vector2(x+35,627),Vector2(x+55,642),Vector2(x+35,657),Vector2(x-45,657)]),Color("efd39a"))
			draw_string(ThemeDB.fallback_font,Vector2(x-35,649),"小镇路口",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("245664"))
		elif kind == "wait_open" or (kind == "bench" and not illustrated):
			draw_rect(Rect2(x - 40, 679, 80, 8), Color("9a7e60"))
			draw_line(Vector2(x - 30, 687), Vector2(x - 30, 715), Color("776b5f"), 4)
			draw_line(Vector2(x + 30, 687), Vector2(x + 30, 715), Color("776b5f"), 4)
		elif indoor and kind == "object" and not illustrated:
			_draw_furniture(x, str(item.get("prop", "table")))
	_draw_person(Vector2(player_x - camera_x, ground), Color("d69b71") if GameState.current_role == "A" else Color("7da8b5"), sin(phase) * gait_weight, facing, sitting)
	if is_finite(walk_limit) and not illustrated:
		var gate_x := walk_limit - camera_x + 18
		draw_line(Vector2(gate_x, 640), Vector2(gate_x, 718), Color("40544e"), 7)
		draw_line(Vector2(gate_x, 655), Vector2(gate_x + 145, 680), Color("c6b798"), 4)
	var near := nearest()
	if enabled and not near.is_empty():
		var text := "E  ·  " + str(near.get("label", "互动"))
		var font := ThemeDB.fallback_font
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
		var x := clampf(float(near.x) - camera_x - width / 2.0, 32.0, 1568.0 - width)
		var hint_y := maxf(80.0, ground - _actor_height() - 64.0)
		draw_rect(Rect2(x - 16, hint_y, width + 32, 46), Color("10161c", 0.94))
		draw_string(font, Vector2(x, hint_y + 30), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("f5e8d0"))
	# Letterbox framing keeps the world visually separate from optional overlays.
	draw_rect(Rect2(0, 0, 1600, 70), Color("10161c",0.72))

func _draw_atlas() -> bool:
	if indoor:
		var texture := Atlas.plate(Atlas.room(room_kind))
		if texture == null: return false
		draw_texture_rect(texture,Rect2(0,0,1600,900),false)
		return true
	if places.is_empty(): return false
	for i in places.size():
		var place: Dictionary = places[i]
		var left := float(place.x) - 880.0 - camera_x
		if left > 1600 or left + 1760 < 0: continue
		var texture := Atlas.plate(Atlas.street(str(place.id)))
		if texture == null: continue
		# Overlap neighboring plates by 160px. Only the incoming left edge
		# fades, so an opaque previous plate always remains underneath.
		if i == 0:
			draw_texture_rect(texture,Rect2(left,0,1760,900),false)
		else:
			var edge_uv := 160.0 / 1760.0
			# Spatial smoothstep blend: both pictures stay fixed in the same world,
			# with no timed image swap when the player crosses their boundary.
			for strip in 16:
				var a := float(strip) / 16.0
				var b := float(strip + 1) / 16.0
				var ca := Color(1, 1, 1, smoothstep(0.0, 1.0, a))
				var cb := Color(1, 1, 1, smoothstep(0.0, 1.0, b))
				draw_polygon(PackedVector2Array([Vector2(left+a*160,0),Vector2(left+b*160,0),Vector2(left+b*160,900),Vector2(left+a*160,900)]),PackedColorArray([ca,cb,cb,ca]),PackedVector2Array([Vector2(a*edge_uv,0),Vector2(b*edge_uv,0),Vector2(b*edge_uv,1),Vector2(a*edge_uv,1)]),texture)
			draw_texture_rect_region(texture,Rect2(left+160,0,1600,900),Rect2(texture.get_width()*edge_uv,0,texture.get_width()*(1.0-edge_uv),texture.get_height()))
	return true

func _draw_street(night: bool) -> void:
	_draw_sea(night)
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
	draw_string(ThemeDB.fallback_font, Vector2(x - 144, 533), title, HORIZONTAL_ALIGNMENT_CENTER, 288, 22, Color("3d5551"))
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
	draw_string(ThemeDB.fallback_font, Vector2(160, 202), room_name, HORIZONTAL_ALIGNMENT_LEFT, 1000, 30, Color("dac9aa"))
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
			draw_line(Vector2(x, 500), Vector2(x, 718), wood, 8)
			draw_rect(Rect2(x - 120, 516, 240, 35), Color("b5a27a"))
			draw_string(ThemeDB.fallback_font, Vector2(x - 100, 542), "SOLMERE   →", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("3e5350"))

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
	else:
		draw_rect(Rect2(x - 60, 647, 120, 12), Color("a89576"))
		draw_rect(Rect2(x - 26, 623, 48, 24), Color("bdae8f"))
	for side in [-1, 1]:
		draw_line(Vector2(x + side * 50, 657), Vector2(x + side * 50, 718), Color("272c2d"), 6)

func _actor_height() -> float:
	# Double the established scene-relative height at the user's request.
	# Keep the same foot anchor and relative scale between streets and close-ups.
	if indoor: return 640.0
	if GameState.current_location == "park" and GameState.current_minute >= 1260: return 660.0
	return 480.0

func _draw_person(at: Vector2, coat: Color, stride: float, direction: float, seated := false) -> void:
	var actor_scale := _actor_height() / ACTOR_BASE_HEIGHT
	var step := stride * 22.0
	at.y -= absf(stride) * 2.5
	draw_set_transform(at,0,Vector2.ONE * actor_scale)
	draw_colored_polygon(PackedVector2Array([Vector2(-30, 4), Vector2(30, 4), Vector2(55, 10), Vector2(-18, 10)]), Color("070e13", 0.5))
	if seated: at.y += 14.0 * actor_scale
	draw_set_transform(at,0,Vector2((1.0 if direction >= 0.0 else -1.0)*maxf(0.16,absf(direction)),1.0)*actor_scale)
	if seated:
		draw_polyline(PackedVector2Array([Vector2(-9,-48),Vector2(21,-48),Vector2(26,-14)]),Color("19272c"),9,true)
		draw_polyline(PackedVector2Array([Vector2(5,-46),Vector2(35,-43),Vector2(37,-14)]),Color("213138"),9,true)
	else:
		draw_polyline(PackedVector2Array([Vector2(-7, -39), Vector2(-8 + step * 0.35, -20), Vector2(-11 + step, -maxf(0.0, stride) * 8)]), Color("19272c"), 9, true)
		draw_polyline(PackedVector2Array([Vector2(7, -39), Vector2(9 - step * 0.35, -19), Vector2(14 - step, -maxf(0.0, -stride) * 8)]), Color("213138"), 9, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-13, -89), Vector2(12, -89), Vector2(20, -36), Vector2(-19, -36)]), coat)
	draw_line(Vector2(10, -82), Vector2(19 - step * 0.4, -50), coat.darkened(0.18), 8, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -114), Vector2(9, -117), Vector2(12, -97), Vector2(3, -89), Vector2(-10, -96)]), Color("c2a68a"))
	draw_colored_polygon(PackedVector2Array([Vector2(-12, -109), Vector2(-11, -119), Vector2(8, -121), Vector2(13, -112), Vector2(-2, -109), Vector2(-9, -99)]), Color("253039"))
	draw_set_transform(Vector2.ZERO)
