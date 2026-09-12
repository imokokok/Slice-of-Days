extends SceneTree
var failures := 0
var main: Node
var state: Node
func check(value: bool, description: String) -> void:
 print(("PASS " if value else "FAIL ") + description)
 if not value: failures += 1
func _init() -> void:
 call_deferred("run")
func settle(seconds: float) -> void:
 await create_timer(seconds).timeout
func run() -> void:
 if ProjectSettings.get_setting("application/config/custom_user_dir_name", "") != "ObservatoryPrototypeTests":
  push_error("Run tests in an isolated test copy. See run_tests.ps1.")
  quit(2)
  return
 state = root.get_node("GameState")
 # This runner uses a separate user-data directory via project override in the test copy.
 state.discovered = {"bird":false,"whale":false}
 state.collected = {"bird":false,"whale":false}
 state.slide_file = ""
 state.slide_index = 0
 state.slide_elapsed = 0.0
 main = load("res://scenes/Main.tscn").instantiate()
 root.add_child(main)
 await settle(0.2)
 var deck = main.get_node("ObservatoryDeck")
 var slideshow = deck.get_node("PhotoScreen")
 check(slideshow.front.texture != null,"empty folder displays placeholder")
 var folder := "user://test_photos"
 DirAccess.make_dir_recursive_absolute(folder)
 for i in 3:
  var img := Image.create(320 + i * 100,180,false,Image.FORMAT_RGB8)
  img.fill(Color(0.12+i*0.12,0.25,0.4))
  if i == 1: img.save_jpg(folder.path_join("02.jpg"))
  else: img.save_png(folder.path_join("0%d.png" % (i+1)))
 slideshow.image_folder = folder
 slideshow.scan_images()
 check(slideshow.files.size()==3,"PNG and JPG scan")
 check(slideshow.files[1].ends_with("02.jpg"),"filename ordering")
 slideshow.hold_seconds = 0.2
 state.slide_elapsed = 0.0
 slideshow.fade_seconds = 0.1
 await settle(0.4)
 check(state.slide_index == 1,"crossfade advances index")
 slideshow.hold_seconds = 100
 var retained_index: int = state.slide_index
 var retained_time: float = state.slide_elapsed
 await main.enter_sky()
 check(not deck.visible and main.sky != null,"telescope enters standalone 3D scene")
 var sky = main.sky
 check(sky.field.get_node("BackgroundStars").multimesh.instance_count == 1000,"1000 batched stars")
 var original_points: PackedVector3Array = sky.data.positions.duplicate()
 var wheel := InputEventMouseButton.new()
 wheel.button_index = MOUSE_BUTTON_WHEEL_UP
 wheel.pressed = true
 sky._unhandled_input(wheel)
 check(sky.target_fov == 55.0,"comfort mode locks FOV")
 var motion := InputEventMouseMotion.new()
 motion.relative = Vector2(20,10)
 sky.dragging = true
 var before_drag: Vector2 = sky.target_angles
 sky._unhandled_input(motion)
 check(sky.target_angles != before_drag,"mouse drag changes view")
 check(sky.angles == sky.target_angles,"comfort mode has no inertial lag")
 var stopped_angles: Vector2 = sky.angles
 await settle(0.15)
 check(sky.angles == stopped_angles,"view stops without continued input")
 check(sky.field.get_node("BackgroundStars").global_transform.is_equal_approx(sky.camera.global_transform),"distant background stays camera-relative")
 check(sky.data.positions == original_points,"player input leaves stars fixed")
 check(not sky.next.visible,"whale locked before bird")
 for data in [sky.BIRD,sky.WHALE]:
  sky.select_constellation(data)
  await settle(0.1)
  var wrong: float = sky.checker.measure(sky.camera,data)
  check(wrong > data.error_threshold * 2,"wrong angle rejected: " + data.id)
  sky.angles = data.reference_angles
  sky.target_angles = data.reference_angles
  sky.update_camera()
  var exact: float = sky.checker.measure(sky.camera,data)
  print("PROJECTION ",data.id," wrong=",wrong," exact=",exact)
  check(exact < 0.0001,"reference projection matches: " + data.id)
  sky.checker.step(sky.camera,data,0.1)
  check(not sky.checker.completed,"hold duration required: " + data.id)
  await settle(data.hold_duration + 0.15)
  check(state.discovered[data.id],"discovery persisted: " + data.id)
  check(sky.capture.visible,"capture available: " + data.id)
  await settle(1.5)
  check(sky.lines.reveal_progress > 0.99 and sky.lines.strength > 0.9,"connected glow after discovery: " + data.id)
  check(sky.next.visible,"unlocked constellation navigation")
  sky.target_fov = 45.0
  sky.camera.fov = 45.0
  check(sky.checker.measure(sky.camera,data) < 0.0001,"FOV normalization: " + data.id)
  sky.camera.transform.origin += Vector3(0,0,100)
  sky.camera.rotate_y(PI)
  check(is_inf(sky.checker.measure(sky.camera,data)),"behind-camera rejection: " + data.id)
  sky.update_camera()
 await main.leave_sky()
 check(deck.visible and main.sky == null,"return restores 2D deck")
 check(state.slide_index==retained_index and state.slide_elapsed>retained_time,"slideshow continues through 3D")
 await main.enter_sky()
 check(main.sky.next.visible,"discovered patterns available on reentry")
 check(state.discovered.bird and state.discovered.whale,"both discoveries survive scene recreation")
 await main.leave_sky()
 main.queue_free()
 root.get_node("AudioManager").waves.stop()
 root.get_node("AudioManager").tone.stop()
 await settle(0.2)
 await process_frame
 print("TEST_RESULT failures=",failures)
 quit(failures)
