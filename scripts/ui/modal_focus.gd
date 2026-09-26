extends Node
## Explicit keyboard scope and return focus for paper overlays.
var surface: Control
var previous_id := 0

static func install(panel: Control, initial: Control = null) -> void:
	if panel.has_meta("modal_focus_scope"): return
	panel.set_meta("modal_focus_scope",true)
	var scope=load("res://scripts/ui/modal_focus.gd").new()
	scope.surface=panel
	var previous:=panel.get_viewport().gui_get_focus_owner()
	if is_instance_valid(previous) and not panel.is_ancestor_of(previous): scope.previous_id=previous.get_instance_id()
	panel.add_child(scope)
	if initial!=null: initial.grab_focus.call_deferred()

func _ready() -> void:
	process_mode=PROCESS_MODE_ALWAYS
	add_to_group("modal_focus_scopes")

func _input(event: InputEvent) -> void:
	if not is_instance_valid(surface) or not surface.is_visible_in_tree(): return
	if not event.is_action_pressed("ui_focus_next") and not event.is_action_pressed("ui_focus_prev"): return
	# Nested confirmation owns the keyboard until it closes.
	var scopes:=get_tree().get_nodes_in_group("modal_focus_scopes")
	for scope in scopes:
		if scope==self: continue
		if scope.is_inside_tree() and not scope.is_queued_for_deletion() and scope.surface.is_visible_in_tree() and (surface.is_ancestor_of(scope) or scopes.find(scope)>scopes.find(self)): return
	var controls: Array[Control]=[]
	_collect(surface,controls)
	if controls.is_empty(): return
	var current:=get_viewport().gui_get_focus_owner()
	var direction: int=-1 if event.is_action_pressed("ui_focus_prev") else 1
	var index:=controls.find(current)
	if index<0: index=0 if direction<0 else -1
	controls[posmod(index+direction,controls.size())].grab_focus()
	get_viewport().set_input_as_handled()

func _collect(node: Node, controls: Array[Control]) -> void:
	for child in node.get_children():
		if child is Control and child.is_visible_in_tree() and not child.is_queued_for_deletion():
			if child.focus_mode==Control.FOCUS_ALL and not (child is BaseButton and child.disabled): controls.append(child)
		_collect(child,controls)

func _exit_tree() -> void:
	_restore.call_deferred(previous_id)

static func _restore(id: int) -> void:
	if id==0: return
	var control=instance_from_id(id)
	if control is Control and control.is_inside_tree() and control.is_visible_in_tree() and not control.is_queued_for_deletion(): control.grab_focus()
