extends SceneTree
## Representative state-ledger checks added with the high-fidelity interaction spec.

const SauceState = preload("res://modules/restaurant/domain/sauce_state.gd")
const Session = preload("res://modules/restaurant/domain/kitchen_session.gd")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_liquid_ledger()
	_test_menu_and_no_fish_boundary()
	_test_actual_mood_delta()
	_test_noodles_soften_only_in_hot_water()
	_test_customer_conversation_has_six_topics()
	if failures.is_empty():
		print("PASS: high-fidelity state slice, %d checks" % checks)
		quit(0)
	else:
		for failure in failures: push_error(failure)
		print("FAIL: high-fidelity state slice, %d / %d checks" % [failures.size(), checks])
		quit(1)

func _test_liquid_ledger() -> void:
	var ketchup := SauceState.make_batch({"id":"ketchup", "viscosity":0.82}, 30.0, "bottle-a", 0.7)
	var soy := SauceState.make_batch({"id":"soy_sauce", "viscosity":0.31}, 20.0, "bottle-b", 0.4)
	var spoon := SauceState.make_batch({"id":"empty"}, 0.0, "spoon-a", 0.0)
	spoon.composition_ml.clear()
	var before := SauceState.total_components(ketchup) + SauceState.total_components(spoon)
	var moved := SauceState.transfer(ketchup, spoon, 7.5)
	_expect(is_equal_approx(moved, 7.5), "spoon takes the requested available sauce volume")
	_expect(is_equal_approx(before, SauceState.total_components(ketchup) + SauceState.total_components(spoon)), "spoon transfer conserves component volume")
	SauceState.merge_into(spoon, soy, 0.05)
	_expect(bool(spoon.layered) and float(spoon.mixedness) < 0.32, "unagitated sauces remain visibly layered")
	SauceState.agitate(spoon, 0.8)
	_expect(not bool(spoon.layered) and float(spoon.mixedness) >= 0.8, "stirring advances the same sauce batch toward mixed")
	_expect(str(spoon.colour_model) == "weighted_srgb_visual_approximation", "visual colour model identifies itself as an approximation")

func _test_menu_and_no_fish_boundary() -> void:
	var session = Session.new()
	session.setup()
	var ids: Array[String] = []
	for item in session.active_ingredients(): ids.append(str(item.get("id", "")))
	_expect(not ids.has("fish") and not ids.has("salmon"), "active ingredient supply contains no fish")
	_expect(ids.has("shrimp"), "non-fish seafood remains available under the literal no-fish rule")
	session.set_menu_recipes([
		{"title":"番茄小炒", "dish":{"ingredients":[{"id":"tomato"}]}},
		{"title":"旧鱼菜", "dish":{"ingredients":[{"id":"fish"}]}}
	])
	_expect(session._menu_recipes.size() == 1 and session._menu_recipes[0].title == "番茄小炒", "saved fish recipes cannot return fish to the order pool")
	session.start_shift()
	_expect(session.current_customer.has("ordered_recipe") and session.current_customer.ordered_recipe.title == "番茄小炒", "an arriving customer orders from actual saved DIY recipes")

func _test_actual_mood_delta() -> void:
	var session = Session.new()
	session.setup()
	var snapshot := {"quality":1.0, "weirdness":0.0, "tags":["fresh"], "burnt":false, "ingredients":[{"id":"tomato", "heat":7.0}], "cut_count":1, "raw_count":0}
	var review: Dictionary = session._evaluate(snapshot, {"id":"mood-test", "kind":"regular", "mood_before":95, "likes":[], "dislikes":[]})
	_expect(int(review.mood_after) == 100 and int(review.mood_delta) == 5, "mood UI reports the actual clamped change")

func _test_noodles_soften_only_in_hot_water() -> void:
	var session = Session.new()
	session.setup()
	_expect(session.add_ingredient("noodles"), "noodles enter the continuous dish state")
	session.water_ml = 500.0
	session.water_heat = 100.0
	session.tick(4.0)
	var hydrated := float(session.dish[0].get("hydration", 0.0))
	_expect(hydrated > 0.4 and float(session.dish[0].get("softness", 0.0)) > 0.2, "boiling water spreads and softens noodles over time")
	session.water_heat = 40.0
	session.tick(4.0)
	_expect(is_equal_approx(float(session.dish[0].get("hydration", 0.0)), hydrated), "cold water does not continue noodle softening")

func _test_customer_conversation_has_six_topics() -> void:
	var session = Session.new()
	session.setup()
	session.start_shift()
	var lines: Dictionary = {}
	for index in 6:
		lines[session.talk()] = true
	_expect(lines.size() == 6, "each customer offers six distinct conversation topics")
	_expect(bool(session.current_customer.get("preferences_known", false)), "conversation reveals the customer's actual preferences")

func _expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition: failures.append(description)
