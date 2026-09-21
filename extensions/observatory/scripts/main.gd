extends Node
var sky: Node
var busy := false
@onready var deck := $ObservatoryDeck
@onready var fade := $Transition/Fade
func _ready() -> void:
 deck.enter_requested.connect(enter_sky)
 if "--stargazing" in OS.get_cmdline_user_args(): enter_sky.call_deferred()
func dim(alpha: float) -> void:
 var tween := create_tween()
 tween.tween_property(fade, "color:a", alpha, 0.4)
 await tween.finished
func enter_sky() -> void:
 if busy: return
 busy = true
 fade.mouse_filter = Control.MOUSE_FILTER_STOP
 ObservatoryAudio.feedback(false)
 await dim(1.0)
 deck.hide()
 sky = load("res://extensions/observatory/scenes/StarGazing3D.tscn").instantiate()
 add_child(sky)
 sky.return_requested.connect(leave_sky)
 sky.finish_requested.connect(leave_sky)
 ObservatoryAudio.set_stargazing(true)
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
 ObservatoryAudio.set_stargazing(false)
 ObservatoryState.save_state()
 await dim(0.0)
 fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
 busy = false
