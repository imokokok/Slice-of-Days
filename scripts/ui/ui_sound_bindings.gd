extends RefCounted
## Adapted signal registration from Maaack/Godot-UI-Sound-Controller (MIT).
## Upstream 4ae5fd97b363b8236abfe616179226aa03ded0cd; license in third_party.
## Solmere uses its existing mixer, instance IDs and only user-driven changes.

static func attach_id(id: int) -> void:
	var node = instance_from_id(id)
	if not node is Control or node.is_queued_for_deletion() or node.has_meta("ui_sounds_bound"): return
	node.set_meta("ui_sounds_bound",true)
	if node is BaseButton:
		node.pressed.connect(_button.bind(id))
	elif node is Slider:
		node.value_changed.connect(_slider.bind(id))
	elif node is TabBar:
		node.tab_changed.connect(_tab.bind(id))
	elif node is LineEdit:
		node.text_submitted.connect(_submit.bind(id))
	if node is BaseButton or node is Slider or node is LineEdit:
		node.focus_entered.connect(_focus.bind(id))

static func _visible(id: int) -> bool:
	var node = instance_from_id(id)
	return node is Control and node.is_inside_tree() and not node.is_queued_for_deletion() and node.is_visible_in_tree()

static func _button(id: int) -> void:
	# Action handlers may close/free the button; still emit one accepted input cue.
	var node = instance_from_id(id)
	if node is BaseButton and not node.disabled: WorldSound.play_ui("click")

static func _slider(_value: float, id: int) -> void:
	if _visible(id) and (instance_from_id(id).has_focus() or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		WorldSound.play_ui("slider")

static func _tab(_index: int, id: int) -> void:
	if _visible(id) and instance_from_id(id).has_focus(): WorldSound.play_ui("tab")

static func _submit(_text: String, id: int) -> void:
	if _visible(id): WorldSound.play_ui("click")

static func _focus(id: int) -> void:
	# Mouse hover stays quiet. Keyboard focus receives a restrained cue.
	if _visible(id) and (Input.is_action_pressed("ui_focus_next") or Input.is_action_pressed("ui_focus_prev")):
		WorldSound.play_ui("focus")
