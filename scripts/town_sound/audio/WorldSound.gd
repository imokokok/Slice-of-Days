extends Node
## Authored procedural game ambience. Only this bus is captured in town mode;
## preview, pressing sounds and real microphones never feed it.
const BUS := "TownWorld"
const RATE := 22050
var ambience: AudioStreamPlayer
var foley: AudioStreamPlayer
var location := ""
var active := false
var cache: Dictionary = {}
var monitoring_locks := 0

func _ready() -> void:
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS)
	ambience = AudioStreamPlayer.new()
	foley = AudioStreamPlayer.new()
	for player in [ambience, foley]:
		player.bus = BUS
		add_child(player)

func set_active(value: bool) -> void:
	active = value
	if not active:
		ambience.stop()
		foley.stop()
	elif ambience.stream != null and not ambience.playing and AudioServer.get_driver_name() != "Dummy":
		ambience.play()

func set_location(value: String) -> void:
	if location == value: return
	location = value
	if not cache.has(value): cache[value] = make_ambience(value)
	ambience.stream = cache[value]
	if active and AudioServer.get_driver_name() != "Dummy": ambience.play()

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
	foley.stream = make_detail(location, footsteps)
	foley.play()

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
