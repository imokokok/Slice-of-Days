extends Node

const ROOT := "res://workshop/open_assets/audio/"
var muted := false
var haptic_level := 0
var bank: Dictionary = {}
var pool: Array[AudioStreamPlayer] = []
var cooldown: Dictionary = {}
var ages: Dictionary = {}
var durations: Dictionary = {}
var cursor := 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	for i in 10:
		var voice := AudioStreamPlayer.new()
		voice.bus="SoundEffects" if AudioServer.get_bus_index("SoundEffects") >= 0 else "Master"
		add_child(voice);pool.append(voice)
	for name in ["paper","pencil","strokes","rustle","scissors","stamp","tear","match"]:
		bank[name]=load(ROOT+name+".mp3")
	for i in range(1,5): bank["typewriter"+str(i)]=load(ROOT+"typewriter"+str(i)+".wav")
	for i in range(1,6): bank["click"+str(i)]=load(ROOT+"click"+str(i)+".ogg")

func _process(delta: float) -> void:
	for voice in pool:
		if voice.playing:
			ages[voice] = ages.get(voice,0.0)+delta
			if ages[voice] > durations.get(voice,0.3): voice.stop()

func play(event: String, strength: float = 1.0) -> void:
	if muted: return
	var now := Time.get_ticks_msec()
	if now-int(cooldown.get(event,-10000)) < 48: return
	cooldown[event]=now
	var clip := "paper"
	var duration := 0.27
	var offset := 0.0
	match event:
		"TYPE_KEY", "TYPE_SPACE", "TYPE_BACKSPACE", "TYPE_RETURN", "TYPE_ROLLER":
			clip="typewriter"+str(rng.randi_range(1,4));duration=0.32
		"KNIFE_SLICE", "PEN_WRITE", "GLUE_SPREAD":
			clip="strokes" if event=="KNIFE_SLICE" else "pencil";offset=rng.randf_range(0.2,2);duration=0.18
		"SCISSOR_CUT", "PAPER_CUT": clip="scissors";duration=0.21;offset=0.2
		"TAPE_TEAR": clip="tear";duration=0.36
		"STAMP_PRESS", "STAMP_RELEASE", "PAPER_PRESS", "TAPE_STICK": clip="stamp";duration=0.22
		"MATCH_STRIKE": clip="match";duration=0.48
		"FIRE_LOOP": return # No synthetic hiss pretending to be a licensed candle recording.
		"WAX_PELLETS", "DIALOGUE_ADVANCE", "MAIL_DROP": clip="click"+str(rng.randi_range(1,5));duration=0.3
		"WAX_POUR", "TAPE_PULL": clip="rustle";duration=0.24
		_: offset=rng.randf_range(0.1,2.0)
	var voice := pool[cursor]
	cursor=(cursor+1)%pool.size()
	voice.stop();voice.stream=bank[clip]
	voice.pitch_scale=rng.randf_range(0.96,1.04)
	voice.volume_db=-16+linear_to_db(clampf(strength,0.1,1.4))
	ages[voice]=0.0;durations[voice]=duration
	voice.play(offset)
	if haptic_level>0 and event in ["SCISSOR_CUT","STAMP_PRESS","TYPE_RETURN","PAPER_PRESS"]:
		for device in Input.get_connected_joypads(): Input.start_joy_vibration(device,0.08*haptic_level,0.03*haptic_level,0.05)

func toggle() -> void:
	muted=not muted
	if muted:
		for voice in pool: voice.stop()

func shutdown() -> void:
	for voice in pool: voice.stop();voice.stream=null
	bank.clear()

func _exit_tree() -> void:
	shutdown()
