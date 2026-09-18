extends Node3D
signal return_requested
const BIRD = preload("res://extensions/observatory/resources/bird_constellation.tres")
const WHALE = preload("res://extensions/observatory/resources/whale_constellation.tres")
const STEP_ANGLE := 0.04
const STEP_LIMIT := 12
var source_data: ConstellationData
var data: ConstellationData
var adjustment := Vector2i.ZERO
var look_offset := Vector2.ZERO
var solution := Vector2i.ZERO
var reveal_tween: Tween
var is_capturing := false
@onready var camera := $Camera3D
@onready var field := $StarField
@onready var checker := $ProjectionChecker
@onready var hint := $UI/Hint
@onready var capture := $UI/Capture
@onready var next := $UI/Next
@onready var lines := $UI/Lines
func _ready() -> void:
 $UI/Return.pressed.connect(func(): return_requested.emit())
 capture.pressed.connect(collect)
 $UI/Album.pressed.connect(func():
  DirAccess.make_dir_recursive_absolute("user://album")
  OS.shell_open(ProjectSettings.globalize_path("user://album")))
 next.pressed.connect(func(): select_constellation(WHALE if data.id == "bird" else BIRD))
 checker.matched.connect(found)
 build_controls()
 select_constellation(WHALE if ObservatoryState.discovered.bird and not ObservatoryState.discovered.whale else BIRD)
func build_controls() -> void:
 var surface := Control.new()
 surface.name = "SkyDrag"
 $UI.add_child(surface)
 $UI.move_child(surface, 0)
 surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 surface.mouse_default_cursor_shape = Control.CURSOR_DRAG
 surface.gui_input.connect(_sky_input)
 $UI/Instructions.text = LocalizationSystem.text("按住鼠标左键拖动，转动望远镜 · 方向键微调 · 对准后停留片刻 · ESC 返回")
func _sky_input(event: InputEvent) -> void:
 if is_capturing: return
 if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
  look_offset = (look_offset + event.relative * Vector2(-0.003, -0.003)).clamp(Vector2(-0.6, -0.6), Vector2(0.6, 0.6))
  checker.elapsed = 0.0
  update_layout()
  $UI/SkyDrag.accept_event()
func select_constellation(value: ConstellationData) -> void:
 if reveal_tween: reveal_tween.kill()
 source_data = value
 # Only the display copy changes; authored world coordinates stay immutable.
 data = value.duplicate(true)
 solution = Vector2i(-4, 3) if value.id == "bird" else Vector2i(5, -3)
 adjustment = Vector2i.ZERO
 look_offset = Vector2.ZERO
 camera.transform = Transform3D.IDENTITY
 camera.fov = 55.0
 checker.configure(data)
 update_layout()
 field.show_constellation(data)
 lines.camera = camera
 lines.data = data
 lines.strength = 0.0
 lines.reveal_progress = 0.0
 refresh_buttons()
func adjust(change: Vector2i) -> void:
 if is_capturing: return
 var updated := (adjustment + change).clamp(Vector2i(-STEP_LIMIT, -STEP_LIMIT), Vector2i(STEP_LIMIT, STEP_LIMIT))
 if updated == adjustment: return
 adjustment = updated
 checker.elapsed = 0.0
 update_layout()
 for i in field.key_stars.size():
  field.key_stars[i].position = data.positions[i]
func update_layout() -> void:
 # Keep the original authored points in three-dimensional world space.
 # Only the real perspective camera orbits; depth and parallax remain intact.
 var angles := source_data.reference_angles + Vector2(adjustment - solution) * STEP_ANGLE + look_offset
 var basis := Basis.from_euler(Vector3(angles.y, angles.x, 0))
 camera.transform = Transform3D(basis, basis * Vector3(0, 0, source_data.orbit_radius))
 data.positions = source_data.positions.duplicate()
 lines.queue_redraw()
func refresh_buttons() -> void:
 capture.visible = checker.completed and checker.error < data.error_threshold * 3.0
 capture.text = LocalizationSystem.text("已收入观测册 · 再拍一张" if ObservatoryState.collected[data.id] else "拍下这片星光")
 next.visible = ObservatoryState.discovered.bird
 next.text = LocalizationSystem.text("寻找鲸鱼 →" if data.id == "bird" else "重访飞鸟 →")
 $UI/Album.text = LocalizationSystem.text("观测册 · %d / 2" % (int(ObservatoryState.collected.bird) + int(ObservatoryState.collected.whale)))
func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  match event.keycode:
   KEY_ESCAPE: return_requested.emit()
   KEY_LEFT: adjust(Vector2i(-1, 0))
   KEY_RIGHT: adjust(Vector2i(1, 0))
   KEY_UP: adjust(Vector2i(0, -1))
   KEY_DOWN: adjust(Vector2i(0, 1))
func _process(delta: float) -> void:
 if not data: return
 checker.step(camera,data,delta)
 var aligned: bool = checker.completed and checker.error < data.error_threshold * 3.0
 lines.strength = move_toward(lines.strength,1.0 if aligned else 0.0,delta*1.8)
 field.set_brightness(0.95 + checker.attraction*0.4 + lines.strength*2.2)
 capture.visible = aligned and not is_capturing
 if not checker.completed:
  hint.text = LocalizationSystem.text("观测册") + "  /  " + LocalizationSystem.text(data.title) + "\n" + (LocalizationSystem.text("轮廓已对齐，等待星光相连……") if checker.elapsed > 0.05 else LocalizationSystem.text(data.hint) + "\n" + LocalizationSystem.text("转动望远镜寻找完整轮廓，对准后停留片刻。"))
 lines.queue_redraw()
func found() -> void:
 ObservatoryState.discovered[data.id] = true
 ObservatoryState.save_state()
 ObservatoryAudio.feedback(true)
 lines.reveal_progress = 0.0
 reveal_tween = create_tween()
 reveal_tween.tween_property(lines,"reveal_progress",1.0,1.4).set_trans(Tween.TRANS_SINE)
 hint.text = LocalizationSystem.text("观测册") + "  /  " + LocalizationSystem.text(data.title) + "\n" + LocalizationSystem.text("星光在这里相遇了。")
 refresh_buttons()
func collect() -> void:
 if is_capturing: return
 is_capturing = true
 for child in $UI.get_children():
  if child != lines: child.hide()
 await RenderingServer.frame_post_draw
 var folder := "user://album"
 DirAccess.make_dir_recursive_absolute(folder)
 var path := folder.path_join(data.id+".png")
 var result := get_viewport().get_texture().get_image().save_png(path)
 is_capturing = false
 for child in $UI.get_children(): child.show()
 if result == OK:
  ObservatoryState.collected[data.id] = true
  ObservatoryState.save_state()
  hint.text = LocalizationSystem.text("观测册") + "  /  " + LocalizationSystem.text(data.title) + "\n" + LocalizationSystem.text("已收藏，星光留在了相册里。")
 else: hint.text = LocalizationSystem.text("照片暂时无法保存，请检查存储空间。")
 refresh_buttons()
