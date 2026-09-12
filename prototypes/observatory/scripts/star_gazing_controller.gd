extends Node3D
signal return_requested
const BIRD = preload("res://resources/bird_constellation.tres")
const WHALE = preload("res://resources/whale_constellation.tres")
const STEP_ANGLE := 0.04
const STEP_LIMIT := 12
var source_data: ConstellationData
var data: ConstellationData
var adjustment := Vector2i.ZERO
var solution := Vector2i.ZERO
var dial_label: Label
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
 select_constellation(WHALE if GameState.discovered.bird and not GameState.discovered.whale else BIRD)
func build_controls() -> void:
 var panel := VBoxContainer.new()
 panel.name = "Adjustment"
 $UI.add_child(panel)
 panel.anchor_left = 0.5
 panel.anchor_right = 0.5
 panel.anchor_top = 1.0
 panel.anchor_bottom = 1.0
 panel.offset_left = -230
 panel.offset_right = 230
 panel.offset_top = -190
 panel.offset_bottom = -25
 dial_label = Label.new()
 dial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 panel.add_child(dial_label)
 for axis in 2:
  var row := HBoxContainer.new()
  row.alignment = BoxContainer.ALIGNMENT_CENTER
  panel.add_child(row)
  for direction in [-1, 1]:
   var button := Button.new()
   button.text = (["水平 −", "水平 +"] if axis == 0 else ["垂直 −", "垂直 +"])[0 if direction < 0 else 1]
   button.custom_minimum_size = Vector2(190, 48)
   button.pressed.connect(adjust.bind(Vector2i(direction, 0) if axis == 0 else Vector2i(0, direction)))
   row.add_child(button)
 $UI/Instructions.text = "固定星图 · 点击按钮逐档调整 · 对准后停留 1.25 秒 · ESC 返回"
func select_constellation(value: ConstellationData) -> void:
 if reveal_tween: reveal_tween.kill()
 source_data = value
 # Only the display copy changes; authored world coordinates stay immutable.
 data = value.duplicate(true)
 solution = Vector2i(-4, 3) if value.id == "bird" else Vector2i(5, -3)
 adjustment = Vector2i.ZERO
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
 # Calculate a virtual projection, then place its points on a fixed-depth plane.
 # The real camera and distant background never move, and no motion is tweened.
 var angles := source_data.reference_angles + Vector2(adjustment - solution) * STEP_ANGLE
 var basis := Basis.from_euler(Vector3(angles.y, angles.x, 0))
 var inverse := Transform3D(basis, basis * Vector3(0, 0, source_data.orbit_radius)).affine_inverse()
 var points := PackedVector3Array()
 for point in source_data.positions:
  var projected: Vector3 = inverse * point
  points.append(projected * (30.0 / -projected.z))
 data.positions = points
 dial_label.text = "水平 %+d     垂直 %+d" % [adjustment.x, adjustment.y]
 lines.queue_redraw()
func refresh_buttons() -> void:
 capture.visible = checker.completed and checker.error < data.error_threshold * 3.0
 capture.text = "已收入观测册 · 再拍一张" if GameState.collected[data.id] else "拍下这片星光"
 next.visible = GameState.discovered.bird
 next.text = "寻找鲸鱼 →" if data.id == "bird" else "重访飞鸟 →"
 $UI/Album.text = "观测册 · %d / 2" % (int(GameState.collected.bird) + int(GameState.collected.whale))
func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
  return_requested.emit()
func _process(delta: float) -> void:
 if not data: return
 checker.step(camera,data,delta)
 var aligned: bool = checker.completed and checker.error < data.error_threshold * 3.0
 lines.strength = move_toward(lines.strength,1.0 if aligned else 0.0,delta*1.8)
 field.set_brightness(0.95 + checker.attraction*0.4 + lines.strength*2.2)
 capture.visible = aligned and not is_capturing
 if not checker.completed:
  hint.text = "观测册  /  " + data.title + "\n" + ("轮廓已对齐，等待星光相连……" if checker.elapsed > 0.05 else data.hint + "\n点击按钮寻找完整轮廓，对准后停留片刻。")
 lines.queue_redraw()
func found() -> void:
 GameState.discovered[data.id] = true
 GameState.save_state()
 AudioManager.feedback(true)
 lines.reveal_progress = 0.0
 reveal_tween = create_tween()
 reveal_tween.tween_property(lines,"reveal_progress",1.0,1.4).set_trans(Tween.TRANS_SINE)
 hint.text = "观测册  /  " + data.title + "
星光在这里相遇了。"
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
  GameState.collected[data.id] = true
  GameState.save_state()
  hint.text = "观测册  /  " + data.title + "
已收藏，星光留在了相册里。"
 else: hint.text = "照片暂时无法保存，请检查存储空间。"
 refresh_buttons()
