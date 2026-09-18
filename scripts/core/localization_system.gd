extends Node

signal catalog_loaded(locale: String)

const DEFAULT_LOCALE := "zh_CN"
const SUPPORTED_LOCALES := ["zh_CN", "en"]
const ENGLISH_CATALOG_PATH := "res://localization/en.json"
const ENGLISH_OVERRIDE_PATH := "res://localization/en_overrides.json"

var _english_translation: Translation
var _english_catalog: Dictionary = {}
var _dynamic_cache: Dictionary = {}
var _templates: Array[Dictionary] = []
var _fragment_sources: Array[String] = []
var _placeholder_regex := RegEx.new()


func _enter_tree() -> void:
	_placeholder_regex.compile("%[-+0-9.]*[sdif]|\\{[A-Za-z_][^}]*\\}")
	_load_english_catalog()


func _load_english_catalog() -> void:
	if not FileAccess.file_exists(ENGLISH_CATALOG_PATH):
		push_warning("English localization catalog is missing: %s" % ENGLISH_CATALOG_PATH)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(ENGLISH_CATALOG_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("English localization catalog is not a JSON dictionary")
		return
	if FileAccess.file_exists(ENGLISH_OVERRIDE_PATH):
		var overrides = JSON.parse_string(FileAccess.get_file_as_string(ENGLISH_OVERRIDE_PATH))
		if typeof(overrides) == TYPE_DICTIONARY:
			parsed.merge(overrides, true)
		else:
			push_error("English localization overrides are not a JSON dictionary")
	_english_translation = Translation.new()
	_english_translation.locale = "en"
	for source in parsed:
		var translated := str(parsed[source])
		if translated.is_empty():
			continue
		var source_text := str(source)
		_english_catalog[source_text] = translated
		_english_translation.add_message(source_text, translated)
		if _placeholder_regex.search(source_text) != null:
			var template := _build_template(source_text, translated)
			if not template.is_empty():
				_templates.append(template)
		elif source_text.length() >= 2 and source_text.length() <= 120:
			_fragment_sources.append(source_text)
	_templates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.source).length() > str(b.source).length())
	_fragment_sources.sort_custom(func(a: String, b: String) -> bool:
		return a.length() > b.length())
	TranslationServer.add_translation(_english_translation)
	catalog_loaded.emit("en")


func supports(locale: String) -> bool:
	return SUPPORTED_LOCALES.has(locale)


func text(source: Variant) -> String:
	var source_text := str(source)
	if not TranslationServer.get_locale().begins_with("en"):
		return source_text
	if _english_catalog.has(source_text):
		return str(_english_catalog[source_text])
	if _dynamic_cache.has(source_text):
		return str(_dynamic_cache[source_text])
	var translated := _translate_template(source_text)
	if translated == source_text:
		translated = _translate_fragments(source_text)
	_dynamic_cache[source_text] = translated
	return translated


func text_with_values(source: Variant, values: Variant) -> String:
	var translated := text(source)
	if values is Dictionary:
		return translated.format(values)
	if values is Array:
		return translated % values
	return translated % values


func _build_template(source: String, translated: String) -> Dictionary:
	var matches := _placeholder_regex.search_all(source)
	if matches.is_empty():
		return {}
	var pattern := "^"
	var cursor := 0
	var placeholders: Array[String] = []
	for match_result in matches:
		var start := match_result.get_start()
		pattern += _regex_escape(source.substr(cursor, start - cursor))
		pattern += "(.+?)"
		placeholders.append(match_result.get_string())
		cursor = match_result.get_end()
	pattern += _regex_escape(source.substr(cursor)) + "$"
	var expression := RegEx.new()
	if expression.compile(pattern) != OK:
		return {}
	return {
		"source": source,
		"translated": translated,
		"placeholders": placeholders,
		"expression": expression,
	}


func _translate_template(source: String) -> String:
	for template in _templates:
		var result: RegExMatch = template.expression.search(source)
		if result == null:
			continue
		var captures: Array[String] = []
		for index in range(1, result.get_group_count() + 1):
			captures.append(result.get_string(index))
		return _fill_template(str(template.translated), template.placeholders, captures)
	return source


func _fill_template(template: String, source_placeholders: Array, captures: Array[String]) -> String:
	var result := ""
	var cursor := 0
	var sequential_index := 0
	var target_occurrences: Dictionary = {}
	for target_match in _placeholder_regex.search_all(template):
		var start := target_match.get_start()
		result += template.substr(cursor, start - cursor)
		var target_placeholder := target_match.get_string()
		var wanted_occurrence := int(target_occurrences.get(target_placeholder, 0))
		target_occurrences[target_placeholder] = wanted_occurrence + 1
		var capture_index := -1
		for source_index in source_placeholders.size():
			if source_placeholders[source_index] != target_placeholder:
				continue
			if wanted_occurrence == 0:
				capture_index = source_index
				break
			wanted_occurrence -= 1
		if capture_index < 0:
			capture_index = sequential_index
		if capture_index < captures.size():
			result += captures[capture_index]
		else:
			result += target_placeholder
		sequential_index += 1
		cursor = target_match.get_end()
	result += template.substr(cursor)
	return result


func _translate_fragments(source: String) -> String:
	var translated := source
	for fragment in _fragment_sources:
		if translated.contains(fragment):
			translated = translated.replace(fragment, str(_english_catalog[fragment]))
	return translated


func _regex_escape(value: String) -> String:
	var result := value
	for character in ["\\", ".", "^", "$", "*", "+", "?", "(", ")", "[", "]", "{", "}", "|"]:
		result = result.replace(character, "\\" + character)
	return result
