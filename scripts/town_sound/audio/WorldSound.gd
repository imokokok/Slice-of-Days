extends Node
## Authored procedural game ambience. Only this bus is captured in town mode;
## preview, pressing sounds and real microphones never feed it.
const BUS := "TownWorld"
const RATE := 22050
var ambience: AudioStreamPlayer
var foley: AudioStreamPlayer
var coast: AudioStreamPlayer
var ui: AudioStreamPlayer
var indoors := false
var location := ""
var active := false
var cache: Dictionary = {}
var monitoring_locks := 0
var footstep_cache: Dictionary = {}
var ambience_thread: Thread
var generating_location := ""
var requested_location := ""

func _ready() -> void:
	if AudioServer.get_bus_index(BUS) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS)
	ambience = AudioStreamPlayer.new()
	foley = AudioStreamPlayer.new()
	coast = AudioStreamPlayer.new()
	ui = AudioStreamPlayer.new()
	coast.bus = BUS
	# Keep the authored stream available even with the Dummy driver so tests,
	# waveform capture and accessibility previews can inspect the real sound.
	# Playback itself remains disabled below when no audio driver exists.
	coast.stream = make_sea()
	coast.volume_db = -8.0
	add_child(coast)
	add_child(ui)
	for player in [ambience, foley]:
		player.bus = BUS
		add_child(player)

func set_active(value: bool) -> void:
	active = value
	if not active:
		coast.stop()
		ambience.stop()
		foley.stop()
	elif ambience.stream != null and not ambience.playing and AudioServer.get_driver_name() != "Dummy":
		ambience.play()
	if active and not coast.playing and AudioServer.get_driver_name() != "Dummy": coast.play()

func set_location(value: String) -> void:
	if location == value: return
	location = value
	requested_location = value
	if AudioServer.get_driver_name() == "Dummy":
		return
	if cache.has(value):
		_apply_ambience(value)
	elif ambience_thread == null:
		_start_ambience_job(value)


func _start_ambience_job(place: String) -> void:
	generating_location = place
	ambience_thread = Thread.new()
	var result := ambience_thread.start(Callable(self, "make_ambience").bind(place))
	if result != OK:
		push_error("Unable to start ambience generation: %s" % error_string(result))
		ambience_thread = null
		generating_location = ""


func _process(_delta: float) -> void:
	if ambience_thread == null or ambience_thread.is_alive():
		return
	var completed_location := generating_location
	var generated = ambience_thread.wait_to_finish()
	ambience_thread = null
	generating_location = ""
	if generated is AudioStreamWAV:
		cache[completed_location] = generated
		if requested_location == completed_location:
			_apply_ambience(completed_location)
	if not requested_location.is_empty() and not cache.has(requested_location):
		_start_ambience_job(requested_location)


func _apply_ambience(place: String) -> void:
	ambience.stream = cache[place]
	if active and AudioServer.get_driver_name() != "Dummy":
		ambience.play()


func _exit_tree() -> void:
	if ambience_thread != null:
		ambience_thread.wait_to_finish()
		ambience_thread = null

func lock_monitor(lock: bool) -> void:
	monitoring_locks = maxi(0, monitoring_locks + (1 if lock else -1))
	AudioServer.set_bus_mute(AudioServer.get_bus_index(BUS), monitoring_locks > 0)

func detail_label() -> String:
	if location in ["park", "port", "town_entrance"]: return "走近水边 · 脚步与水滴"
	if location in ["cafe", "cafeteria", "night_market"]: return "轻碰杯碟"
	if location in ["library", "handcraft_shop", "print_shop"]: return "翻一页纸"
	return "轻敲木面"

func play_detail(footsteps := false) -> void:
	if not active or AudioServer.get_driver_name() == "Dummy": return
	foley.volume_db = 0.0
	foley.stream = make_detail(location, footsteps)
	foley.play()

func play_ui(cue: String) -> void:
	if AudioServer.get_driver_name() == "Dummy": return
	ui.stream = make_ui(cue)
	ui.volume_db = -5.0
	ui.play()

