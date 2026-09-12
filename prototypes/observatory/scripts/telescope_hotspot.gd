extends Button
signal enter_requested
func _ready() -> void:
 mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 mouse_entered.connect(func(): modulate = Color(1.2, 1.15, 1.0))
 mouse_exited.connect(func(): modulate = Color.WHITE)
 pressed.connect(func(): enter_requested.emit())
