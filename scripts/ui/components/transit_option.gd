extends "res://scripts/ui/components/solmere_button.gd"
## Route data with shared mouse, pad, focus and disabled feedback.
var title := ""
var subtitle := ""
var compact := false
var title_label: Label
const P = preload("res://scripts/ui/components/interface_palette.gd")
func _ready() -> void:
	super._ready()
	text=""
	title_label=P.words(self,title,Vector2(18,9),maxf(size.x,custom_minimum_size.x)-36,21)
	if not compact: P.words(self,subtitle,Vector2(18,40),size.x-36,17,P.MUTED)
	tooltip_text=title+"\n"+subtitle
func _draw() -> void:
	super._draw()
	if selected: draw_line(Vector2(3,11),Vector2(3,size.y-11),P.SEA,3,true)
	if is_instance_valid(title_label): title_label.add_theme_color_override("font_color",P.MUTED if disabled else P.INK)