static func make_ui(cue: String) -> AudioStreamWAV:
	var durations := {"focus": 0.055, "dialogue": 0.075, "coin": 0.24, "error": 0.16, "shutter": 0.18, "record_start": 0.16, "record_stop": 0.12}
	var duration := float(durations.get(cue, 0.10))
	var frames := maxi(1, int(RATE * duration))
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var t := float(i) / RATE
		var envelope := sin(PI * minf(t / duration, 1.0)) * exp(-t * (8.0 if cue == "coin" else 16.0))
		var value := 0.0
		match cue:
			"coin": value = (sin(TAU * 880.0 * t) + 0.55 * sin(TAU * 1320.0 * t)) * 0.18 * envelope
			"error": value = (sin(TAU * 150.0 * t) + 0.35 * sin(TAU * 105.0 * t)) * 0.16 * envelope
			"shutter": value = (sin(TAU * 90.0 * t) * 0.12 + sin(TAU * 1900.0 * t) * 0.05) * envelope
			"record_start": value = sin(TAU * (430.0 + t * 900.0) * t) * 0.16 * envelope
			"record_stop": value = sin(TAU * (620.0 - t * 1500.0) * t) * 0.14 * envelope
			"dialogue": value = sin(TAU * 620.0 * t) * 0.07 * envelope
			_: value = sin(TAU * 760.0 * t) * 0.06 * envelope
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	return wav

static func make_ambience(place: String) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(place.hash())
	var data := PackedByteArray()
	var count := RATE * 12
	data.resize(count * 2)
	var low := 0.0
	var water := place in ["park", "port"]
	var outdoor := water or place in ["town_entrance", "bus_stop", "old_station", "night_market"]
	var machine := place in ["print_shop", "bus_stop", "old_station"]
	for i in count:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low += (noise - low) * (0.025 if outdoor else 0.008)
		var value := low * (0.20 if outdoor else 0.10)
		if water: value += noise * 0.013 * (0.65 + 0.35 * sin(TAU * t / 6))
		if machine: value += sin(TAU * 72 * t) * 0.009 + sin(TAU * 144 * t) * 0.004
		if outdoor and not machine:
			var chirp := fposmod(t + 1.7, 4.0)
			if chirp < 0.35:
				value += sin(TAU * (1800 * chirp + 900 * chirp * chirp)) * sin(PI * chirp / 0.35) * 0.017
		if not outdoor and not machine:
			var tick := fposmod(t, 2.0)
			value += sin(TAU * 720 * tick) * exp(-tick * 100) * 0.02
		# Fade both loop edges to zero to avoid discontinuity clicks.
		value *= minf(1.0, minf(t, 12.0 - t) / 0.15)
		data.encode_s16(i * 2, int(value * 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = count
	return wav

static func make_detail(place: String, footsteps := false) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(place.hash()) + (11 if footsteps else 0)
	var data := PackedByteArray()
	data.resize(RATE * 2 * 2)
	var low := 0.0
	for i in RATE * 2:
		var t := float(i) / RATE
		var pulse := fposmod(t, 0.48) if footsteps else t
		var noise := rng.randf_range(-1.0, 1.0)
		low += (noise - low) * 0.15
		var value := 0.0
		if footsteps:
			value = (low * 0.28 + sin(TAU * 95 * pulse) * 0.07) * exp(-pulse * 30)
		elif place in ["cafe", "cafeteria", "night_market"]:
			value = (sin(TAU * 1450 * t) + sin(TAU * 2387 * t) * 0.3) * exp(-t * 9) * 0.07
		elif place in ["library", "handcraft_shop", "print_shop"]:
			value = (noise - low) * sin(PI * minf(t / 0.7, 1.0)) * exp(-t * 4) * 0.10
		else:
			value = (sin(TAU * 220 * t) * 0.1 + low * 0.12) * exp(-t * 22)
		value *= minf(1.0, t * 1000)
		data.encode_s16(i * 2, int(clampf(value, -1, 1) * 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	return wav

func play_footstep() -> void:
	if not active or AudioServer.get_driver_name() == "Dummy": return
	if not footstep_cache.has(location):
		var wav := make_detail(location,true)
		wav.data = wav.data.slice(0,int(RATE*0.16)*2)
		footstep_cache[location] = wav
	foley.stream = footstep_cache[location]
	foley.volume_db = -8.0
	foley.play()

func set_indoor(value: bool) -> void:
	indoors = value
	if coast != null: coast.volume_db = -27.0 if indoors else -8.0
static func make_sea() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 71209
	var data := PackedByteArray()
	var count := RATE * 12
	data.resize(count*2)
	var low := 0.0
	var wash := 0.0
	for i in count:
		var t := float(i)/RATE
		var noise := rng.randf_range(-1,1)
		low = lerpf(low,noise,0.035)
		wash = lerpf(wash,noise,0.24)
		var swell := 0.2 + 0.8 * pow(0.5 + 0.5 * sin(TAU*t/6.0),2.0)
		var foam := 0.5 + 0.5 * sin(TAU*t/3.0+1.4)
		var sample := (low*1.2 + wash*0.24 + noise*0.035*foam)*swell
		sample *= minf(1.0,minf(t,12.0-t)/0.12)
		data.encode_s16(i*2,int(clampf(sample,-1,1)*32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = count
	return wav
