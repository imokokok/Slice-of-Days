extends Control
signal enter_requested
const Art = preload("res://scripts/lookout_art.gd")
const COAST = preload("res://assets/background/lookout_coast_night.png")
@export var artwork_size := Vector2(1920,1080)
@export var crop_alignment := Vector2(.5,.5)
const CENTER := 1120.0
const GROUND := 930.0
var factor := 1.0
func _ready() -> void:
 mouse_filter = MOUSE_FILTER_IGNORE
 get_viewport().size_changed.connect(fit_artwork)
 $TelescopeHotspot.enter_requested.connect(func(): enter_requested.emit())
 fit_artwork()
func fit_artwork() -> void:
 var available := get_viewport_rect().size
 factor = minf(available.x/artwork_size.x,available.y/artwork_size.y)
 size = artwork_size * factor
 position = (available-size)*crop_alignment
 var photo := Art.photo_rect(CENTER,GROUND)
 $PhotoScreen.position = photo.position*factor
 $PhotoScreen.size = photo.size*factor
 var telescope := Art.telescope_rect(CENTER,GROUND)
 $TelescopeHotspot.position = telescope.position*factor
 $TelescopeHotspot.size = telescope.size*factor
 queue_redraw()
func _draw() -> void:
 draw_set_transform(Vector2.ZERO,0,Vector2.ONE*factor)
 # The same authored coast used by the town; preserve its aspect ratio.
 var h := float(COAST.get_height())
 draw_rect(Rect2(0,0,1920,1080),Color("0d1b39"))
 draw_rect(Rect2(0,800,1920,GROUND-800),Color("163357"))
 draw_texture_rect_region(COAST,Rect2(0,380,1920,450),Rect2(0,h*.311,COAST.get_width(),h*.345))
 draw_rect(Rect2(0,GROUND,1920,1080-GROUND),Color("737f7d"))
 draw_texture_rect(Art.screen_texture(),Art.screen_rect(CENTER,GROUND),false,Color("9aaec7"))
 draw_texture_rect(Art.platform_texture(),Art.platform_rect(CENTER,GROUND),false,Color("9aaec7"))
 draw_set_transform(Vector2.ZERO)
