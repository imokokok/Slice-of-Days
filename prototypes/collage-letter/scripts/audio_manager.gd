extends Node

const ROOT := "res://assets/open_pack/audio/"
var muted := false
var bank: Dictionary = {}
var pool: Array[AudioStreamPlayer] = []
var cooldown: Dictionary = {}
var ages: Dictionary = {}
var durations: Dictionary = {}
var cursor := 0
var last_clip := ""
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	for i in 10:
		var voice := AudioStreamPlayer.new()
		voice.bus="SoundEffects" if AudioServer.get_bus_index("SoundEffects") >= 0 else "Master"
		add_child(voice);pool.append(voice)
	for name in ["paper","strokes","rustle","scissors","stamp","tear","match"]:
		bank[name]=load(ROOT+name+".mp3")
	bank["pencil"]=load(ROOT+"pencil.ogg")
	bank["tape"]=load(ROOT+"tape.mp3")
	for i in range(1,6): bank["click"+str(i)]=load(ROOT+"click"+str(i)+".ogg")

func _process(delta: float) -> void:
	for voice in pool:
		if voice.playing:
			ages[voice] = ages.get(voice,0.0)+delta
			var remaining: float=durations.get(voice,0.3)-ages[voice]
			voice.volume_db=float(voice.get_meta("gain_db",-16.0))+linear_to_db(clampf(remaining/0.035,0.001,1.0))
			if ages[voice] > durations.get(voice,0.3): voice.stop()

func play(event: String, strength: float = 1.0) -> void:
	if muted: return
	var now := Time.get_ticks_msec()
	if now-int(cooldown.get(event,-10000)) < (100 if event=="PENCIL_DRAW" else 75): return
	cooldown[event]=now
	var clip := "rustle"
	var duration := 0.27
	var offset := 0.0
	match event:
		"KNIFE_SLICE":
			clip="scissors";offset=0.12;duration=0.35
		"PAPER_CUT": clip="tear";duration=0.21;offset=0.2
		"TAPE_TEAR": clip="tape";offset=2.1;duration=0.65
		"TAPE_PULL": clip="tape";offset=0.25;duration=0.8
		"PENCIL_DRAW": clip="pencil";offset=rng.randf_range(0.1,0.7);duration=0.3
		"STAMP_PRESS", "STAMP_RELEASE", "PAPER_PRESS", "TAPE_STICK": clip="stamp";duration=0.22
		"MATCH_STRIKE": clip="match";duration=0.48
		"FIRE_LOOP": return # This pack contains no candle loop recording.
		"WAX_PELLETS", "DIALOGUE_ADVANCE", "MAIL_DROP": clip="click"+str(rng.randi_range(1,5));duration=0.3
		"WAX_POUR": clip="rustle";duration=0.24
		_: offset=rng.randf_range(0.1,2.0)
	var voice := pool[cursor]
	cursor=(cursor+1)%pool.size()
	voice.stop();voice.stream=bank[clip]
	voice.pitch_scale=rng.randf_range(0.96,1.04)
	last_clip=clip
	voice.volume_db=-5+linear_to_db(clampf(strength,0.1,1.4))
	voice.set_meta("gain_db",voice.volume_db)
	ages[voice]=0.0;durations[voice]=duration
	var length: float = voice.stream.get_length()
	voice.play(clampf(offset,0,maxf(0,length-duration)))

func toggle() -> void:
	muted=not muted
	if muted:
		for voice in pool: voice.stop()

func shutdown() -> void:
	for voice in pool: voice.stop();voice.stream=null
	bank.clear()

func _exit_tree() -> void:
	shutdown()
