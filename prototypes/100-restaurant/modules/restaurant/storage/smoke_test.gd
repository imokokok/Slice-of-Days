extends SceneTree
## Run: godot --headless --path . --script modules/restaurant/storage/smoke_test.gd
const Repository = preload("res://modules/restaurant/storage/recipe_repository.gd")
const Canvas = preload("res://modules/restaurant/ui/poster_canvas.gd")
var failures: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)

func run() -> void:
	var base := "user://after_hours_kitchen_tests/" + Crypto.new().generate_random_bytes(8).hex_encode()
	var repository := Repository.new(base + "/book.json")
	check(repository.load_recipes().is_empty(), "new book should start empty")
	var dish := {"ingredients": [{"id": "tomato", "cut": true, "heat": 7.5}], "quality": 0.8, "tags": ["fresh"]}
	var record := {"title": "测试番茄", "author": "QA", "notes": "切碎后下锅", "dish": dish}
	check(repository.save_recipe(record), "save record: " + repository.last_error)
	var recipes: Array = repository.load_recipes()
	check(recipes.size() == 1, "saved record visible")
	if not recipes.is_empty():
		var recipe_id: String = recipes[0].id
		check(repository.like_recipe(recipe_id), "first like succeeds")
		check(not repository.like_recipe(recipe_id), "duplicate like rejected")
		var reloaded := Repository.new(base + "/book.json")
		check(reloaded.load_recipes().size() == 1 and reloaded.has_liked(recipe_id), "reload preserves likes")
	var full_capacity := record.duplicate(true)
	var capacity_repository := Repository.new(base + "/capacity.json")
	full_capacity.title = "四十八块实际切片"
	full_capacity.dish = {"ingredients": []}
	for index in range(48):
		full_capacity.dish.ingredients.append({"id": "tomato", "cut": true, "heat": 7.5, "batch_uid": "source_%d" % (index / 16)})
	check(capacity_repository.save_recipe(full_capacity), "recipe accepts the kitchen's full 48-piece physical capacity: " + capacity_repository.last_error)
	full_capacity.dish.ingredients.append({"id": "tomato"})
	check(not capacity_repository.save_recipe(full_capacity), "recipe rejects a 49th physical piece")
	check(repository.export_to(base + "/portable.json") == OK, "portable export")
	var second := Repository.new(base + "/other.json")
	var imported: Dictionary = second.import_from(base + "/portable.json")
	check(imported.error.is_empty() and imported.added == 1, "portable import")
	check(second.import_from(base + "/portable.json").added == 0, "duplicate import is idempotent")
	var invalid := record.duplicate(true)
	invalid.dish.ingredients = [{"id": "not_a_real_ingredient"}]
	check(not repository.save_recipe(invalid), "unknown ingredient rejected")
	invalid = record.duplicate(true)
	invalid.thumbnail = "C:/private/photo.png"
	check(not repository.save_recipe(invalid), "external image paths rejected")
	var canvas := Canvas.new()
	get_root().add_child(canvas)
	canvas.size = Vector2(480, 480)
	await process_frame
	await process_frame
	canvas.add_sticker("star")
	canvas.add_sticker("heart")
	canvas.undo()
	check(canvas.stickers.size() == 1, "canvas undo")
	var poster_data: Dictionary = canvas.export_data()
	canvas.clear_canvas()
	check(canvas.stickers.is_empty(), "canvas clear")
	canvas.import_data(poster_data)
	check(canvas.stickers.size() == 1, "canvas roundtrip")
	var points: Array = []
	for index in 100:
		points.append([float(index) / 100.0, 0.5])
	poster_data.strokes = [{"points": points, "color": "284a42ff", "width": 0.01}]
	record.poster = poster_data
	check(repository.save_recipe(record), "poster with 100 points accepted")
	var bad_file := FileAccess.open(base + "/bad.json", FileAccess.WRITE)
	bad_file.store_string("{invalid json")
	bad_file.close()
	check(not second.import_from(base + "/bad.json").error.is_empty(), "malformed import rejected")
	check(second.load_recipes().size() == 1, "invalid import leaves local data unchanged")
	var broken_file := FileAccess.open(base + "/book.json", FileAccess.WRITE)
	broken_file.store_string("{broken")
	broken_file.close()
	var recovered := Repository.new(base + "/book.json")
	check(not recovered.load_recipes().is_empty(), "backup recovery")
	var picture := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	picture.fill(Color("d97468"))
	record.thumbnail = Marshalls.raw_to_base64(picture.save_png_to_buffer())
	check(recovered.save_recipe(record), "save after backup recovery with valid thumbnail")
	canvas.queue_free()
	if failures.is_empty():
		print("STORAGE_AND_POSTER_TESTS_PASSED")
	quit(0 if failures.is_empty() else 1)
