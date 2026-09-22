extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var folder := "res://extensions/observatory/assets/nebulae/"
	var assets={
		"crab_observed":["crab.glb.obj","Crab_Nebula_disc.obj","Crab_Nebula_jet_1.obj","Crab_Nebula_jet_2.obj"],
		"cygnus_observed":["cygnus_loop.glb.obj"],"casa_observed":["cco.obj","fekcorr.obj","newar.obj","newhetg.obj","newjets.obj","newopt.obj","newsi.obj"]
	}
	for output in assets:
		var root:=Node3D.new()
		for file in assets[output]:
			var source:=FileAccess.open(folder+file,FileAccess.READ)
			if source==null: continue
			var vertices:=PackedVector3Array(); var indices:=PackedInt32Array()
			while not source.eof_reached():
				var line:=source.get_line().strip_edges(); var fields:=line.split(" ",false)
				if fields.is_empty(): continue
				if fields[0]=="v": vertices.append(Vector3(float(fields[1]),float(fields[2]),float(fields[3])))
				elif fields[0]=="f":
					for j in 3: indices.append(int(fields[j].split("/")[0])-1)
			if vertices.is_empty(): continue
			var arrays=[]; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_INDEX]=indices
			var mesh:=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var node:=MeshInstance3D.new(); node.mesh=mesh; node.name=file; root.add_child(node); node.owner=root
		var scene:=PackedScene.new()
		var pack_error:=scene.pack(root)
		var save_error:=ResourceSaver.save(scene,folder+output+".tscn")
		print(output," nodes=",root.get_child_count()," pack=",pack_error," save=",save_error)
	print("IMPORTED OBSERVED ",assets.keys()); quit()
