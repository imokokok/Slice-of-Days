extends RefCounted
## Authored street staging in world pixels, shared by drawing and interaction.
## Block boundaries, routes, original textures and save coordinates stay stable.
const CURB := 718.0
const FEET := 820.0
const CUTOUTS := {
	"residence": {"size":Vector2(600,500), "ground":1166.0},
	"dorm": {"size":Vector2(600,500), "ground":1166.0},
	"produce_stall": {"size":Vector2(560,375), "ground":941.0},
	"night_market": {"size":Vector2(620,540), "ground":1193.0},
	"print_shop": {"size":Vector2(690,455), "ground":920.0},
}
const SCENE_WIDTHS := {"bus_stop":620.0, "chess_stall":660.0, "tarot_stall":650.0}

static func center_local(location: String) -> float:
	return 710.0 if location == "produce_stall" else 780.0 if location == "tarot_stall" else 800.0

static func cutout_rect(location: String, source: Vector2, center: float) -> Rect2:
	var layout: Dictionary = CUTOUTS[location]
	var scale_value := minf(layout.size.x / source.x, layout.size.y / source.y)
	return Rect2(Vector2(center-source.x*scale_value*.5, CURB-float(layout.ground)*scale_value), source*scale_value)

static func entry_offset(location: String) -> float:
	# Actual doorway / counter centers in the current supplied cutouts.
	match location:
		"residence", "dorm": return 92.0
		"night_market": return -48.0
		"tarot_stall": return 58.0
		"bus_stop": return 45.0
		"chess_stall": return 66.0
		"print_shop": return 0.0
		"produce_stall": return -65.0
	return 0.0

static func npc_offset(location: String, resident: String, index: int) -> float:
	if location == "produce_stall":
		match resident:
			"beetman": return 190.0
			"chenyuan": return 380.0
			"wu_wu": return 520.0
		return [-530.0,-390.0,-220.0][mini(index,2)]
	if location == "bus_stop": return [-210.0,190.0,-410.0][mini(index,2)]
	if location == "chess_stall": return [175.0,370.0,-240.0][mini(index,2)]
	if location == "tarot_stall": return [350.0,-360.0,515.0][mini(index,2)]
	if location == "cafe": return [350.0,515.0,-360.0][mini(index,2)]
	return [-355.0,350.0,515.0][mini(index,2)]

static func argument_offset() -> float:
	return 450.0

static func clear_arrival(desired: float, hotspots: Array, left: float, right: float) -> float:
	# Only used for a new arrival. Never push the player around during walking.
	var bodies: Array[float] = []
	for item in hotspots:
		if str(item.get("kind","")) in ["person","shopkeeper"]: bodies.append(float(item.x))
		elif str(item.get("kind","")) == "argument":
			bodies.append(float(item.x)-70); bodies.append(float(item.x)+70)
	for delta in [0.0,-100.0,100.0,-200.0,200.0,-300.0,300.0]:
		var candidate := clampf(desired+delta,left+80,right-80)
		if bodies.all(func(x: float) -> bool: return absf(x-candidate)>=95): return candidate
	return desired

static func daylight(minute: int) -> Color:
	# Apply light to *every* world element, including generated geometry/actors.
	if minute < 360 or minute >= 1200: return Color("72869c")
	if minute >= 1080: return Color("eed0b5").lerp(Color("72869c"), float(minute-1080)/120.0)
	if minute >= 990: return Color.WHITE.lerp(Color("eed0b5"), float(minute-990)/90.0)
	if minute < 450: return Color("d4dfda").lerp(Color.WHITE, float(minute-360)/90.0)
	return Color.WHITE
