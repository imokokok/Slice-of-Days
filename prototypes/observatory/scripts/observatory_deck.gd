extends Control
signal enter_requested
@export var artwork_size := Vector2(1961, 802)
@export var crop_alignment := Vector2(0.8, 0.5)
func _ready() -> void:
 get_viewport().size_changed.connect(fit_artwork)
 fit_artwork()
 $TelescopeHotspot.enter_requested.connect(func(): enter_requested.emit())
func fit_artwork() -> void:
 # 等比铺满 16:9，裁切宽图两侧；偏右取景保留幕布和望远镜。
 # 背景、幕布与热点使用同一画布，一起缩放和定位。
 var available := get_viewport_rect().size
 var factor := maxf(available.x / artwork_size.x, available.y / artwork_size.y)
 size = artwork_size * factor
 position = (available - size) * crop_alignment
