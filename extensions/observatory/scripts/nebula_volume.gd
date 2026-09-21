extends Node3D
## Genuine world-space gas samples, rendered in one draw call per nebula.
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
	if entry.has("model"):
		var mesh: ArrayMesh = load(entry.model)
		var points: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for p in points:
			vertices.append(p + Vector3(rng.randf_range(-.1,.1),rng.randf_range(-.1,.1),rng.randf_range(-.1,.1)))
			var color := Color("b46ce0").lerp(Color("ffc48e"), clampf((p.y+17)/34,0,1))
			if image != null:
				var uv := Vector2(clampf(p.x/34+.5,0,1),clampf(.5-p.y/34,0,1))
				color = image.get_pixel(int(uv.x*(image.get_width()-1)),int(uv.y*(image.get_height()-1)))
			color.a = 0.075 * smoothstep(-17.0,-13.0,p.y)
			colors.append(color)
			sizes.append(rng.randf_range(.75,1.1))
	else:
		# Stratified, non-coplanar emission field: no full-image background quad.
		var noise := FastNoiseLite.new()
		noise.seed = 801
		noise.frequency = .016
		for y in 384:
			for x in 384:
				var u := (float(x)+rng.randf())/384
				var v := (float(y)+rng.randf())/384
				var color := image.get_pixel(int(u*(image.get_width()-1)),int(v*(image.get_height()-1)))
				var edge := smoothstep(0.0,.12,minf(minf(u,1-u),minf(v,1-v)))
				var luminance := color.get_luminance()
				if luminance < .035 or edge < .015: continue
				var depth := noise.get_noise_2d(x*256.0/384,y*256.0/384)*9 + (luminance-.5)*5 + rng.randf_range(-1.2,1.2)
				# Perspective compensation preserves the recognisable front view.
				var spread := 1.0-depth/52.0
				vertices.append(Vector3((u-.5)*46*spread,(.5-v)*46*spread,depth))
				color.a = edge * .30
				colors.append(color)
				sizes.append(rng.randf_range(.46,.54))
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
	material.set_shader_parameter("opacity",.52 if entry.has("model") else .88)
	batch.material_override = material
	add_child(batch)
