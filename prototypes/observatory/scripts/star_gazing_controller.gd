extends Node3D
signal return_requested
const BIRD = preload("res://resources/bird_constellation.tres")
const WHALE = preload("res://resources/whale_constellation.tres")
@export var drag_sensitivity := 0.001
@export var comfort_mode := true
@export var comfort_range := Vector2(0.22, 0.15)
@export var damping := 5.0
@export var rotation_limit := Vector2(0.85, 0.48)
var data: ConstellationData
var angles := Vector2.ZERO
var target_angles := Vector2.ZERO
var target_fov := 55.0
var dragging := false
var freeze_time := 0.0
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
 select_constellation(WHALE if GameState.discovered.bird and not GameState.discovered.whale else BIRD)
func select_constellation(value: ConstellationData) -> void:
 if reveal_tween: reveal_tween.kill()
 data = value
 var side := -1.0 if randf() < 0.5 else 1.0
 angles = data.reference_angles + Vector2(side*randf_range(0.36,0.52),randf_range(-0.24,0.24))
 angles = angles.clamp(-rotation_limit,rotation_limit)
 if comfort_mode:
  angles = data.reference_angles + Vector2(side*randf_range(0.14,0.2),randf_range(-0.09,0.09))
 target_angles = angles
 target_fov = data.reference_fov
 camera.fov = target_fov
 checker.configure(data)
 field.show_constellation(data)
 hint.text = "观测册  /  " + data.title + "
" + data.hint
 lines.camera = camera
 lines.data = data
 lines.strength = 0.0
 lines.reveal_progress = 0.0
 refresh_buttons()
 update_camera()
 if comfort_mode: $UI/Instructions.text = "轻拖微调 · 松手即停 · 焦距锁定 · ESC 返回"
func refresh_buttons() -> void:
 capture.visible = checker.completed and checker.error < data.error_threshold * 3.0
 capture.text = "已收入观测册 · 再拍一张" if GameState.collected[data.id] else "拍下这片星光"
 next.visible = GameState.discovered.bird
 next.text = "寻找鲸鱼 →" if data.id == "bird" else "重访飞鸟 →"
 $UI/Album.text = "观测册 · %d / 2" % (int(GameState.collected.bird) + int(GameState.collected.whale))
func update_camera() -> void:
 var basis := Basis.from_euler(Vector3(angles.y,angles.x,0))
 camera.transform = Transform3D(basis,basis * Vector3(0,0,data.orbit_radius))
 if comfort_mode:
  # 远处星幕作为固定视觉参照，仅关键星图产生有限视差。
  field.get_node("BackgroundStars").global_transform = camera.global_transform
func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
  return_requested.emit()
 if event is InputEventMouseButton:
  if event.button_index == MOUSE_BUTTON_LEFT: dragging = event.pressed
  if not comfort_mode:
   if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP: target_fov = clampf(target_fov-2,42,66)
   if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN: target_fov = clampf(target_fov+2,42,66)
 if event is InputEventMouseMotion and dragging and freeze_time <= 0:
  target_angles -= event.relative * drag_sensitivity * (1.0-checker.attraction)
  target_angles.x = clampf(target_angles.x,-rotation_limit.x,rotation_limit.x)
  target_angles.y = clampf(target_angles.y,-rotation_limit.y,rotation_limit.y)
  if comfort_mode:
   target_angles = target_angles.clamp(data.reference_angles-comfort_range,data.reference_angles+comfort_range)
   angles = target_angles
func _process(delta: float) -> void:
 if not data: return
 if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): dragging = false
 freeze_time = maxf(0.0, freeze_time-delta)
 if comfort_mode:
  angles = target_angles
  camera.fov = data.reference_fov
 else:
  angles = angles.lerp(target_angles,1.0-exp(-damping*delta))
  camera.fov = lerpf(camera.fov,target_fov,1.0-exp(-damping*delta))
 update_camera()
 checker.step(camera,data,delta)
 var aligned: bool = checker.completed and checker.error < data.error_threshold * 3.0
 lines.strength = move_toward(lines.strength,1.0 if aligned else 0.0,delta*1.8)
 field.set_brightness(0.95 + checker.attraction*0.4 + lines.strength*2.2)
 capture.visible = aligned and not is_capturing
 if not checker.completed:
  hint.text = "观测册  /  " + data.title + "\n" + ("星点正在靠拢，稳住视角……" if checker.elapsed > 0.05 else data.hint + "\n寻找完整轮廓，稳住片刻，星光会自行相连。")
 lines.queue_redraw()
func found() -> void:
 GameState.discovered[data.id] = true
 GameState.save_state()
 freeze_time = 0.5
 target_angles = angles
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
