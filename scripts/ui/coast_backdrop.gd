extends Control
## Authored time-of-day plates are separate from the foreground lighting pass.
const DAY=preload("res://art/user_scenes/lookout_approach.png")
const DUSK=preload("res://art/time_of_day/coast_dusk.png")
const NIGHT=preload("res://art/time_of_day/coast_night.png")
const RAIN=preload("res://art/time_of_day/coast_rain.png")
var stage: Control
var panorama: TextureRect

func _ready() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE
	show_behind_parent=true
	panorama=TextureRect.new(); panorama.texture=DAY
	panorama.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; panorama.mouse_filter=MOUSE_FILTER_IGNORE
	var sky_material := ShaderMaterial.new(); sky_material.shader=preload("res://scripts/ui/coast_sky.gdshader")
	sky_material.set_shader_parameter("dusk_sky",DUSK); sky_material.set_shader_parameter("night_sky",NIGHT); sky_material.set_shader_parameter("rain_sky",RAIN)
	panorama.material=sky_material; panorama.show_behind_parent=true; add_child(panorama)
	WorldAtmosphere.ensure_initialized()
	_process(0.0)

static func weights(minute: float) -> Vector3:
	return preload("res://scripts/ui/world_atmosphere.gd").sky_weights(minute)

func _process(_delta: float) -> void:
	if not is_instance_valid(stage): return
	var area: Rect2=stage.coast_art_rect() if stage.route_id=="lookout_route" else Rect2(-stage.camera_x,0,8000,900)
	panorama.position=area.position; panorama.size=area.size
	panorama.material.set_shader_parameter("blend",WorldAtmosphere.blend)
	var light := WorldAtmosphere.light
	panorama.material.set_shader_parameter("light",Vector3(light.r,light.g,light.b))
	panorama.material.set_shader_parameter("rain",WorldAtmosphere.rain)
	queue_redraw()
func _draw() -> void:
	if not is_instance_valid(stage) or not is_inside_tree(): return
	var area: Rect2 = stage.coast_art_rect() if stage.route_id=="lookout_route" else Rect2(-stage.camera_x,0,8000,900)
	var blend := WorldAtmosphere.blend
	# Gentle water movement stays behind the street and is anchored to the coast.
	var t := Time.get_ticks_msec()*.001
	for i in 28:
		var x := fposmod(float(i)*281+sin(t*.28+i)*8,8000)
		var y := 576.0+posmod(i*19,126)
		var at := area.position+Vector2(x/8000.0,y/900.0)*area.size
		var gleam := (.06+.07*(.5+.5*sin(t*.65+i*1.7)))*(1-blend.z*.6)
		draw_line(at,at+Vector2((22+posmod(i*13,50))*area.size.x/8000,0),Color(.88,.92,.88,gleam),1.4,true)
