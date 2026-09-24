extends Node

const Restaurant = preload("res://modules/restaurant/restaurant.tscn")
var paid_sessions: Dictionary = {}
var demo_wallet: float = 0.0
var module: Node

func _ready() -> void :
	_enter_restaurant()

func _enter_restaurant() -> void :
	module = Restaurant.instantiate()
	module.configure({"player_id": "local_demo", "display_name": "100饭店主厨", "shift_seconds": 600.0 if "--live-preview" in OS.get_cmdline_user_args() else 240.0})
	module.shift_completed.connect(_on_settlement)
	module.exit_requested.connect(_on_exit)
	add_child(module)
	if "--live-preview" in OS.get_cmdline_user_args():
		module.call_deferred("_start_shift")
		module.call_deferred("_notify", "第一位客人已经来了！右侧查看要求，点击客人聊聊口味。")
		if "--recipe-preview" in OS.get_cmdline_user_args():
			module.call_deferred("_show_cookbook")

func _on_settlement(result: Dictionary) -> void :

	var receipt: String = str(result.get("session_id", ""))
	if receipt.is_empty() or paid_sessions.has(receipt):
		return
	paid_sessions[receipt] = true
	demo_wallet += float(result.get("share", 0.0))
	print("HOST_SETTLEMENT ", JSON.stringify(result))

func _on_exit() -> void :
	module.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var layer: = CanvasLayer.new()
	add_child(layer)
	var bg: = ColorRect.new()
	bg.color = Color("f8edcf")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var box: = VBoxContainer.new()
	box.position = Vector2(480, 280)
	box.size = Vector2(640, 340)
	box.add_theme_constant_override("separation", 24)
	layer.add_child(box)
	var font: = FontVariation.new()
	font.base_font = load("res://modules/restaurant/assets/fonts/noto_sans_sc.ttf")
	font.variation_opentype = {2003265652: 400.0}
	var title: = Label.new()
	title.text = "已回到主游戏示例"
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("284b47"))
	box.add_child(title)
	var info: = Label.new()
	info.text = "示例钱包：¥ %.2f\n小游戏已释放场景，由主游戏接管。" % demo_wallet
	info.add_theme_font_override("font", font)
	info.add_theme_font_size_override("font_size", 20)
	info.add_theme_color_override("font_color", Color("64756a"))
	box.add_child(info)
	var again: = Button.new()
	again.text = "再进入饭店"
	again.custom_minimum_size.y = 54
	again.add_theme_font_override("font", font)
	again.pressed.connect( func(): layer.queue_free();_enter_restaurant())
	box.add_child(again)
	var close: = Button.new()
	close.text = "退出演示"
	close.custom_minimum_size.y = 48
	close.add_theme_font_override("font", font)
	close.pressed.connect( func(): get_tree().quit())
	box.add_child(close)
