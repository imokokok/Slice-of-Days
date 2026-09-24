extends Button
## Layered cooking illustration controlled by Solmere's live recipe state.
const Assets = preload("res://scripts/ui/production_assets.gd")
const FRONT = preload("res://art/ui/third_party_adapted/solmere_pot_front.png")
const FALLBACK = preload("res://art/ui/kitchen_open_redraw/enamel_pan.png")
const COOKING = preload("res://scripts/core/cooking_mechanics.gd")
var ingredients: Array[String] = []
var prepared: Dictionary = {}
var heat := .58
var stirring := 0.0
var stir_count := 0
var stir_tween: Tween
var drop_lift := 0.0:
	set(value):
		drop_lift=value
		queue_redraw()
var drop_tween: Tween
var cooking_phase := "cook"
var addition_states: Dictionary = {}
var exposure: Dictionary = {}
var seasonings: Array[String]=[]

func _ready() -> void:
	name="CookingPot"; accessibility_name="料理锅，拌匀并确认火候"
	mouse_default_cursor_shape=CURSOR_POINTING_HAND; focus_mode=FOCUS_ALL
	for state in ["normal","hover","pressed","disabled","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for signal_name in ["mouse_entered","mouse_exited","focus_entered","focus_exited"]: connect(signal_name,queue_redraw)

func stir() -> void:
	if disabled: return
	stir_count+=1
	WorldSound.play_ui("water" if COOKING.pan_moisture(exposure.values())>=0.45 else "drop")
	if stir_tween and stir_tween.is_valid(): stir_tween.kill()
	stirring=0
	stir_tween=create_tween()
	stir_tween.tween_method(func(value: float): stirring=value; queue_redraw(),0.0,TAU,.02 if SettingsSystem.reduced_motion() else .68)
	stir_tween.tween_callback(func(): stirring=0; queue_redraw())

func update_recipe(ids: Array[String], preparation: Dictionary, temperature: float, phase := "cook", additions: Array = [], layers: Array[String]=[]) -> void:
	var just_added := ids.size()>ingredients.size()
	ingredients=ids.duplicate(); prepared=preparation.duplicate(); heat=temperature; cooking_phase=phase; seasonings=layers.duplicate()
	addition_states.clear()
	exposure.clear()
	for value in additions:
		var addition: Dictionary=value
		var id := str(addition.get("id",""))
		addition_states[id]=str(addition.get("state","just_right"))
		exposure[id]=addition
	if just_added:
		if drop_tween and drop_tween.is_valid(): drop_tween.kill()
		drop_lift=0.35 if SettingsSystem.reduced_motion() else 1.0
		drop_tween=create_tween()
		drop_tween.tween_property(self,"drop_lift",0.0,0.08 if SettingsSystem.reduced_motion() else 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		drop_tween.tween_callback(queue_redraw)
	queue_redraw()

func _food_tint(id: String) -> Color:
	var value: Dictionary=exposure.get(id,{})
	return COOKING.food_tint(id,str(addition_states.get(id,"just_right")),float(value.get("cook_progress",0.0)),float(value.get("browning",0.0)),heat)

func _draw() -> void:
	var back:=Assets.texture("pot_back"); var front: Texture2D=FRONT
	var sx:=size.x/390.0; var sy:=size.y/390.0
	draw_set_transform(Vector2.ZERO,0,Vector2(sx,sy))
	if back:
		draw_texture_rect(back,Rect2(43,134,306,80),false,Color("f0e8d7"))
	else:
		draw_texture_rect(FALLBACK,Rect2(0,0,390,390),false)
	for i in ingredients.size():
		var food_art=preload("res://scripts/ui/components/cooking_ingredients.gd")
		var lift := drop_lift*58.0 if i==ingredients.size()-1 else 0.0
		var slot := (i+stir_count)%maxi(1,ingredients.size())
		var at:=Vector2(98+slot*96+sin(stirring+i)*14,(156 if back else 198)+cos(stirring+i)*11-lift)
		var progress := float((exposure.get(ingredients[i],{}) as Dictionary).get("cook_progress",0.0))
		var width := 103.0*(1.0-0.10*progress)
		var food_rect := Rect2(at-Vector2(width*0.5,54),Vector2(width,108))
		if prepared.has(ingredients[i]): food_art.draw_prepared(self,ingredients[i],str(prepared[ingredients[i]]),food_rect,_food_tint(ingredients[i]))
		else: draw_texture_rect(food_art.texture(ingredients[i]),food_rect,false,_food_tint(ingredients[i]))
		var value: Dictionary=exposure.get(ingredients[i],{})
		var brown := float(value.get("browning",0.0))
		if brown>0.04:
			for mark in 3:
				var x := at.x-18.0+float(mark)*16.0
				draw_arc(Vector2(x,at.y+14.0+float(mark%2)*5.0),5.0,0.0,TAU,12,Color("75452e",brown*0.4),2.0,true)
	if not seasonings.is_empty():
		var palette := {"salt":Color("fff4db"),"pepper":Color("47372d"),"wasabi":Color("8dab6a"),"ketchup":Color("c75d4c"),"herbs":Color("5e8b62")}
		for layer_index in seasonings.size():
			var color: Color=palette.get(seasonings[layer_index],Color.WHITE)
			if seasonings[layer_index] in ["wasabi","ketchup"]:
				var previous := Vector2(158,162+layer_index*8)
				for segment in range(1,7):
					var next := Vector2(158+segment*12,162+layer_index*8+sin(float(segment)*1.6)*7.0)
					draw_line(previous,next,color,4.0,true)
					previous=next
				continue
			for mark in 6:
				var angle := float(mark)*2.4+float(layer_index)*0.65
				draw_circle(Vector2(194+cos(angle)*float(24+(mark*9)%65),169+sin(angle)*float(9+(mark*7)%30)),3.5,color)
	# The front of the pot occludes the lower parts of the food and spoon.
	var spoon:=Assets.texture("kitchen_spoon")
	if spoon and back:
		draw_set_transform(Vector2(235+sin(stirring)*30,55),-.18+sin(stirring)*.25,Vector2(sx,sy))
		draw_texture_rect(spoon,Rect2(-14,-30,34,146),false)
	if back:
		draw_set_transform(Vector2.ZERO,0,Vector2(sx,sy))
		draw_texture_rect(front,Rect2(3,104,384,273),false)
	if heat>.68 and not ingredients.is_empty():
		draw_arc(Vector2(192,350 if back else 322),119,.15,PI-.15,26,Color("d99d70",(heat-.68)*.65),3,true)
	var lid:=Assets.texture("pot_lid")
	if lid and back: draw_texture_rect(lid,Rect2(236,321,145,56),false,Color("f2e4cf"))
	if not disabled and (is_hovered() or has_focus()): draw_line(Vector2(90,383),Vector2(309,383),Color("617b73"),3,true)
	draw_set_transform(Vector2.ZERO)
