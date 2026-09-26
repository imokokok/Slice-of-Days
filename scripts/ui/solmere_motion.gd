extends RefCounted
## Adapted Control pop/scale tween from Rock Gementiza's UI Animation Library.
## Upstream 62230b14300c44a6a7decb8ad052b2b29b416a67; MIT, see
## third_party/licenses/godot_ui_animation/LICENSE. Solmere adds interruption,
## per-node ownership, accessibility, restrained motion and exact restoration.

static func _cancel(node: Control, key: String) -> void:
	if not node.has_meta(key): return
	var previous: Tween = node.get_meta(key, null)
	if previous != null and previous.is_valid(): previous.kill()

static func paper_open(node: Control, reduced := false) -> Tween:
	if not is_instance_valid(node) or not node.is_inside_tree(): return null
	_cancel(node,"paper_motion")
	if not node.has_meta("paper_rest_scale"): node.set_meta("paper_rest_scale",node.scale)
	var target: Vector2 = node.get_meta("paper_rest_scale")
	node.pivot_offset = node.size * .5
	node.scale = target if reduced else target * .985
	node.modulate.a = 1.0 if reduced else .55
	var tween := node.create_tween().set_parallel(true)
	node.set_meta("paper_motion",tween)
	tween.tween_property(node,"scale",target,.01 if reduced else .22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(node,"modulate:a",1.0,.01 if reduced else .16)
	return tween

static func page_turn(node: Control, reduced := false) -> Tween:
	return paper_open(node,reduced)

static func press(node: Control, down: bool, reduced := false) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree(): return
	_cancel(node,"press_motion")
	# offset_transform does not move layout bounds or neighboring controls.
	node.offset_transform_enabled = true
	var tween := node.create_tween()
	node.set_meta("press_motion",tween)
	tween.tween_property(node,"offset_transform_scale",Vector2.ONE * (.975 if down and not reduced else 1.0),.01 if reduced else .09).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

static func ingredient_pickup(node: Control, reduced := false) -> void:
	press(node,true,reduced)
	if reduced: return
	var tween: Tween = node.get_meta("press_motion")
	tween.tween_property(node,"offset_transform_scale",Vector2.ONE,.13)

static func attach_id(instance_id: int) -> void:
	# Pages can rebuild and free buttons before the deferred queue runs.
	# Resolve the ID here; passing a freed, typed Object fails before any guard.
	var button=instance_from_id(instance_id)
	if button is BaseButton and not button.is_queued_for_deletion(): attach(button)

static func attach(button: BaseButton) -> void:
	if not is_instance_valid(button) or button.is_queued_for_deletion(): return
	if button.has_meta("solmere_motion_bound"): return
	button.set_meta("solmere_motion_bound",true)
	button.button_down.connect(func():
		if not button.disabled: press(button,true,SettingsSystem.reduced_motion()))
	button.button_up.connect(func(): press(button,false,SettingsSystem.reduced_motion()))
	button.focus_exited.connect(func(): press(button,false,SettingsSystem.reduced_motion()))
	button.mouse_exited.connect(func(): press(button,false,SettingsSystem.reduced_motion()))
