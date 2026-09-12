extends Node
var waves := AudioStreamPlayer.new()
var tone := AudioStreamPlayer.new()
var fade: Tween
func _ready() -> void:
 add_child(waves)
 add_child(tone)
 var path := "res://assets/audio/soft_waves.ogg"
 if not ResourceLoader.exists(path): path = "res://assets/audio/soft_waves_placeholder.wav"
 if ResourceLoader.exists(path):
  waves.stream = load(path)
  if waves.stream is AudioStreamOggVorbis:
   waves.stream.loop = true
  elif waves.stream is AudioStreamWAV:
   waves.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
   waves.stream.loop_begin = 0
   waves.stream.loop_end = int(waves.stream.get_length() * waves.stream.mix_rate)
  waves.volume_db = -25
  waves.play()
func _exit_tree() -> void:
 waves.stop()
 tone.stop()
 waves.stream = null
 tone.stream = null
func set_stargazing(active: bool) -> void:
 if fade: fade.kill()
 fade = create_tween()
 fade.tween_property(waves, "volume_db", -33.0 if active else -25.0, 0.8)
func feedback(found: bool) -> void:
 var path := "res://assets/audio/constellation_found.ogg" if found else "res://assets/audio/telescope_click.ogg"
 if not ResourceLoader.exists(path): path = "res://assets/audio/chime_placeholder.wav"
 if ResourceLoader.exists(path):
  tone.stream = load(path)
  tone.volume_db = -24 if found else -32
  tone.play()
