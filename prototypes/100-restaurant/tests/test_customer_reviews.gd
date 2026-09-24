extends SceneTree
var checks := 0
var failures: Array[String] = []
const Session = preload("res://modules/restaurant/domain/kitchen_session.gd")
func _initialize() -> void:
	var model = Session.new()
	model.setup()
	var voices: Dictionary = {}
	for customer in model.customers:
		model.dish = [{"id":"tomato", "heat":15.0, "cut":false}]
		var result: Dictionary = model._evaluate(model.plate(), customer)
		_expect(result.reason == "burnt" and "番茄" in result.detail, "every customer names the actual burnt ingredient")
		voices[result.feedback] = true
		_expect(not str(result.reaction).is_empty() and not str(result.role).is_empty(), "customer has a visible personality and reaction")
	_expect(voices.size() == model.customers.size(), "all authored customers have distinct voices for the same flaw")
	model.dish = [{"id":"shrimp", "heat":0, "cut":false}]
	var raw: Dictionary = model._evaluate(model.plate(), model.customers[1])
	_expect(raw.reason == "raw" and "整虾" in raw.detail, "uncooked shrimp produces concrete cooking feedback")
	model.dish = [{"id":"tomato", "heat":14.01, "cut":false}]
	_expect(model._evaluate(model.plate(), model.customers[0]).reason == "burnt", "review threshold matches domain burn threshold")
	model.dish = [{"id":"chili", "heat":0, "cut":false}]
	var disliked: Dictionary = model._evaluate(model.plate(), model.customers[0])
	_expect(disliked.reason == "dislike" and "辣椒" in disliked.detail, "specific disliked ingredient is mentioned")
	model.dish = [{"id":"ketchup","heat":0},{"id":"ketchup","heat":0},{"id":"ketchup","heat":0},{"id":"rice","heat":8}]
	var sauce: Dictionary = model._evaluate(model.plate(), model.customers[0])
	_expect(sauce.reason == "seasoning" and "3份" in sauce.detail, "excessive sauce feedback uses actual dish quantities")
	model.dish = [{"id":"rice","heat":8,"cut":true}]
	var good: Dictionary = model._evaluate(model.plate(), model.customers[0])
	_expect(good.reason == "liked" and "米饭" in good.detail and not "番茄" in good.detail, "positive feedback names actual preferred food without stale ingredients")
	var custom := {"id":"host_custom", "name":"外部NPC", "kind":"gourmet", "review_voice":"unknown", "likes":[], "dislikes":[]}
	_expect(not model._evaluate(model.plate(), custom).feedback.is_empty(), "unknown host voice falls back to kind")
	model.start_shift()
	model.current_customer = model.customers[0].duplicate(true)
	var receipt: Dictionary = model.serve()
	_expect(receipt.has("reaction") and receipt.has("detail") and receipt.has("role"), "serve result carries personality fields across module boundary")
	_expect(receipt.payment > 0 and model.dish.is_empty(), "feedback preserves settlement and serving semantics")
	var repo = preload("res://modules/restaurant/storage/recipe_repository.gd").new("user://water_save_%s/book.json" % Time.get_ticks_usec())
	var water_dish := {"ingredients":[{"id":"rice","heat":8}], "water_ml":720.0}
	_expect(repo.save_recipe({"title":"汤饭", "author":"测试", "dish":water_dish}), "actual water quantity saves with the recipe")
	var reload = preload("res://modules/restaurant/storage/recipe_repository.gd").new(repo.storage_path)
	var records: Array = reload.load_recipes()
	_expect(records.size() == 1 and records[0].dish.water_ml == 720, "water quantity survives repository reload")
	for invalid in [-1, 1501, "很多", INF]:
		water_dish.water_ml = invalid
		_expect(not repo._validate_dish(water_dish, false).ok, "malformed or excessive water data is rejected")
	for failure in failures: push_error(failure)
	print("%s: customer reviews, %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
