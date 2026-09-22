extends SceneTree
## Offline geometry import. No image synthesis or measured-depth invention.
## Area-weighted samples preserve the supplied STL surface, with an explicitly
## removed printer pedestal for M16. Ship native resources, not runtime STL parsers.
func _initialize() -> void:
	call_deferred("build")

func build() -> void:
	for id in ["eta_carinae", "pillars"]:
		var folder := "res://extensions/observatory/assets/nebulae/"
		var bytes := FileAccess.get_file_as_bytes(folder + id + ".stl")
		var count := bytes.decode_u32(80)
		assert(bytes.size() == 84 + count * 50, "Invalid binary STL")
		var triangles: Array[PackedVector3Array] = []
		var areas := PackedFloat64Array()
		var area := 0.0
		var bounds := AABB()
		for i in count:
			var face := PackedVector3Array()
			for j in 3:
				var at := 84 + i * 50 + 12 + j * 12
				var p := Vector3(bytes.decode_float(at), bytes.decode_float(at+8), -bytes.decode_float(at+4))
				face.append(p)
			# M16 STL includes a circular printing base (not part of the nebula).
			if id == "pillars" and minf(face[0].y, minf(face[1].y, face[2].y)) < 30.0: continue
			var weight := (face[1]-face[0]).cross(face[2]-face[0]).length() * 0.5
			if weight < 0.0000001: continue
			if triangles.is_empty(): bounds=AABB(face[0],Vector3.ZERO)
			for p in face: bounds = bounds.expand(p)
			area += weight
			areas.append(area)
			triangles.append(face)
		var rng := RandomNumberGenerator.new()
		rng.seed = 98271
		var points := PackedVector3Array()
		for i in 120000:
			var triangle: PackedVector3Array = triangles[mini(areas.bsearch(rng.randf()*area),triangles.size()-1)]
			var u := sqrt(rng.randf())
			var v := rng.randf()
			var point := triangle[0]*(1-u)+triangle[1]*(u*(1-v))+triangle[2]*(u*v)
			points.append((point-bounds.get_center()) * (34.0 / bounds.size[bounds.get_longest_axis_index()]))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = points
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays)
		assert(ResourceSaver.save(mesh,folder+id+".res",ResourceSaver.FLAG_COMPRESS)==OK)
		# Continuous geometry retains fine contours without particle speckle.
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for face in triangles:
			for point in face:
				var p := (point-bounds.get_center()) * (34.0 / bounds.size[bounds.get_longest_axis_index()])
				surface.set_uv(Vector2(p.x/34.0+.5,.5-p.y/34.0))
				surface.add_vertex(p)
		surface.index()
		surface.generate_normals()
		assert(ResourceSaver.save(surface.commit(),folder+id+"_surface.res",ResourceSaver.FLAG_COMPRESS)==OK)
		print("IMPORTED ",id," source triangles=",count," sampled=",points.size()," dimensions=",bounds.size)
	quit()
