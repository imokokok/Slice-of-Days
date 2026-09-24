extends RefCounted
## Authored street staging in world pixels, shared by drawing and interaction.
## Block boundaries, routes, original textures and save coordinates stay stable.
const CURB := 718.0
const FEET := 820.0
const SIDEWALK_EDGE := 846.0
const ROAD := 863.0
const SHARED_HOME_CANVAS := Vector2(1811, 1280)
const SHARED_HOME_DOOR := Vector2(1060, 1205)
const SHARED_HOME_STAIRS := Vector2(190, 1205)
const SHARED_HOME_PAPER_OPENINGS: Array[Vector2i] = [
	Vector2i(160,1100), Vector2i(205,1060), Vector2i(275,1000),
	Vector2i(315,960), Vector2i(360,935), Vector2i(385,660),
	Vector2i(450,660), Vector2i(525,660), Vector2i(588,660),
	Vector2i(582,553), Vector2i(1280,552),
]

static func rain_amount(day: int, minute: float) -> float:
	# One coastal weather system follows the saved day/time, never a block hash.
	var windows := {2:Vector2(780,1110),3:Vector2(420,630),5:Vector2(630,750)}
	if not windows.has(day): return 0.0
	var span: Vector2=windows[day]
	return smoothstep(span.x,span.x+30,minute)*(1.0-smoothstep(span.y-30,span.y,minute))
const CUTOUTS := {
	"residence": {"size":Vector2(1200,850), "ground":1205.0},
	"dorm": {"size":Vector2(600,500), "ground":1166.0},
	"produce_stall": {"size":Vector2(560,375), "ground":941.0},
	"night_market": {"size":Vector2(620,540), "ground":1193.0},
	"print_shop": {"size":Vector2(690,455), "ground":920.0},
}
const SCENE_WIDTHS := {"bus_stop":620.0, "chess_stall":660.0, "tarot_stall":650.0}

static func center_local(location: String) -> float:
	# Offset each frontage to leave a small social pocket on the open side.
	return float({"produce_stall":710,"tarot_stall":760,"bus_stop":750,"chess_stall":730,"print_shop":770,"night_market":770,"residence":820,"dorm":760}.get(location,800))

static func resident_feet(resident: String) -> float:
	# Residents occupy a shallow second plane, entirely on the paving, while
	# the continuous player path stays clear in the foreground.
	return CURB + 34.0 - float(absi(resident.hash()) % 3) * 4.0

static func cutout_rect(location: String, source: Vector2, center: float) -> Rect2:
	var layout: Dictionary = CUTOUTS[location]
	var scale_value := minf(layout.size.x / source.x, layout.size.y / source.y)
	return Rect2(Vector2(center-source.x*scale_value*.5, CURB-float(layout.ground)*scale_value), source*scale_value)

static func entry_offset(location: String) -> float:
	# Actual doorway / counter centers in the current supplied cutouts.
	match location:
		"residence": return home_entry_offset("B")
		"dorm": return 92.0
		"night_market": return -48.0
		"tarot_stall": return 58.0
		"bus_stop": return 45.0
		"chess_stall": return 66.0
		"print_shop": return 0.0
		"produce_stall": return -65.0
	return 0.0

static func home_entry_offset(role: String) -> float:
	# Upstairs is reached from the left exterior stair; downstairs has its own door.
	var rect := cutout_rect("residence", SHARED_HOME_CANVAS, 0.0)
	var anchor := SHARED_HOME_STAIRS if role == "A" else SHARED_HOME_DOOR
	return rect.position.x + anchor.x * rect.size.x / SHARED_HOME_CANVAS.x

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

static func daylight(minute: float) -> Color:
	# Apply one continuous coastal light cycle to every world element. The
	# transition is driven by the sun's position, rather than a binary dark
	# overlay: morning is cool, late afternoon turns amber, and blue hour fades
	# into the deep marine night palette.
	var t := fposmod(float(minute), 1440.0)
	if t < 330.0:
		return Color("415a78").lerp(Color("667990"), t / 330.0)
	if t < 420.0:
		return Color("667990").lerp(Color("f0c09a"), (t - 330.0) / 90.0)
	if t < 510.0:
		return Color("f0c09a").lerp(Color("fff8df"), (t - 420.0) / 90.0)
	if t < 960.0:
		return Color("fff8df").lerp(Color("fffdf0"), (t - 510.0) / 450.0)
	if t < 1080.0:
		return Color("fffdf0").lerp(Color("f0bd91"), (t - 960.0) / 120.0)
	if t < 1170.0:
		return Color("f0bd91").lerp(Color("8799bf"), (t - 1080.0) / 90.0)
	return Color("8799bf").lerp(Color("415a78"), (t - 1170.0) / 270.0)
