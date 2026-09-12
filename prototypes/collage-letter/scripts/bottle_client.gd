extends Node

var base_url := "http://127.0.0.1:8787"
var token := ""
var player: Dictionary = {}
var identity_path := "user://bottle_identity.json"
var identities: Dictionary = {}
var display_name := "海边来客"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="):
			var profile := arg.trim_prefix("--profile=").validate_filename()
			identity_path="user://bottle_identity_"+profile+".json"
	var config := ConfigFile.new()
	if config.load("res://network.cfg")==OK:
		base_url=str(config.get_value("server","url",base_url)).trim_suffix("/")
	if FileAccess.file_exists(identity_path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(identity_path))
		if data is Dictionary:
			identities=data.get("identities",{})
			base_url=data.get("last_url",base_url)
	select_identity(base_url)

func select_identity(url: String) -> void:
	base_url=url.strip_edges().trim_suffix("/")
	var identity: Dictionary=identities.get(base_url,{})
	token=identity.get("token","")
	display_name=identity.get("name",display_name)
	player={}

func persist() -> void:
	identities[base_url]={"token":token,"name":display_name}
	var file := FileAccess.open(identity_path+".tmp",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"identities":identities,"last_url":base_url}))
		file.close()
		DirAccess.rename_absolute(identity_path+".tmp",identity_path)

func connect_service(url: String, nickname: String) -> Dictionary:
	if not (url.begins_with("http://") or url.begins_with("https://")):
		return {"ok":false,"error":"请输入 http:// 或 https:// 开头的邮局地址。"}
	select_identity(url)
	display_name=nickname.strip_edges().left(24)
	if display_name.is_empty():
		display_name="海边来客"
	if token.is_empty():
		var result: Dictionary=await request("/v1/players",HTTPClient.METHOD_POST,{"name":display_name})
		if not result.ok:
			return result
		token=result.get("token","")
		player=result.get("player",{})
		persist()
	var me: Dictionary=await request("/v1/me")
	if me.ok:
		persist()
	return me

func request(path: String, method: int = HTTPClient.METHOD_GET, body: Dictionary = {}) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout=12
	http.body_size_limit=2_000_000
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not token.is_empty():
		headers.append("Authorization: Bearer "+token)
	var error := http.request(base_url+path,headers,method,JSON.stringify(body) if method!=HTTPClient.METHOD_GET else "")
	if error!=OK:
		http.queue_free()
		return {"ok":false,"error":"无法发起连接，请检查邮局地址。"}
	var response: Array=await http.request_completed
	http.queue_free()
	if response[0]!=HTTPRequest.RESULT_SUCCESS:
		return {"ok":false,"error":"暂时连接不到邮局。作品仍在桌上，请启动服务或检查网络后重试。"}
	var data = JSON.parse_string(response[3].get_string_from_utf8())
	if not data is Dictionary:
		return {"ok":false,"error":"邮局返回了无法识别的内容。"}
	data["ok"]=response[1]>=200 and response[1]<300
	if data.has("player"):
		player=data.player
	return data

func publish(payload: Dictionary) -> Dictionary:
	return await request("/v1/letters",HTTPClient.METHOD_POST,payload)
