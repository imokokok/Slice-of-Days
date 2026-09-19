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

	var walk: Dictionary = travel.route("residence", "park", "walk", "A", 545)
	var borrowed: Dictionary = travel.route("residence", "park", "friend", "A", 545)
	var taxi: Dictionary = travel.route("residence", "park", "taxi", "A", 545)
	check(walk.available and borrowed.available and taxi.available, "All three travel choices should be available for a meaningful trip")
	check(int(walk.cost) == 0 and int(borrowed.cost) < int(taxi.cost), "Travel choices should have a clear distance-based price tradeoff")
	check(int(taxi.minutes) < int(borrowed.minutes) and int(borrowed.minutes) < int(walk.minutes), "Taxi, borrowed car, and walking should have ordered travel times")

	var same_street: Dictionary = travel.route("bus_stop", "print_shop", "taxi", "A", 545)
	var cross_street: Dictionary = travel.route("bus_stop", "library", "taxi", "A", 545)
	check(same_street.available and int(same_street.cost) == 40, "A short same-street taxi should use the base fare")
	check(cross_street.available and int(cross_street.cost) >= 50, "A taxi crossing streets should cost at least 50")

	check(load("res://scenes/town_map.tscn") is PackedScene, "The standalone map with three choices should parse")
	check(load("res://scripts/residency/paper_overlay.gd") is GDScript, "The paper map with three choices should parse")
	print("TRAVEL CHOICES ", checks - failures, " checks / ", failures, " failures")
	quit(0 if failures == 0 else 1)
