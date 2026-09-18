extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, title: String) -> void:
	if condition:
		print("PASS ", title)
	else:
		failures += 1
		push_error(title)


func run() -> void:
	var settings = root.get_node("SettingsSystem")
	var original_values: Dictionary = settings.values.duplicate(true)
	settings.values = settings.DEFAULTS.duplicate(true)
	settings.values["language"] = "en"
	settings.apply_settings()

	var packed := load("res://scenes/main_menu.tscn")
	check(packed is PackedScene, "Main menu scene loads")
	if not packed is PackedScene:
		quit(failures)
		return
	var menu = packed.instantiate()
	root.add_child(menu)
	await process_frame

	check(menu.navigation.get_node("NewGame").text == "New Game", "Main navigation starts in saved English")
	check(menu.navigation.get_node("Chapters").text == "Chapters", "Chapter button is translated")
	check(menu.navigation.get_node("Settings").text == "Settings", "Settings button is translated")

	menu._show_settings()
	await process_frame
	var picker: OptionButton = null
	var labels: Array[String] = []
	for child in menu.modal_panel.get_children():
		if child is OptionButton:
			picker = child
		elif child is Label:
			labels.append(child.text)
	check(labels.has("Settings") and labels.has("Language"), "Settings modal is translated to English")
	check(picker != null and picker.get_item_text(0) == "Simplified Chinese" and picker.get_item_text(1) == "English", "Language choices are readable in English")
	if OS.get_cmdline_user_args().has("--capture-localization"):
		await RenderingServer.frame_post_draw
		var screenshot: Image = menu.get_viewport().get_texture().get_image()
		check(screenshot.save_png("/tmp/solmere-settings-en.png") == OK, "English settings screenshot is captured")

	settings.set_language("zh_CN")
	menu._show_settings()
	await process_frame
	labels.clear()
	for child in menu.modal_panel.get_children():
		if child is Label:
			labels.append(child.text)
	check(labels.has("设置") and labels.has("语言"), "Settings modal switches back to Chinese immediately")
	check(menu.navigation.get_node("NewGame").text == "新游戏", "Open navigation retranslates back to Chinese")

	menu.queue_free()
	settings.values = original_values
	settings.apply_settings()
	quit(failures)
