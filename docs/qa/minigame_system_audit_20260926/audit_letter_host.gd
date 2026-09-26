extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var gs=root.get_node("GameState");var router=root.get_node("SceneRouter")
 root.get_node("ChapterSystem").start_new_game();gs.switch_to_role("A",3,true)
 gs.current_minute=610;gs.current_location="handcraft_shop"
 assert(router.gameplay_module("ghostwriting","street:handcraft_shop"))
 await create_timer(.8).timeout
 var host=current_scene;var game=host.experience
 for i in 600:
  if game.ready_done: break
  await process_frame
 assert(game.ready_done)
 game.smoke=true
 await load("res://audit_letter_actions.gd").run(game,host)
