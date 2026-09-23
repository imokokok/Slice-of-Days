extends Node
## Authored procedural game ambience. Only this bus is captured in town mode;
## preview, pressing sounds and real microphones never feed it.
const BUS := "TownWorld"
const MUSIC_BUS := "TownWorldMusic"
const SOUND_EFFECTS_BUS := "TownWorldSoundEffects"
const RATE := 22050
const Production = preload("res://scripts/ui/production_assets.gd")
var ambience: AudioStreamPlayer
var foley: AudioStreamPlayer
var coast: AudioStreamPlayer
var weather_player: AudioStreamPlayer
var ui: AudioStreamPlayer
var indoors := false
var location := ""
var active := false
var cache: Dictionary = {}
var monitoring_locks := 0
var footstep_cache: Dictionary = {}
var step_index := 0
var ambience_thread: Thread
var generating_location := ""
var requested_location := ""
var weather := "clear"
var natural: AudioStreamPlayer
var natural_previous: AudioStreamPlayer
var steps: AudioStreamPlayer
var birds: AudioStreamPlayer
var natural_profile := ""
var nature_transition: Tween
var next_bird := 12.0
var bird_index := 0
var detail_index := 0
var last_ui_msec := -1000
var last_ui_key := ""

func _ready() -> void:
	_ensure_bus(BUS, "Master")
	_ensure_bus(MUSIC_BUS, BUS)
	_ensure_bus(SOUND_EFFECTS_BUS, BUS)
	ambience = AudioStreamPlayer.new()
	foley = AudioStreamPlayer.new()
	coast = AudioStreamPlayer.new()
	weather_player = AudioStreamPlayer.new()
	weather_player.bus=SOUND_EFFECTS_BUS
	ui = AudioStreamPlayer.new()
	ambience.bus = MUSIC_BUS
	coast.bus = MUSIC_BUS
	foley.bus = SOUND_EFFECTS_BUS
	# Interface feedback is deliberately not part of Town World's recorder mix.
	ui.bus = "SoundEffects"
	# Keep the authored stream available even with the Dummy driver so tests,
	# waveform capture and accessibility previews can inspect the real sound.
	# Playback itself remains disabled below when no audio driver exists.
	coast.stream = make_sea()
	coast.volume_db = -12.0
	add_child(coast)
	add_child(weather_player)
	add_child(ui)
	for player in [ambience, foley]:
		add_child(player)
	natural=AudioStreamPlayer.new(); natural_previous=AudioStreamPlayer.new()
	steps=AudioStreamPlayer.new(); birds=AudioStreamPlayer.new()
	for player in [natural,natural_previous,birds]: player.bus=MUSIC_BUS; add_child(player)
	steps.bus=SOUND_EFFECTS_BUS; add_child(steps)


func _ensure_bus(bus_name: String, send_name: String) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		AudioServer.add_bus()
		bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_send(bus_index, send_name)

func set_active(value: bool) -> void:
	active = value
	if not active:
		coast.stop()
		ambience.stop()
		foley.stop()
		weather_player.stop()
		natural.stop(); natural_previous.stop(); birds.stop(); steps.stop()
		natural_profile=""
	elif ambience.stream != null and not ambience.playing and AudioServer.get_driver_name() != "Dummy":
		ambience.play()
	if active and not coast.playing and AudioServer.get_driver_name() != "Dummy": coast.play()
	if active: _refresh_nature()
	if active and weather=="rain" and not weather_player.playing: _refresh_rain()

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

func set_weather(value: String) -> void:
	var next := "rain" if value == "rain" else "clear"
	if weather == next: return
	weather = next
	if weather == "clear":
		weather_player.stop()
		return
	_refresh_rain()

func _refresh_rain() -> void:
	var sample := Production.sound("ambience_indoor_rain" if indoors else "ambience_rain")
	weather_player.stream=sample if sample!=null else make_weather_rain()
	weather_player.volume_db=-24.0 if indoors else -20.0
	if active and weather=="rain" and AudioServer.get_driver_name()!="Dummy": weather_player.play()

func _refresh_nature() -> void:
	if not active or natural==null: return
	var minute := GameState.current_minute
	var profile := "ambience_room" if indoors else "ambience_night" if minute>=19*60 or minute<6*60 else "ambience_wind" if minute>=17*60 else "ambience_day"
	if profile==natural_profile: return
	var sample := Production.sound(profile)
	if sample==null: return
	natural_profile=profile
	if nature_transition and nature_transition.is_valid(): nature_transition.kill()
	var old := natural_previous; natural_previous=natural; natural=old
	natural.stop(); natural.stream=sample; natural.volume_db=-55
	if AudioServer.get_driver_name()=="Dummy": return
	natural.play()
	nature_transition=create_tween().set_parallel(true)
	nature_transition.tween_property(natural,"volume_db",-26.0 if indoors else -23.0,.7)
	nature_transition.tween_property(natural_previous,"volume_db",-55.0,.7)
	nature_transition.chain().tween_callback(natural_previous.stop)


func _start_ambience_job(place: String) -> void:
	generating_location = place
	ambience_thread = Thread.new()
	var result := ambience_thread.start(Callable(self, "make_ambience").bind(place))
	if result != OK:
		push_error("Unable to start ambience generation: %s" % error_string(result))
		ambience_thread = null
		generating_location = ""


