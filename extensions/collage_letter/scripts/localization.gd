extends RefCounted
static var language := "zh"
static var table: Dictionary = {}
static var keys: Array = []
static var initialized := false
static func initialize() -> void:
	if initialized: return
	initialized=true
	table=JSON.parse_string(FileAccess.get_file_as_string("res://extensions/collage_letter/assets/languages.json"))
	keys=table.keys()
	keys.sort_custom(func(a,b): return a.length()>b.length())
	var config:=ConfigFile.new()
	if config.load("user://letter_language.cfg")==OK: language=config.get_value("language","selected","zh")
	for arg in OS.get_cmdline_user_args():
		if arg in ["--lang=en","--lang=zh"]: language=arg.trim_prefix("--lang=")
static func choose(value: String) -> void:
	language=value
	var config:=ConfigFile.new()
	config.set_value("language","selected",value)
	config.save("user://letter_language.cfg")
static func t(source: String) -> String:
	if language=="zh": return source
	if table.has(source): return str(table[source])
	var result:=source
	for key in keys:
		if result.contains(key): result=result.replace(key,str(table[key]))
	return result
static func material(raw: Dictionary, locale: String) -> Dictionary:
	var data:=raw.duplicate()
	data["display_locale"]=locale
	for field in ["title","headline","body","brand","footer","badge"]:
		var text_locale:=str(raw.get("text_language_zh","zh")) if locale=="zh" and field!="title" else locale
		data[field]=raw.get(field+"_"+text_locale,raw.get(field,""))
	return data
