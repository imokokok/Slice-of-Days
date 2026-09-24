extends Node
## Presentation clock only. Transactions and opening hours keep the real clock.
const Composition = preload("res://scripts/ui/street_composition.gd")
const MAX_MINUTES_PER_SECOND := 8.0
var initialized := false
var day := 1
var minute := 540.0
var rain := 0.0
var light := Color.WHITE
var blend := Vector3(1,0,0)
var changing := false

func _ready() -> void:
	process_priority = -20

func ensure_initialized() -> void:
	if not initialized: reset_to_clock()

## Only call at first presentation or behind an opaque scene curtain.
func reset_to_clock() -> void:
	day = GameState.current_day
	minute = float(GameState.current_minute)
	rain = Composition.rain_amount(day, minute)
	initialized = true
	_sample()

func _process(delta: float) -> void:
	if not initialized: return
	# A new chapter is revealed at its correct time behind SceneRouter's curtain.
	# Never run an entire overnight time-lapse in the outgoing scene.
	if day != GameState.current_day: return
	advance_visual(delta, float(GameState.current_minute))

func advance_visual(delta: float, target: float) -> void:
	if not is_finite(delta) or delta <= 0: return
	# A stalled frame / refocusing the window must not skip the visible transition.
	var dt := minf(delta, .1)
	var before := minute
	var distance := absf(target-minute)
	minute = move_toward(minute,target,minf(distance*(1.0-exp(-dt/1.6)),MAX_MINUTES_PER_SECOND*dt))
	var target_rain := Composition.rain_amount(day,minute)
	rain = move_toward(rain,target_rain,dt/8.0)
	changing = absf(minute-before)>.00001 or absf(rain-target_rain)>.00001
	_sample()

func _sample() -> void:
	light = Composition.daylight(minute)
	blend = sky_weights(minute)

static func sky_weights(at: float) -> Vector3:
	var t := fposmod(at,1440.0)
	if t < 330: return Vector3(0,0,1)
	if t < 480:
		var dawn := smoothstep(330.0,480.0,t)
		return Vector3(dawn,0,1-dawn)
	if t < 1020: return Vector3(1,0,0)
	if t < 1110:
		var sunset := smoothstep(1020.0,1110.0,t)
		return Vector3(1-sunset,sunset,0)
	if t < 1200:
		var evening := smoothstep(1110.0,1200.0,t)
		return Vector3(0,1-evening,evening)
	return Vector3(0,0,1)
