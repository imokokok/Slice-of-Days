extends VisualCanvas
## Local library playback uses the same saved source timeline as the Studio.
var player: AudioStreamPlayer
func _process(_delta: float) -> void:
	if is_instance_valid(player) and player.playing:
		time=player.get_playback_position()
		queue_redraw()
