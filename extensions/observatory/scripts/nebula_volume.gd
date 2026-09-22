extends Node3D
## Image-space observation stage. A nebula is one real telescope photograph
## viewed inside a lightweight 3D camera. Dragging changes the camera angle and
## the wheel changes distance, but the image is never blurred into fake volume
## geometry or replaced with a generated nebula model.
var sample_count := 0
var depth_range := Vector2.ZERO
var source_bounds := AABB()
var components: Array[MeshInstance3D]=[]
var batch: MultiMeshInstance3D
const GAS = preload("res://extensions/observatory/shaders/observed_structure.gdshader")

func build(entry: Dictionary) -> void:
	for child in get_children(): remove_child(child); child.queue_free()
	components.clear(); sample_count=0; source_bounds=AABB()
	var image_path := str(entry.get("image", ""))
	if not image_path.is_empty() and ResourceLoader.exists(image_path):
		_build_image_depth(entry,load(image_path))
		return
	# Keep the published model as a data fallback for old saves whose catalog
	# predates image sources. New catalog entries always take the image path.
	if not entry.has("model"): return
	var path := str(entry.model)
	var asset=load(path)
	if path.ends_with(".glb"):
		# Godot's GLTFDocument keeps the original NASA GLB geometry available even
		# before the editor has generated a .import sidecar.
		var document := GLTFDocument.new(); var state := GLTFState.new()
		var error := document.append_from_file(path,state)
		if error==OK:
			var scene: Node3D=document.generate_scene(state); add_child(scene); _collect_meshes(scene)
		else: push_error("Unable to read published nebula GLB: "+path)
	elif asset is PackedScene:
		var scene: Node3D=asset.instantiate(); add_child(scene); _collect_meshes(scene)
	else:
		var mesh := MeshInstance3D.new(); mesh.name="PublishedStructure"
		mesh.mesh=load(path.replace(".res","_surface.res")); add_child(mesh); components.append(mesh)
	var first := true
	for mesh in components:
		var box := mesh.global_transform * mesh.get_aabb()
		if first: source_bounds=box; first=false
		else: source_bounds=source_bounds.merge(box)
	var factor := 34.0/maxf(source_bounds.get_longest_axis_size(),.001)
	var center := source_bounds.get_center()
	# A single shared similarity transform preserves relative positions and sizes.
	var group := Node3D.new(); group.name="ObservedGeometry"; add_child(group)
	var top_nodes := get_children().duplicate()
	for child in top_nodes:
		if child!=group: child.reparent(group)
	group.scale=Vector3.ONE*factor; group.position=-center*factor
	depth_range=Vector2((source_bounds.position.z-center.z)*factor,(source_bounds.end.z-center.z)*factor)
	var observed_texture: Texture2D
	var observed_path := str(entry.get("image", ""))
	if not observed_path.is_empty() and ResourceLoader.exists(observed_path): observed_texture=load(observed_path)
	for mesh in components:
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(i)
			sample_count+=arrays[Mesh.ARRAY_VERTEX].size()
			var original=mesh.mesh.surface_get_material(i)
			var color := Color("bbcddc")
			var mesh_id := mesh.name.to_lower()
			if entry.id=="crab": color=Color("d98262") if "jet" in mesh_id else Color("e7b65d")
			elif entry.id=="cygnus_loop": color=Color("84a8c7")
			elif entry.id=="casa":
				if "fek" in mesh_id: color=Color("e18a55")
				elif "ar" in mesh_id: color=Color("d6a4bd")
				elif "si" in mesh_id: color=Color("b6d3dc")
				elif "jet" in mesh_id: color=Color("d6b45e")
				else: color=Color("92b5c2")
			if original is BaseMaterial3D: color=original.albedo_color
			var material := ShaderMaterial.new(); material.shader=GAS
			material.set_shader_parameter("layer_color",color)
			material.set_shader_parameter("use_observed_image",observed_texture!=null)
			if observed_texture!=null: material.set_shader_parameter("observed_image",observed_texture)
			mesh.set_surface_override_material(i,material)

func _build_image_depth(entry: Dictionary, texture: Texture2D) -> void:
	if texture == null: return
	var source_size := texture.get_size()
	var aspect := source_size.y / maxf(source_size.x, 1.0)
	var width := 30.0
	var height := width * aspect
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name="ObservedImageSurface"
	var quad := QuadMesh.new(); quad.size=Vector2(width,height)
	mesh_instance.mesh=quad
	var material := StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.albedo_texture=texture
	mesh_instance.material_override=material
	add_child(mesh_instance); components.append(mesh_instance)
	source_bounds=mesh_instance.get_aabb()
	depth_range=Vector2.ZERO
	sample_count=quad.get_faces().size()

func _collect_meshes(node: Node) -> void:
	if node is MeshInstance3D: components.append(node)
	for child in node.get_children(): _collect_meshes(child)
