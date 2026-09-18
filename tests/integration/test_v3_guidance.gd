extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"):
		quit(1)
		return
	var state = root.get_node("GameState")
	var residency = root.get_node("ResidencySystem")
	var guidance = root.get_node("GuidanceSystem")
	var locations: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/locations.json")).get("locations", [])
	var community: Dictionary = locations.filter(func(row: Dictionary) -> bool: return str(row.get("id", "")) == "print_shop")[0]
	check(not community.get("hours", []).is_empty() and int(community.hours[0][0]) == 540 and int(community.hours[0][1]) == 1080, "Community center has the authored 09:00–18:00 opening window")
	state.begin_new_game("A")
	state.current_location = "residence"
	state.current_minute = 600
	var first: Dictionary = guidance.next_step()
	check(str(first.get("location", "")) == "print_shop", "Guidance begins with the real starter-packet counter")
	check("领取资料袋" in str(first.get("text", "")), "Guidance names the first actionable task")
	residency.collect_packet()
	for location in ["print_shop", "cafe", "produce_stall"]:
		residency.visit(location)
	var rows: Array = guidance.today_rows()
	check(rows.any(func(row: Dictionary) -> bool: return str(row.get("action", "")) == "organize"), "Today view always links back to nightly organization")
	state.current_location = "produce_stall"
	state.current_minute = 1000
	var forecast: String = guidance.preview(35, "cafe")
	check(forecast.begins_with("预计 "), "Map guidance gives a concrete arrival forecast")
	check(not guidance.known_at("produce_stall").is_empty(), "Known-place guidance remains readable with no hidden prerequisite")
	print("V3 GUIDANCE PASS: %d checks" % checks if failures == 0 else "V3 GUIDANCE FAIL: %d / %d" % [failures, checks])
	quit(failures)
