extends Node
## Derived from the actual scene/modal stack, never a second gameplay state.
signal changed(state: String)
var last := ""
const POLICIES := {
	"EXPLORATION":{"world_time":true,"move":true,"notebook":true,"notify":true},
	"DIALOGUE":{"world_time":false,"move":false,"notebook":false,"notify":false},
	"INTERACTION":{"world_time":false,"move":false,"notebook":false,"notify":false},
	"CAMERA":{"world_time":false,"move":false,"notebook":false,"notify":false},
	"RECORDER":{"world_time":true,"move":true,"notebook":false,"notify":false},
	"NOTEBOOK":{"world_time":false,"move":false,"notebook":true,"notify":false},
	"ARCHIVE":{"world_time":false,"move":false,"notebook":true,"notify":false},
	"MAP":{"world_time":false,"move":false,"notebook":true,"notify":false},
	"TRAVEL":{"world_time":false,"move":false,"notebook":false,"notify":false},
	"MINIGAME":{"world_time":false,"move":false,"notebook":false,"notify":false},
	"MEMORY":{"world_time":false,"move":true,"notebook":false,"notify":false},
	"PAUSE":{"world_time":false,"move":false,"notebook":false,"notify":false}}
func current() -> String:
	if get_tree().paused: return "PAUSE"
	if SceneRouter.transitioning: return "TRAVEL"
	if has_node("/root/GlobalRecorder") and GlobalRecorder.focused(): return "NOTEBOOK" if is_instance_valid(GlobalRecorder.collection) else "RECORDER"
	for node in get_tree().get_nodes_in_group("memory_space"): if is_instance_valid(node): return "MEMORY"
	var scene := get_tree().current_scene
	if is_instance_valid(scene):
		for property in ["room_dialogue","event_overlay"]:
			var dialogue: Variant=scene.get(property)
			if is_instance_valid(dialogue) and dialogue is CanvasItem and dialogue.visible: return "DIALOGUE"
		if scene.scene_file_path in ["res://scenes/native_module_game.tscn","res://scenes/extension_host.tscn"]: return "MINIGAME"
		var shell := scene.get_node_or_null("GameplayShell")
		if shell!=null:
			var overlay: Variant=shell.get("overlay")
			if is_instance_valid(overlay):
				return {"pause":"PAUSE","settings":"PAUSE","dossier":"ARCHIVE","map":"MAP"}.get(str(overlay.mode),"NOTEBOOK")
			var tool: Variant=shell.get("tool")
			if is_instance_valid(tool): return "RECORDER" if tool.is_in_group("mobile_recorder") else "CAMERA"
	if not get_tree().get_nodes_in_group("meta_dialogue").is_empty(): return "DIALOGUE"
	if MetaExperience.modal_open(): return "INTERACTION"
	return "EXPLORATION"
func policy() -> Dictionary: return POLICIES[current()]
func _process(_delta: float) -> void:
	var value := current()
	if last!=value: last=value; changed.emit(last)
