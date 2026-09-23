extends Control
## The same saved transaction used by the wallet and Life Log, rendered as paper.
const P = preload("res://scripts/ui/components/interface_palette.gd")
var receipt: Dictionary = {}
var collection_note := ""

func _ready() -> void:
	name="PaymentReceipt"; add_to_group("native_confirmation"); add_to_group("meta_modal")
	set_anchors_and_offsets_preset(PRESET_FULL_RECT); mouse_filter=MOUSE_FILTER_STOP; theme=P.theme_for_tools()
	var dim := ColorRect.new(); dim.color=Color("183b50",.72); dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT); add_child(dim)
	var sheet := Control.new(); sheet.position=Vector2(500,34); sheet.size=Vector2(600,830); add_child(sheet)
	# Generated paper has soft alpha; back the writing area with opaque stock.
	var stock := Polygon2D.new(); stock.color=P.CREAM
	stock.polygon=PackedVector2Array([Vector2(65,96),Vector2(523,95),Vector2(535,354),Vector2(562,794),Vector2(48,797),Vector2(67,343)])
	sheet.add_child(stock)
	preload("res://scripts/ui/components/handmade_assets.gd").picture(sheet,"receipt",Vector2.ZERO,Vector2(600,830),true)
	P.words(sheet,"SOLMERE",Vector2(112,120),390,31,P.SEA)
	P.words(sheet,"相机交接凭条" if receipt.get("kind","")=="handover" else "杂货店 · 摄影柜台",Vector2(112,163),390,21,P.SEA)
	P.words(sheet,"DAY %02d   %02d:%02d" % [int(receipt.get("day",1)),int(receipt.get("minute",0))/60,int(receipt.get("minute",0))%60],Vector2(112,201),390,18,P.MUTED)
	var rows := ScrollContainer.new(); rows.position=Vector2(112,255); rows.size=Vector2(384,145)
	rows.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; sheet.add_child(rows)
	var stack := VBoxContainer.new(); stack.size_flags_horizontal=SIZE_EXPAND_FILL; stack.add_theme_constant_override("separation",12); rows.add_child(stack)
	for line in receipt.get("line_items",[]):
		var text := Label.new(); text.text=LocalizationSystem.text("%s × %d\n%d 元" % [LocalizationSystem.text(str(line.name)),int(line.quantity),int(line.total)])
		text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; text.size_flags_horizontal=SIZE_EXPAND_FILL; stack.add_child(text)
	P.words(sheet,"整理旧货 · %d 分钟" % int(receipt.help_minutes) if receipt.get("kind","")=="handover" else "实付  %d 元" % int(receipt.get("total",0)),Vector2(112,425),380,31,P.SEA)
	P.words(sheet,"付款后余额  %d 元" % int(receipt.get("balance",0)),Vector2(112,473),380,18,P.MUTED)
	P.words(sheet,collection_note if not collection_note.is_empty() else "小票已存入生活记录的素材夹。\n摄影柜台也能再次查看。",Vector2(112,533),377,19,P.INK)
	var close := preload("res://scripts/ui/components/solmere_button.gd").new()
	close.text=LocalizationSystem.text("收好小票")+"  ·  "+SettingsSystem.binding_text("ui_cancel"); close.position=Vector2(110,664); close.size=Vector2(385,52)
	close.pressed.connect(queue_free); sheet.add_child(close); close.grab_focus()
	if not SettingsSystem.reduced_motion():
		sheet.position.y+=12; sheet.modulate.a=0
		var tween := create_tween().set_parallel(); tween.tween_property(sheet,"position:y",34,.18); tween.tween_property(sheet,"modulate:a",1,.18)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		queue_free(); get_viewport().set_input_as_handled()
