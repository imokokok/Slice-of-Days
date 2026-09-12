extends Control
@export_dir var image_folder := "res://assets/slideshow/"
@export var random_order := false
@export var hold_seconds := 5.0
@export var fade_seconds := 1.0
@export var preserve_background_when_empty := false
@export var projection_shader: Shader
var files: Array[String] = []
var front := TextureRect.new()
var back := TextureRect.new()
var transitioning := false
var transition: Tween
func _ready() -> void:
 clip_contents = true
 for rect in [back, front]:
  add_child(rect)
  rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
  rect.modulate = Color(0.73, 0.78, 0.83)
  rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
  if projection_shader:
   rect.modulate = Color.WHITE
   rect.stretch_mode = TextureRect.STRETCH_SCALE
   var mat := ShaderMaterial.new()
   mat.shader = projection_shader
   rect.material = mat
 scan_images()
func scan_images() -> void:
 files.clear()
 if DirAccess.dir_exists_absolute(image_folder):
  for name in DirAccess.get_files_at(image_folder):
   if name.get_extension().to_lower() in ["jpg", "jpeg", "png"]:
    files.append(image_folder.path_join(name))
 files.sort()
 if files.is_empty():
  front.texture = load("res://assets/background/photo_placeholder.svg")
  front.visible = not preserve_background_when_empty
  back.hide()
  return
 front.show()
 back.show()
 var saved := files.find(GameState.slide_file)
 GameState.slide_index = saved if saved >= 0 else GameState.slide_index % files.size()
 front.texture = texture_at(GameState.slide_index)
func texture_at(index: int) -> Texture2D:
 var tex: Texture2D
 if ResourceLoader.exists(files[index]): tex = load(files[index]) as Texture2D
 else:
  var img := Image.load_from_file(files[index])
  if img: tex = ImageTexture.create_from_image(img)
 return tex if tex else load("res://assets/background/photo_placeholder.svg")
func _process(delta: float) -> void:
 if files.size() < 2 or transitioning: return
 GameState.slide_elapsed += delta
 if GameState.slide_elapsed >= hold_seconds: advance()
func advance() -> void:
 transitioning = true
 var next := (GameState.slide_index + 1) % files.size()
 if random_order: next = (GameState.slide_index + randi_range(1, files.size()-1)) % files.size()
 back.texture = texture_at(next)
 transition = create_tween()
 transition.tween_property(front, "modulate:a", 0.0, fade_seconds)
 await transition.finished
 front.texture = back.texture
 front.modulate.a = 1.0
 GameState.slide_index = next
 GameState.slide_file = files[next]
 GameState.slide_elapsed = 0.0
 transitioning = false
