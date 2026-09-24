extends Control
## A live serving preview assembled from the ingredients actually cooked.
## The plate never substitutes a canned finished-dish image: layout, timing and
## imperfect heat remain visible in the player's own three ingredients.

const KIT = preload("res://art/ui/pocket_doodles/kitchen_objects.png")
const ART = preload("res://scripts/ui/components/cooking_ingredients.gd")
const ASSETS = preload("res://scripts/ui/production_assets.gd")
const COOKING = preload("res://scripts/core/cooking_mechanics.gd")

var ingredients: Array[String]=[]
var prepared: Dictionary={}
var addition_states: Dictionary={}
var exposure: Dictionary={}
var plating_mode := "space"
var heat := 0.58
var reveal := 1.0:
	set(value):
		reveal=value
		queue_redraw()
var reveal_tween: Tween

func _ready() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE

func update_dish(ids: Array[String], preparation: Dictionary, mode: String, temperature: float, additions: Array) -> void:
	ingredients=ids.duplicate(); prepared=preparation.duplicate(); plating_mode=mode; heat=temperature
	addition_states.clear()
	exposure.clear()
	for value in additions:
		var addition: Dictionary=value
		var id := str(addition.get("id",""))
		addition_states[id]=str(addition.get("state","just_right"))
		exposure[id]=addition
	queue_redraw()

func appear() -> void:
	if reveal_tween and reveal_tween.is_valid(): reveal_tween.kill()
	reveal=0.55 if SettingsSystem.reduced_motion() else 0.0
	reveal_tween=create_tween()
	reveal_tween.tween_property(self,"reveal",1.0,0.08 if SettingsSystem.reduced_motion() else 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _tint(id: String) -> Color:
	var value: Dictionary=exposure.get(id,{})
	return COOKING.food_tint(id,str(addition_states.get(id,"just_right")),float(value.get("cook_progress",0.0)),float(value.get("browning",0.0)),heat)

func _plate(center: Vector2, radius: float) -> void:
	draw_circle(center,radius,Color("f7f0dd"))
	draw_arc(center,radius-4.0,0.0,TAU,64,Color("6f8c87"),3.0,true)
	draw_arc(center,radius-11.0,0.2,PI*1.12,36,Color("d7c9aa",0.55),2.0,true)

func _food(id: String, center: Vector2, extent: Vector2, angle := 0.0) -> void:
	var transform_scale := Vector2.ONE*(0.72+reveal*0.28)
	draw_set_transform(center,angle,transform_scale)
	ART.draw_prepared(self,id,str(prepared.get(id,"")),Rect2(-extent*0.5,extent),_tint(id))
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if ingredients.is_empty(): return
	var center := size*Vector2(0.5,0.5)
	if plating_mode=="share":
		var centers := [center+Vector2(-105,-34),center+Vector2(105,-34),center+Vector2(0,88)]
		for i in mini(3,ingredients.size()):
			_plate(centers[i],70.0)
			_food(ingredients[i],centers[i],Vector2(92,76),(-0.10+i*0.10))
	else:
		var serving := ASSETS.texture("serving_bowl")
		if serving:
			draw_texture_rect(serving,Rect2(center-Vector2(174,142),Vector2(348,284)),false,Color("f6f0df"))
		else:
			draw_texture_rect_region(KIT,Rect2(center-Vector2(180,150),Vector2(360,300)),Rect2(512,512,512,512))
		for i in ingredients.size():
			var spread := 88.0 if plating_mode=="space" else 54.0
			var angle := -PI*0.82+i*PI*0.64
			var at := center+Vector2(cos(angle),sin(angle)*0.56)*spread
			var extent := Vector2(112,92) if plating_mode=="space" else Vector2(138,112)
			_food(ingredients[i],at,extent,-0.12+i*0.12)
	# Steam is intentionally sparse and uses the player's heat instead of a
	# baked illustration so the same plate can honestly represent every recipe.
	var steam_alpha := 0.10+clampf(heat-0.35,0.0,0.5)*0.22
	for i in 3:
		var x := center.x-54+i*54
		draw_arc(Vector2(x,center.y-92-i*5),24,PI*1.05,PI*1.72,18,Color("fffaf0",steam_alpha),3,true)