func _process(_delta: float) -> void:
	_refresh_nature()
	if active and not indoors and weather!="rain" and GameState.current_minute>=6*60 and GameState.current_minute<18*60:
		next_bird-=_delta
		if next_bird<=0:
			bird_index+=1; next_bird=17.0+float(bird_index%4)*7.0
			birds.stream=Production.sound("bird_%d" % (bird_index%4+1))
			birds.volume_db=-27.0
			if birds.stream!=null and AudioServer.get_driver_name()!="Dummy": birds.play()
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
	if footsteps: play_footstep(); return
	detail_index+=1
	var kind := "water" if location in ["port","town_entrance"] else "leaf" if location=="park" else "paper" if location in ["library","handcraft_shop","print_shop"] else "wood"
	var sample := Production.sound("foley_%s_%d" % [kind,detail_index%3+1])
	foley.volume_db = -15.0 if sample!=null else 0.0
	foley.pitch_scale = 1.0
	foley.stream = sample if sample!=null else make_detail(location, footsteps)
	foley.play()

func play_ui(cue: String) -> void:
	if AudioServer.get_driver_name() == "Dummy": return
	var now := Time.get_ticks_msec()
	# Specific action feedback wins over the global generic button callback.
	if cue=="click" and now-last_ui_msec<85: return
	if cue=="focus" and now-last_ui_msec<120: return
	var key := str({"focus":"ui_focus","dialogue":"ui_click","coin":"ui_success","error":"ui_error","record_start":"ui_record_start","record_stop":"ui_record_stop","paper":"ui_slide","open":"ui_open","close":"ui_close","notification":"ui_notice","check":"ui_check","drag":"ui_drag","drop":"ui_drop","snap":"ui_snap","cut":"foley_wood_1","water":"foley_water_1"}.get(cue,"ui_click"))
	var sample := Production.sound(key) if cue!="shutter" else null
	ui.stream = sample if sample!=null else make_ui(cue)
	ui.volume_db = -19.0 if sample!=null else -5.0
	last_ui_msec=now; last_ui_key=key
	ui.play()

static func make_ui(cue: String) -> AudioStreamWAV:
	var durations := {"focus": 0.055, "dialogue": 0.075, "coin": 0.24, "error": 0.16, "shutter": 0.18, "record_start": 0.16, "record_stop": 0.12, "paper": 0.38}
	var duration := float(durations.get(cue, 0.10))
	var frames := maxi(1, int(RATE * duration))
	var data := PackedByteArray()
	data.resize(frames * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 46331
	var paper_smooth := 0.0
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
			"paper":
				var noise := rng.randf_range(-1.0, 1.0)
				paper_smooth += (noise - paper_smooth) * 0.12
				var turn := sin(PI * clampf(t / duration, 0.0, 1.0))
				var settle := exp(-pow((t - 0.30) / 0.045, 2.0))
				value = ((noise - paper_smooth) * 0.12 + paper_smooth * 0.035) * turn + sin(TAU * 118.0 * t) * 0.025 * settle
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
	step_index += 1
	var surface := "wood" if indoors else "grass" if location=="park" else "gravel" if location in ["port","viewpoint"] else "stone"
	var sample := Production.sound("step_%s_%d" % [surface,step_index%5+1])
	if sample!=null:
		steps.stream=sample; steps.volume_db=-21.0 if indoors else -19.0
		steps.pitch_scale=1.0; steps.play(); return
	if not footstep_cache.has(location):
		var wav := make_detail(location,true)
		wav.data = wav.data.slice(0,int(RATE*0.16)*2)
		footstep_cache[location] = wav
	foley.stream = footstep_cache[location]
	foley.pitch_scale = 0.95 if step_index % 2 == 0 else 1.04
	foley.volume_db = -10.0 if indoors else -8.0
	foley.play()

func set_indoor(value: bool) -> void:
	var changed := indoors!=value
	indoors = value
	if coast != null: coast.volume_db = -30.0 if indoors else -12.0
	if weather_player != null: weather_player.volume_db = -27.0 if indoors else -18.0
	if changed:
		_refresh_nature()
		if weather=="rain": _refresh_rain()

static func make_weather_rain() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 50831
	var count := RATE * 12
	var data := PackedByteArray(); data.resize(count * 2)
	var low := 0.0
	for i in count:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low += (noise - low) * 0.03
		var drops := noise * 0.035 + low * 0.11
		var swell := 0.6 + 0.4 * sin(TAU * t / 7.0)
		drops *= swell * minf(1.0, minf(t, 12.0 - t) / 0.2)
		data.encode_s16(i * 2, int(clampf(drops, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = count
	return wav
static func make_sea() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 71209
	var data := PackedByteArray()
	var count := RATE * 16
	data.resize(count*2)
	var rumble := 0.0
	var body := 0.0
	var foam := 0.0
	for i in count:
		var t := float(i)/RATE
		var noise := rng.randf_range(-1.0,1.0)
		rumble += (noise-rumble)*0.0025
		body += (noise-body)*0.028
		foam += (noise-foam)*0.22
		var breaker_a := pow(maxf(0.0,sin(TAU*(t-0.8)/7.9)),5.0)
		var breaker_b := 0.62*pow(maxf(0.0,sin(TAU*(t-4.7)/10.7)),7.0)
		var breaker := clampf(breaker_a+breaker_b,0.0,1.0)
		var undertow := 0.18+0.22*(0.5+0.5*sin(TAU*t/8.0))
		var hiss := (foam-body)*breaker
		var sample := rumble*0.055*undertow + body*0.045*(0.25+breaker) + hiss*0.18
		# A quiet interval between breakers prevents a continuous fan-like wash.
		sample *= 0.55+0.45*breaker
		sample *= minf(1.0,minf(t,16.0-t)/0.18)
		data.encode_s16(i*2,int(clampf(sample,-1,1)*32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = count
	return wav
