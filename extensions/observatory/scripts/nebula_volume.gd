extends Node3D
## Continuous geometry and world-space gas rendering, without a sky photograph.
## Official models use their supplied geometry. Orion is a labelled artistic
## reconstruction: image colour supplies emission, never scientific distance.
var sample_count := 0
var depth_range := Vector2.ZERO
var batch: MultiMeshInstance3D

func build(entry: Dictionary) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var sizes := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 36217
	var image: Image
	if not str(entry.get("image", "")).is_empty():
		var texture: Texture2D = load(entry.image)
		image = texture.get_image()
		if image.is_compressed(): image.decompress()
	_build_continuous_surface(entry,image)
	if not entry.has("model"): return
	if entry.has("model"):
		var mesh: ArrayMesh = load(entry.model)
		var points: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for p in points:
			vertices.append(p + Vector3(rng.randf_range(-.1,.1),rng.randf_range(-.1,.1),rng.randf_range(-.1,.1)))
			var color := Color("b46ce0").lerp(Color("ffc48e"), clampf((p.y+17)/34,0,1))
			if image != null:
				var uv := Vector2(clampf(p.x/34+.5,0,1),clampf(.5-p.y/34,0,1))
				color = image.get_pixel(int(uv.x*(image.get_width()-1)),int(uv.y*(image.get_height()-1)))
			color.a = 0.58 * smoothstep(-17.0,-15.0,p.y)
			colors.append(color)
			sizes.append(rng.randf_range(.22,.30))
	sample_count = vertices.size()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	multi.mesh = quad
	multi.instance_count = sample_count
	depth_range = Vector2(INF,-INF)
	for i in sample_count:
		multi.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*sizes[i]),vertices[i]))
		multi.set_instance_color(i,colors[i])
		depth_range.x = minf(depth_range.x,vertices[i].z)
		depth_range.y = maxf(depth_range.y,vertices[i].z)
	batch = MultiMeshInstance3D.new()
	batch.name = "NebulaGas"
	batch.multimesh = multi
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = preload("res://extensions/observatory/shaders/nebula_dust.gdshader")
	material.set_shader_parameter("opacity",.012)
	batch.material_override = material
	add_child(batch)

func _build_continuous_surface(entry: Dictionary, image: Image) -> void:
	# A world-space gaseous surround, without decorative stars or a sky photo.
	var atmosphere := MeshInstance3D.new(); atmosphere.name="GaseousSurround"
	var box := BoxMesh.new(); box.size=Vector3.ONE*400.0; atmosphere.mesh=box
	var fog := ShaderMaterial.new(); fog.shader=preload("res://extensions/observatory/shaders/nebula_atmosphere.gdshader"); fog.render_priority=-100
	fog.set_shader_parameter("gas_color",Color("8c584a") if entry.id=="eta_carinae" else Color("426c86") if entry.id=="pillars" else Color("704c7e"))
	atmosphere.material_override=fog; atmosphere.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(atmosphere)
	if not entry.has("model"):
		var gas := MeshInstance3D.new(); gas.name="IntegratedGasVolume"
		var bounds := BoxMesh.new(); bounds.size=Vector3.ONE*144.0; gas.mesh=bounds
		var shader := ShaderMaterial.new(); shader.shader=preload("res://extensions/observatory/shaders/nebula_cloud_volume.gdshader"); shader.render_priority=-50
		shader.set_shader_parameter("emission_image",load(entry.image))
		gas.material_override=shader; gas.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(gas)
	var geometry := MeshInstance3D.new()
	geometry.name="ContinuousNebula"
	var material := ShaderMaterial.new()
	material.shader=preload("res://extensions/observatory/shaders/nebula_surface.gdshader")
	material.set_shader_parameter("has_image",image!=null)
	if image!=null: material.set_shader_parameter("emission_image",load(entry.image))
	if entry.has("model"):
		geometry.mesh=load(str(entry.model).replace(".res","_surface.res"))
	else:
		material.set_shader_parameter("reconstructed",true)
		# Two curved, joined gas boundaries make a volume, not a photo card.
		# Colour is observational; depth and thickness are an artistic reconstruction.
		var vertices := PackedVector3Array()
		var uvs := PackedVector2Array()
		var indices := PackedInt32Array()
		var noise := FastNoiseLite.new(); noise.seed=801; noise.frequency=.016
		const GRID := 256
		for side in 2:
			for y in GRID+1:
				for x in GRID+1:
					var uv := Vector2(float(x)/GRID,float(y)/GRID)
					var edge := sin(uv.x*PI)*sin(uv.y*PI)
					var front := noise.get_noise_2d(x,y)*16
					var z := front - side*edge*16.0
					var spread := 1.0-front/40.0
					vertices.append(Vector3((uv.x-.5)*72*spread,(.5-uv.y)*72*spread,z))
					uvs.append(uv)
			for y in GRID:
				for x in GRID:
					var a := side*(GRID+1)*(GRID+1)+y*(GRID+1)+x
					indices.append_array(PackedInt32Array([a,a+1,a+GRID+1,a+1,a+GRID+2,a+GRID+1]))
		var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_TEX_UV]=uvs; arrays[Mesh.ARRAY_INDEX]=indices
		var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		geometry.mesh=mesh
		sample_count=vertices.size(); depth_range=Vector2(INF,-INF)
		for point in vertices:
			depth_range.x=minf(depth_range.x,point.z); depth_range.y=maxf(depth_range.y,point.z)
	geometry.material_override=material
	geometry.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(geometry)
