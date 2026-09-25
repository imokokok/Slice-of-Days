extends Node
## Pool allocation/recycling adapted from Nathan Hoad's Godot Sound Manager,
## abstract_audio_player_pool.gd @ 1c041582db806a0d0edad77111d1fb7a009346ef.
## MIT license: third_party/licenses/godot_sound_manager/LICENSE.
## Solmere: bounded polyphony, world-only routing and short natural release.
const MAX_PLAYERS:=12
var available_players: Array[AudioStreamPlayer]=[]
var busy_players: Array[AudioStreamPlayer]=[]
var deadlines: Dictionary={}
var gains: Dictionary={}

func get_available_player() -> AudioStreamPlayer:
	if available_players.is_empty():
		if busy_players.size()>=MAX_PLAYERS:
			var oldest:AudioStreamPlayer=busy_players[0]; oldest.stop(); mark_player_as_available(oldest)
		else:
			var player:=AudioStreamPlayer.new(); player.bus="TownWorldSoundEffects"; add_child(player)
			available_players.append(player); player.finished.connect(mark_player_as_available.bind(player))
	return available_players.pop_front()

func mark_player_as_available(player:AudioStreamPlayer) -> void:
	busy_players.erase(player); deadlines.erase(player); gains.erase(player)
	if not available_players.has(player): available_players.append(player)

func play_stream(stream:AudioStream,gain:float,duration:=3.0) -> AudioStreamPlayer:
	if stream==null or AudioServer.get_driver_name()=="Dummy": return null
	var player:=get_available_player()
	player.stream=stream; player.volume_db=gain; player.pitch_scale=1.0
	busy_players.append(player); deadlines[player]=duration; gains[player]=gain; player.play(); return player

func _process(delta:float) -> void:
	for player in busy_players.duplicate():
		deadlines[player]=float(deadlines[player])-delta
		var left:float=deadlines[player]
		player.volume_db=float(gains[player])+linear_to_db(clampf(left/.06,.001,1))
		if left<=0: player.stop(); mark_player_as_available(player)

func stop_all() -> void:
	for player in busy_players.duplicate(): player.stop(); mark_player_as_available(player)
