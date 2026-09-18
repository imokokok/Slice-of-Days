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
	var localization = root.get_node("LocalizationSystem")
	var settings = root.get_node("SettingsSystem")
	var original_values: Dictionary = settings.values.duplicate(true)
	var original_locale := TranslationServer.get_locale()

	TranslationServer.set_locale("zh_CN")
	check(localization.text("设置") == "设置", "Chinese is the source and fallback locale")
	TranslationServer.set_locale("en")
	check(localization.text("设置") == "Settings", "English catalog is registered")
	check(localization.text("第3天") == "Day 3", "Formatted runtime text is localized")
	check(localization.text("7 张照片  ·  12 个景物") == "7 Photos · 12 Scenes", "Repeated placeholder types keep their values in order")

	settings.values = settings.DEFAULTS.duplicate(true)
	check(settings.language() == "zh_CN", "Fresh settings default to Chinese")
	settings.set_language("en")
	check(settings.language() == "en", "Settings accept English")
	check(TranslationServer.get_locale().begins_with("en"), "Changing the setting changes the runtime locale")

	var settings_path := "user://localization_test_settings.json"
	check(settings.save_settings(settings_path), "Language setting can be saved")
	settings.values = settings.DEFAULTS.duplicate(true)
	check(settings.load_settings(settings_path), "Language setting can be loaded")
	check(settings.language() == "en", "Saved English choice survives reload")
	var legacy_path := "user://localization_legacy_settings.json"
	var legacy_file := FileAccess.open(legacy_path, FileAccess.WRITE)
	legacy_file.store_string('{"master_volume": 55}')
	legacy_file.close()
	check(settings.load_settings(legacy_path), "Settings from before localization still load")
	check(settings.language() == "zh_CN", "Legacy settings without a language keep the Chinese default")

	settings.values = original_values
	settings.apply_settings()
	TranslationServer.set_locale(original_locale)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_path))
	quit(failures)
