extends Node3D
@export var background_star_count := 1000
var key_stars: Array[MeshInstance3D] = []
var shader := preload("res://shaders/star_glow.gdshader")
func star(pos: Vector3, size_value: float, color: Color, phase_value: float) -> MeshInstance3D:
 var node := MeshInstance3D.new()
 var quad := QuadMesh.new()
 quad.size = Vector2.ONE * size_value
 node.mesh = quad
 var mat := ShaderMaterial.new()
 mat.shader = shader
 mat.set_shader_parameter("star_color", color)
 mat.set_shader_parameter("phase", phase_value)
 node.material_override = mat
 node.position = pos
 add_child(node)
 return node
func _ready() -> void:
 # 背景星批量渲染，不为几千颗星创建独立节点或材质。
 var rng := RandomNumberGenerator.new()
 rng.seed = 819
 var batch := MultiMeshInstance3D.new()
 batch.name = "BackgroundStars"
 var mesh := QuadMesh.new()
 mesh.size = Vector2(2,2)
 var multi := MultiMesh.new()
 multi.transform_format = MultiMesh.TRANSFORM_3D
 multi.use_custom_data = true
 multi.mesh = mesh
 multi.instance_count = background_star_count
 # 分格采样并保留间距，避免随机分布挤成密集小团。
 var columns := maxi(1, int(ceil(sqrt(background_star_count * 2.9 / 1.76))))
 var rows := maxi(1, int(ceil(float(background_star_count) / columns)))
 for i in background_star_count:
  var yaw := -1.45 + (float(i % columns) + rng.randf_range(0.22,0.78)) / columns * 2.9
  var pitch := -0.88 + (float(i / columns) + rng.randf_range(0.22,0.78)) / rows * 1.76
  var depth := rng.randf_range(50,145)
  var pos := Vector3(sin(yaw)*cos(pitch),sin(pitch),-cos(yaw)*cos(pitch))*depth
  var size_value := rng.randf_range(0.25,0.65)
  if i % 55 == 0: size_value *= 1.25
  multi.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size_value),pos))
  multi.set_instance_custom_data(i,Color(rng.randf(),rng.randf(),rng.randf(),1))
 batch.multimesh = multi
 var mat := ShaderMaterial.new()
 mat.shader = shader
 mat.set_shader_parameter("background_batch",true)
 mat.set_shader_parameter("brightness",0.7)
 batch.material_override = mat
 add_child(batch)
func show_constellation(data: ConstellationData) -> void:
 for s in key_stars:
  remove_child(s)
  s.queue_free()
 key_stars.clear()
 for i in data.positions.size():
  var distance := data.positions[i].distance_to(data.reference_transform().origin)
  var size_value := data.sizes[i] * 2.8 * distance / 30.0
  key_stars.append(star(data.positions[i],size_value,Color(1.0,0.87,0.65) if i in data.main_stars else Color(0.78,0.87,1.0),float(i)*0.618))
func set_brightness(value: float) -> void:
 for s in key_stars: s.material_override.set_shader_parameter("brightness", value)
