extends "main.gd"
# Original 1615f5d mechanics and art. Only isolate host saves by journey/role.
func _ready() -> void:
	var context: Dictionary=get_meta("solmere_context",{})
	var state=get_node_or_null("/root/GameState")
	if state and not context.is_empty():
		var key: String=(str(state.shared_state.get("journey_id","local"))+"_"+str(context.get("current_character","A"))).validate_filename()
		save_path="user://letter_original_"+key+".json"
		preview_path="user://letter_original_"+key+".png"
	await super._ready()
