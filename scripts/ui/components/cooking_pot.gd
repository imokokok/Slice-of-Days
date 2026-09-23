extends Button
## Little Chef layered illustrations, controlled by Solmere's real recipe state.
const Assets = preload("res://scripts/ui/production_assets.gd")
const FRONT = preload("res://art/ui/third_party_adapted/solmere_pot_front.png")
var ingredients: Array[String] = []
var prepared: Dictionary = {}
var heat := .58
var stirring := 0.0
var stir_tween: Tween

func _ready() -> void:
	name="CookingPot"; accessibility_name="料理锅，拌匀并确认火候"
	mouse_default_cursor_shape=CURSOR_POINTING_HAND; focus_mode=FOCUS_ALL
	for state in ["normal","hover","pressed","disabled","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for signal_name in ["mouse_entered","mouse_exited","focus_entered","focus_exited"]: connect(signal_name,queue_redraw)

func stir() -> void:
	if disabled: return
	WorldSound.play_ui("water")
	if stir_tween and stir_tween.is_valid(): stir_tween.kill()
	stirring=0
	stir_tween=create_tween()
	stir_tween.tween_method(func(value: float): stirring=value; queue_redraw(),0.0,TAU,.02 if SettingsSystem.reduced_motion() else .68)
	stir_tween.tween_callback(func(): stirring=0; queue_redraw())

func update_recipe(ids: Array[String], preparation: Dictionary, temperature: float) -> void:
	ingredients=ids.duplicate(); prepared=preparation.duplicate(); heat=temperature
	queue_redraw()

func _draw() -> void:
	var back:=Assets.texture("pot_back"); var front: Texture2D=FRONT
	if not back or not front: return
	var sx:=size.x/390.0; var sy:=size.y/390.0
	draw_set_transform(Vector2.ZERO,0,Vector2(sx,sy))
	draw_texture_rect(back,Rect2(43,134,306,80),false,Color("f0e8d7"))
	for i in ingredients.size():
		var food:=preload("res://scripts/ui/components/cooking_ingredients.gd").texture(ingredients[i],prepared.has(ingredients[i]))
		var at:=Vector2(116+i*60+sin(stirring+i)*8,154+cos(stirring+i)*6)
		draw_texture_rect(food,Rect2(at-Vector2(32,35),Vector2(64,70)),false)
	# The front of the pot occludes the lower parts of the food and spoon.
	var spoon:=Assets.texture("kitchen_spoon")
	if spoon:
		draw_set_transform(Vector2(235+sin(stirring)*30,55),-.18+sin(stirring)*.25,Vector2(sx,sy))
		draw_texture_rect(spoon,Rect2(-14,-30,34,146),false)
	draw_set_transform(Vector2.ZERO,0,Vector2(sx,sy))
	draw_texture_rect(front,Rect2(3,104,384,273),false)
	if heat>.68 and not ingredients.is_empty():
		draw_arc(Vector2(192,361),119,.15,PI-.15,26,Color("d99d70",(heat-.68)*.65),3,true)
	var lid:=Assets.texture("pot_lid")
	if lid: draw_texture_rect(lid,Rect2(236,321,145,56),false,Color("f2e4cf"))
	if not disabled and (is_hovered() or has_focus()): draw_line(Vector2(90,383),Vector2(309,383),Color("617b73"),3,true)
	draw_set_transform(Vector2.ZERO)
