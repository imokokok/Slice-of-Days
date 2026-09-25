extends SceneTree
const Client = preload("res://scripts/bottle_client.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var client := Client.new()
	root.add_child(client)
	client.identity_path="user://retry_fixture_identity.json"
	client.identities={}
	var result: Dictionary=await client.connect_service(OS.get_environment("COLLAGE_TEST_URL"),"Retry fixture")
	assert(result.ok)
	result=await client.publish({"title":"Only once","caption":"Saved before response failed","request_id":"retry-exact-request-001"})
	assert(result.ok and result.replayed and client.player.reply_required)
	result=await client.publish({"title":"Blocked","caption":"Debt still applies","request_id":"retry-exact-request-002"})
	assert(not result.ok)
	result=await client.request("/test/unavailable")
	assert(not result.ok)
	result=await client.request("/v1/players",HTTPClient.METHOD_POST,{"name":"fail-signup"})
	assert(not result.ok)
	DirAccess.remove_absolute(client.identity_path)
	print("RETRY_CLIENT_PASS: lost publish response replays once; debt enforced; retries bounded; signup never retried")
	quit()
