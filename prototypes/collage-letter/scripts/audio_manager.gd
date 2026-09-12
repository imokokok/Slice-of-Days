extends Node

const EVENTS = ["KNIFE_SLICE","PAPER_MOVE","PAPER_CUT","PAPER_PRESS","TAPE_PULL","TAPE_TEAR","TAPE_STICK","PHOTO_PICKUP","PHOTO_DROP","PAPER_FOLD","ENVELOPE_INSERT","ENVELOPE_CLOSE","MATCH_STRIKE","FIRE_LOOP","WAX_POUR","STAMP_PRESS","STAMP_RELEASE","MAIL_DROP","DIALOGUE_ADVANCE"]
var bank: Dictionary = {}
var muted := false
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	for event in EVENTS:
		bank[event] = []
		for variant in 4:
			bank[event].append(synthesize(event,variant))
	var ambience := AudioStreamPlayer.new()
	var stream := synthesize("AMBIENCE",0)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size()/2
	ambience.stream = stream
	ambience.volume_db = -31
	ambience.name = "Ambience"
	add_child(ambience)
	ambience.play()

func synthesize(event: String, variant: int) -> AudioStreamWAV:
	var length := 0.16
	if event in ["TAPE_PULL","PAPER_FOLD","ENVELOPE_INSERT","WAX_POUR"]:
		length = 0.5
	if event == "AMBIENCE":
		length = 4.0
	var data := PackedByteArray()
	var count := int(22050*length)
	data.resize(count*2)
	var filtered := 0.0
	for i in count:
		var t := float(i)/22050.0
		var envelope := pow(1.0-float(i)/count,2.0)*minf(t*140,1.0)
		filtered = lerpf(filtered,rng.randf_range(-1,1),0.18)
		var value := filtered*0.7
		if event == "KNIFE_SLICE":
			value = filtered*0.55 + rng.randf_range(-1,1)*0.045
		elif event in ["PAPER_CUT","TAPE_TEAR","MATCH_STRIKE"]:
			value = rng.randf_range(-1,1)*0.4*(0.3+0.7*absf(sin(t*90)))
		elif event in ["STAMP_PRESS","MAIL_DROP","PAPER_PRESS"]:
			value = sin(t*(140+variant*15)*TAU)*0.4+filtered*0.2
		elif event == "WAX_POUR":
			value = filtered*0.2+sin(t*330*TAU)*0.08*pow(absf(sin(t*24)),12)
		elif event == "AMBIENCE":
			envelope = 0.6+0.3*sin(t*TAU/4)
			value = filtered*0.45
		data.encode_s16(i*2,int(clampf(value*envelope,-1,1)*28000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	return stream

func play(event: String, strength: float = 1.0) -> void:
	if muted or not bank.has(event):
		return
	var player := AudioStreamPlayer.new()
	player.stream = bank[event][rng.randi_range(0,3)]
	player.pitch_scale = rng.randf_range(0.94,1.06)
	player.volume_db = -14+linear_to_db(clampf(strength,0.15,1.5))
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func toggle() -> void:
	muted = not muted
	get_node("Ambience").volume_db = -80 if muted else -31

func shutdown() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream=null
	bank.clear()

func _exit_tree() -> void:
	shutdown()
