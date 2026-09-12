extends Node
var sky: Node
var busy := false
@onready var deck := $ObservatoryDeck
@onready var fade := $Transition/Fade
func _ready() -> void:
 get_tree().auto_accept_quit = false
 deck.enter_requested.connect(enter_sky)
 if "--stargazing" in OS.get_cmdline_user_args(): enter_sky.call_deferred()
func _notification(what: int) -> void:
 if what == NOTIFICATION_WM_CLOSE_REQUEST:
  GameState.save_state()
  AudioManager.waves.stop()
  AudioManager.tone.stop()
  await get_tree().create_timer(0.15).timeout
  get_tree().quit()
func dim(alpha: float) -> void:
 var tween := create_tween()
 tween.tween_property(fade, "color:a", alpha, 0.4)
 await tween.finished
func enter_sky() -> void:
 if busy: return
 busy = true
 fade.mouse_filter = Control.MOUSE_FILTER_STOP
 AudioManager.feedback(false)
 await dim(1.0)
 deck.hide()
 sky = load("res://scenes/StarGazing3D.tscn").instantiate()
 add_child(sky)
 sky.return_requested.connect(leave_sky)
 AudioManager.set_stargazing(true)
 await dim(0.0)
 fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
 busy = false
func leave_sky() -> void:
 if busy: return
 busy = true
 fade.mouse_filter = Control.MOUSE_FILTER_STOP
 await dim(1.0)
 remove_child(sky)
 sky.queue_free()
 sky = null
 deck.show()
 AudioManager.set_stargazing(false)
 GameState.save_state()
 await dim(0.0)
 fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
 busy = false
