extends Node
## Adapted from Nathan Hoad's Godot Sound Manager abstract_audio_player_pool.gd.
## MIT, upstream 1c041582db806a0d0edad77111d1fb7a009346ef. See third_party.
## Bounded pool, immediate reservation/play and priority added for Solmere.
const LIMIT := 8
var available_players: Array[AudioStreamPlayer] = []
var busy_players: Array[AudioStreamPlayer] = []

func play(resource: AudioStream, bus: String, volume: float, priority := 0) -> AudioStreamPlayer:
	if resource == null: return null
	var player: AudioStreamPlayer
	if not available_players.is_empty():
		player=available_players.pop_front()
	elif busy_players.size()<LIMIT:
		player=AudioStreamPlayer.new()
		add_child(player)
		player.finished.connect(_release.bind(player))
	else:
		# Discard excess low-priority clicks before interrupting a result/record cue.
		for candidate in busy_players:
			if int(candidate.get_meta("priority",0))<priority:
				player=candidate; player.stop(); busy_players.erase(player); break
		if player==null: return null
	player.stream=resource; player.bus=bus; player.volume_db=volume; player.pitch_scale=1.0
	player.set_meta("priority",priority)
	busy_players.append(player)
	player.play()
	return player

func _release(player: AudioStreamPlayer) -> void:
	busy_players.erase(player)
	if not available_players.has(player): available_players.append(player)

func stop_bus(bus: String) -> void:
	for player in busy_players.duplicate():
		if player.bus==bus: player.stop(); _release(player)
