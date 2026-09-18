import bpy,pathlib,math
P=pathlib.Path(__file__).resolve().parents[2]
source=P/'model_sources/Solmere_memory_rooms.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
def box(c,name,p,s,mat):
 bpy.ops.mesh.primitive_cube_add(size=1,location=(p[0],-p[2],p[1]));o=bpy.context.object;o.name=name;o.scale=(s[0],s[2],s[1])
 for old in list(o.users_collection):old.objects.unlink(o)
 c.objects.link(o);o.data.materials.append(bpy.data.materials[mat]);return o
for c in list(bpy.data.collections):
 if len(c.name)!=2 or c.name[0] not in 'AB':continue
 c.hide_viewport=False;c.hide_render=False
 for o in c.objects:
  if o.name.startswith('Memory_paper_support'):o.location=(0,3.365,2.0)
  if o.name.startswith('Clock_back'):o.location.x+=3.6
  if o.name.startswith('Label_03:14') or o.name.startswith('Label_23:58'):o.location.x+=3.6
 box(c,'Ceiling',(0,3.2,0),(7,.15,7),'Lime plaster')
 if c.name in ['B3','B0']:
  for i in range(12):box(c,'Radiator_fin',(2.3+i*.055,.55,-3.25),(.045,.75,.15),'Cream paper')
  box(c,'Radiator_pipe',(2.6,.18,-3.25),(.8,.045,.045),'Ink metal')
 if c.name in ['A6','B3','B5','B0']:
  curve=bpy.data.curves.new('Loose_audio_cable','CURVE');curve.dimensions='3D';curve.bevel_depth=.012;curve.bevel_resolution=1
  spline=curve.splines.new('POLY');spline.points.add(24)
  for i,p in enumerate(spline.points):
   a=i/24*math.pi*1.8;p.co=(.8+math.cos(a)*.42,1.95+math.sin(a)*.24,.09,1)
  obj=bpy.data.objects.new('Coiled_cable',curve);c.objects.link(obj);curve.materials.append(bpy.data.materials['Ink metal'])
 bpy.ops.object.select_all(action='DESELECT')
 for o in c.objects:o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(P/'art/memories'/f'{c.name}.glb'),use_selection=True,export_format='GLB',export_yup=True,export_cameras=False,export_lights=False)
for c in bpy.data.collections:
 if c.name not in ['A6','Collection']:c.hide_viewport=True;c.hide_render=True
bpy.ops.wm.save_as_mainfile(filepath=str(source))
print('REFINEMENT_COMPLETE')
