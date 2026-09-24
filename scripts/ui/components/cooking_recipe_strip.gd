extends Control
## A compact illustrated pan order for the open recipe page. It reuses the
## exact same raw/prepared textures as the board, pot and finished plate.

const ART = preload("res://scripts/ui/components/cooking_ingredients.gd")

var ingredients: Array[String]=[]
var prepared: Dictionary={}
var addition_states: Dictionary={}
var exposure: Dictionary={}
var cooked_count := -1

func _ready() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE

func update_recipe(ids: Array[String], preparation: Dictionary, additions: Array, actual_count := -1) -> void:
	ingredients=ids.duplicate(); prepared=preparation.duplicate(); cooked_count=actual_count
	addition_states.clear()
	exposure.clear()
	for value in additions:
		var addition: Dictionary=value
		addition_states[str(addition.get("id",""))]=str(addition.get("state","just_right"))
		exposure[str(addition.get("id",""))]=addition
	queue_redraw()

func _tint(id: String, index: int) -> Color:
	if cooked_count>=0 and index>=cooked_count: return Color(1,1,1,0.38)
	var value: Dictionary=exposure.get(id,{})
	return preload("res://scripts/core/cooking_mechanics.gd").food_tint(id,str(addition_states.get(id,"just_right")),float(value.get("cook_progress",0.0)),float(value.get("browning",0.0)),0.55)

func _draw() -> void:
	for i in mini(3,ingredients.size()):
		var id := ingredients[i]
		var texture := ART.texture(id,prepared.has(id))
		if not texture: continue
		var center := Vector2(32+i*76,35)
		var dimensions := texture.get_size()*minf(58.0/texture.get_width(),58.0/texture.get_height())
		var rect := Rect2(center-dimensions*0.5,dimensions)
		if prepared.has(id): ART.draw_prepared(self,id,str(prepared[id]),rect,_tint(id,i))
		else: ART.draw_raw(self,id,rect,_tint(id,i))
		if i<mini(3,ingredients.size())-1:
			draw_line(Vector2(61+i*76,35),Vector2(75+i*76,35),Color("71847c",0.7),2,true)
			draw_line(Vector2(71+i*76,31),Vector2(75+i*76,35),Color("71847c",0.7),2,true)
			draw_line(Vector2(71+i*76,39),Vector2(75+i*76,35),Color("71847c",0.7),2,true)
