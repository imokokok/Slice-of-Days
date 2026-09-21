extends SceneTree

var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var state = root.get_node("GameState")
	var chapters = root.get_node("ChapterSystem")
	var travel = root.get_node("TravelSystem")
	chapters.start_new_game("A")
	state.current_minute = 545
	check(not travel.route("residence","park","friend","A",545).available,"Friend ride requires a real relationship")
	root.get_node("RelationshipSystem").add_flags("wu_wu",["ride_offered"])

	var walk: Dictionary = travel.route("residence", "park", "walk", "A", 545)
	var borrowed: Dictionary = travel.route("residence", "park", "friend", "A", 545)
	var taxi: Dictionary = travel.route("residence", "park", "taxi", "A", 545)
	check(walk.available and borrowed.available and taxi.available, "All three travel choices are available")
	check(int(walk.cost) == 0 and int(borrowed.cost) < int(taxi.cost), "Prices increase from walking to borrowed car to taxi")
	check(int(taxi.minutes) < int(borrowed.minutes) and int(borrowed.minutes) < int(walk.minutes), "Travel times decrease from walking to borrowed car to taxi")

	var same_street: Dictionary = travel.route("bus_stop", "print_shop", "taxi", "A", 545)
	var cross_street: Dictionary = travel.route("bus_stop", "library", "taxi", "A", 545)
	check(same_street.available and int(same_street.cost) == 40, "Same-street taxi uses the distance fare")
	check(cross_street.available and int(cross_street.cost) >= 50, "Cross-street taxi costs at least 50")

	check(load("res://scenes/town_map.tscn") is PackedScene, "Standalone map parses")
	check(load("res://scripts/residency/paper_overlay.gd") is GDScript, "Full-width paper map parses")
	var paper = load("res://scripts/residency/paper_overlay.gd").new()
	paper.mode = "map"
	root.add_child(paper)
	await process_frame
	check(paper.body.get_node("MapViewport").size.x == 1284.0, "Map uses the former details-column width")
	check(paper.body.get_node_or_null("MapDetails") == null, "Map opens without the old fixed details column")
	paper._map_select("park")
	await process_frame
	var card: Control = paper.body.get_node("MapDetails")
	check(card.get_node("TravelWalk") is Button and card.get_node("TravelFriend") is Button and card.get_node("TravelTaxi") is Button, "Destination card contains all three travel choices")
	paper.queue_free()
	TranslationServer.set_locale("en")
	var borrowed_label: String = root.get_node("LocalizationSystem").text_with_values("%s · %d 分钟 / %d 元", [root.get_node("LocalizationSystem").text("找人借车"), 18, 20])
	if FileAccess.file_exists("res://localization/en.json"):
		check(borrowed_label == "Borrow a Car · 18 min / ¥20", "Travel choice template is localized")
	else:
		check(borrowed_label == "找人借车 · 18 分钟 / 20 元", "Missing optional English catalog preserves authored travel text")
	TranslationServer.set_locale("zh_CN")
	print("TRAVEL CHOICES ", checks - failures, " checks / ", failures, " failures")
	quit(0 if failures == 0 else 1)
