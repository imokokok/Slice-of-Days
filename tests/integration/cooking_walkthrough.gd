extends RefCounted
## Exercise the public controls; never manufacture a completed cooking record.
static func prepare_and_cook(kitchen, option := 0) -> void:
	kitchen.primary_button.pressed.emit()
	for i in kitchen.selected_tokens.size():
		kitchen.prep_option_buttons[option].pressed.emit()
		while not kitchen.prep_board.target_id.is_empty(): kitchen.prep_board.pressed.emit()
	finish_prepared(kitchen)

static func finish_prepared(kitchen) -> void:
	for token_id in kitchen.selected_tokens:
		var window: Array=kitchen._token_data(token_id).get("heat_window",[.42,.70])
		kitchen.value_slider.value=(float(window[0])+float(window[1]))*.5
		kitchen.token_buttons[token_id].pressed.emit()
		if is_instance_valid(kitchen.illustrated_pot): kitchen.illustrated_pot.pressed.emit()
		else: kitchen.primary_button.pressed.emit()
	kitchen.value_slider.value=.58
	for i in 2: kitchen.stir_buttons.fold.pressed.emit()
	kitchen.primary_button.pressed.emit()
	var seasoning: String=preload("res://scripts/core/cooking_mechanics.gd").seasoning_target(kitchen._selected_token_data())
	if seasoning!="rest": kitchen.seasoning_buttons["wasabi" if seasoning=="brighten" else seasoning].pressed.emit()
	kitchen.primary_button.pressed.emit()
	kitchen.plating_buttons.share.pressed.emit()
