"""Blender 5.1: authored modular furniture, 14 distinct story arrangements + 2 present rooms.
Coordinates exposed below use Godot metres (X right, Y up, Z toward camera).
"""
import bpy, math, pathlib, json, sys
from mathutils import Vector
P=pathlib.Path(__file__).resolve().parents[2]
OUT=P/'art/memories';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def material(name,color,emission=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 bs=next((n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
 if bs is None:
  bs=m.node_tree.nodes.new('ShaderNodeBsdfPrincipled');out=m.node_tree.nodes.new('ShaderNodeOutputMaterial');m.node_tree.links.new(bs.outputs['BSDF'],out.inputs['Surface'])
 bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=.83
 if emission:bs.inputs['Emission Color'].default_value=(*color,1);bs.inputs['Emission Strength'].default_value=emission
 return m
M={k:material(k,c,e) for k,c,e in [('Lime plaster',(.66,.59,.46),0),('Sage paint',(.22,.34,.32),0),('Warm oak',(.32,.19,.105),0),('Oak light',(.51,.32,.18),0),('Ink metal',(.045,.075,.084),0),('Cream paper',(.86,.8,.64),0),('Clay',(.48,.235,.135),0),('Linen',(.50,.47,.36),0),('Olive',(.20,.28,.13),0),('Blue',(.19,.34,.45),0),('Rose',(.57,.31,.33),0),('Glass blue',(.12,.23,.34),.4),('Screen',(.045,.12,.16),.45),('Lamp',(.95,.62,.26),2),('Lilac blue',(.47,.60,.76),0)]}
active=None
def reg(o,name,mat):
 o.name=name
 for c in list(o.users_collection): c.objects.unlink(o)
 active.objects.link(o)
 if mat:o.data.materials.append(M[mat])
 return o
def pos(p):return (p[0],-p[2],p[1])
def box(name,p,s,mat,bevel=.025):
 bpy.ops.mesh.primitive_cube_add(size=1,location=pos(p));o=reg(bpy.context.object,name,mat);o.scale=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  b=o.modifiers.new('Soft handmade edges','BEVEL');b.width=bevel;b.segments=1
  bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=b.name)
 return o
def cyl(name,p,r,h,mat,vertices=12):
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=h,location=pos(p));return reg(bpy.context.object,name,mat)
def ball(name,p,s,mat):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=pos(p));o=reg(bpy.context.object,name,mat);o.scale=(s[0],s[2],s[1]);return o
def label(text,p,size=.09,mat='Cream paper'):
 bpy.ops.object.text_add(location=pos(p),rotation=(math.pi/2,0,0));o=reg(bpy.context.object,'Label_'+text,mat);o.data.body=text;o.data.size=size;o.data.extrude=.0004
 bpy.ops.object.convert(target='MESH');return o
def table(x,z,w=1.6,d=.8,y=.78):
 box('Table_oak_top',(x,y,z),(w,.085,d),'Oak light')
 for dx in [-w/2+.1,w/2-.1]:
  for dz in [-d/2+.1,d/2-.1]:box('Table_leg',(x+dx,y/2,z+dz),(.07,y,.07),'Warm oak')
def chair(x,z):
 box('Chair_seat',(x,.46,z),(.48,.065,.46),'Sage paint')
 for dx in [-.19,.19]:
  for dz in [-.18,.18]:box('Chair_leg',(x+dx,.23,z+dz),(.055,.46,.055),'Warm oak')
 for dx in [-.19,.19]:box('Chair_back_post',(x+dx,.75,z+.2),(.055,.63,.055),'Warm oak')
 for dx in [-.12,0,.12]:box('Chair_back_slat',(x+dx,.88,z+.2),(.055,.32,.04),'Sage paint')
def mug(x,y,z):
 cyl('Cup_body',(x,y+.055,z),.065,.11,'Cream paper')
 cyl('Coffee_surface',(x,y+.114,z),.05,.004,'Warm oak')
 bpy.ops.mesh.primitive_torus_add(major_radius=.04,minor_radius=.012,major_segments=12,minor_segments=6,location=pos((x+.07,y+.07,z)),rotation=(math.pi/2,0,0));reg(bpy.context.object,'Cup_handle','Cream paper')
def plant(x,y,z,r=.2):
 cyl('Terracotta_pot',(x,y+r*.6,z),r*.65,r*1.2,'Clay')
 for i in range(7):
  a=i*2.399;ball('Olive_leaf',(x+math.cos(a)*r*.75,y+r*2+(.1 if i%2 else 0),z+math.sin(a)*r*.75),(r*.55,r*.18,r*.27),'Olive')
 cyl('Stem',(x,y+r*1.4,z),.015,r*1.8,'Warm oak')
def books(x,y,z,count=5):
 for i in range(count):box('Stacked_book',(x,y+.026+i*.047,z),(.32-i%2*.025,.043,.22),['Cream paper','Sage paint','Clay'][i%3],.003)
def screen(x,y,z,w=.9,kind='DAW'):
 box('Monitor_stand',(x,y+.12,z),(.06,.24,.06),'Ink metal')
 box('Monitor_foot',(x,y+.016,z+.02),(.28,.03,.19),'Ink metal')
 box('Monitor_frame',(x,y+.43,z),(w,.52,.06),'Ink metal')
 box('Monitor_glass',(x,y+.43,z+.036),(w-.045,.475,.008),'Screen',.003)
 if kind=='DAW':
  for i in range(5):
   for j in range(3):box('Arrangement_clip',(x-w*.39+j*w*.25,y+.58-i*.078,z+.044),(w*.22,.043,.003),['Sage paint','Blue','Clay','Linen','Rose'][i],.002)
 else:
  for i in range(2):box('Version_view',(x+(-1 if i==0 else 1)*w*.22,y+.45,z+.044),(w*.38,.3,.003),['Sage paint','Blue'][i],.001)
 label(kind,(x-w*.44,y+.64,z+.047),.035)
 box('Computer_keyboard',(x,y+.023,z+.35),(.49,.036,.15),'Ink metal')
 for row in range(3):
  for col in range(12):box('Keycap',(x-.22+col*.04,y+.049,z+.30+row*.04),(.032,.013,.027),'Linen',.002)
 box('Mouse',(x+.36,y+.035,z+.35),(.055,.055,.09),'Ink metal')
def bed(x,z):
 box('Bed_frame',(x,.23,z),(1.4,.35,1.94),'Warm oak');box('Mattress',(x,.48,z),(1.36,.2,1.91),'Cream paper',.07)
 box('Duvet',(x,.62,z+.26),(1.4,.13,1.4),'Linen',.06);box('Pillow',(x,.63,z-.65),(.85,.16,.42),'Cream paper',.06)
def sofa(x,z):
 box('Sofa_base',(x,.27,z),(1.9,.34,.8),'Linen',.08)
 box('Sofa_back',(x,.65,z-.36),(1.9,.69,.14),'Sage paint',.06)
 for dx in [-.53,0,.53]:box('Sofa_cushion',(x+dx,.49,z),(.53,.17,.64),'Linen',.06)
def kitchen():
 box('Kitchen_cabinet',(-1.5,.46,-2.25),(2.3,.88,.68),'Sage paint');box('Counter',(-1.5,.94,-2.25),(2.36,.08,.75),'Cream paper')
 for x in [-2.3,-1.5,-.7]:
  box('Cabinet_front',(x,.48,-1.898),(.73,.76,.035),'Sage paint')
  cyl('Cabinet_knob',(x+.18,.76,-1.86),.025,.03,'Clay')
 box('Sink',(-2,.989,-2.25),(.58,.016,.42),'Ink metal');cyl('Tap',(-2,1.14,-2.48),.025,.32,'Ink metal')
 box('Hob',(-.85,.991,-2.25),(.7,.018,.45),'Ink metal')
 for x in [-1.04,-.65]:cyl('Burner',(x,1.01,-2.25),.135,.015,'Warm oak')
 cyl('Pot',(-1.04,1.095,-2.25),.14,.17,'Sage paint');cyl('Pot_lid',(-1.04,1.19,-2.25),.15,.028,'Ink metal')
 box('Range_hood',(-.85,1.8,-2.38),(1,.17,.6),'Ink metal')
 box('Fridge',(2.5,1,-2.2),(.8,2,.8),'Cream paper',.07)
 box('Fridge_handle',(2.19,1.2,-1.76),(.04,.33,.04),'Ink metal')
def studio(role):
 for x in [-1.75,0,1.75]:
  table(x,-2.35,1.55,.8);screen(x,.83,-2.47,.94,'L / R' if role=='A' else 'EXPORT COMPLETE');chair(x,-1.3);mug(x+.5,.83,-2.05)
  for i in range(2):box('Takeaway_box',(x-.45,.86+i*.065,-2.05),(.22,.06,.18),'Cream paper')
  box('Computer_tower',(x+.57,.31,-2.37),(.24,.55,.4),'Ink metal')
 box('Clock_back',(-2,2.42,-3.39),(.75,.26,.05),'Ink metal');label('03:14' if role=='A' else '23:58',(-2.3,2.35,-3.348),.17,'Lamp')
def bedroom(role):
 bed(-2.1,-1.4);table(.8,-2.25,2.3,.85);chair(.9,-1.27);screen(.8,.83,-2.38,1.12);mug(1.65,.83,-1.99)
 books(0,.83,-2.23,4)
 if role=='B':
  # Dedicated MIDI keys, interface, two speakers, headphones, recorder and guitar.
  for x in [-.16,1.77]:
   box('Speaker',(x,1.04,-2.44),(.23,.42,.23),'Ink metal');ball('Speaker_cone',(x,1.01,-2.31),(.079,.079,.024),'Blue')
  box('MIDI_body',(.8,.87,-1.94),(.68,.07,.2),'Ink metal')
  for i in range(14):box('MIDI_key',(.5+i*.044,.92,-1.9),(.04,.02,.15),'Cream paper')
  box('Audio_interface',(1.38,.89,-2.25),(.18,.11,.15),'Clay')
  for i in range(2):ball('Headphone_cup',(-.16+i*.18,.9,-1.98),(.08,.06,.09),'Ink metal')
  cyl('Keys_ring',(1.72,.847,-1.78),.035,.008,'Ink metal')
  box('Recorder',(.0,.87,-1.87),(.07,.08,.15),'Ink metal')
  ball('Guitar_body',(2.6,.7,-1.9),(.32,.44,.09),'Oak light');box('Guitar_neck',(2.6,1.35,-1.9),(.065,.7,.04),'Warm oak')
def shell(roomid):
 box('Floor_collision',(0,-.08,0),(7,.16,7),'Warm oak')
 for i in range(18):box('Floorboard',(0,.015,-3.3+i*.38),(6.95,.025,.365),'Oak light',.004)
 for name,p,s in [('Back_wall',(0,1.55,-3.5),(7,3.1,.16)),('Left_wall',(-3.5,1.55,0),(.16,3.1,7)),('Right_wall',(3.5,1.55,0),(.16,3.1,7)),('Front_wall',(0,1.55,3.5),(7,3.1,.16))]:box(name,p,s,'Lime plaster',.01)
 for x in [-3.2,0,3.2]:box('Ceiling_beam',(x,3.07,0),(.15,.16,7),'Warm oak')
 box('Rug',(0,.04,.2),(2.5,.024,2),'Linen',.003)
 for x in [-1.2,1.2]:box('Rug_border',(x,.054,.2),(.035,.003,1.9),'Sage paint',0)
 box('Window_recess',(-2,1.98,-3.397),(1.7,1.5,.04),'Warm oak');box('Night_window',(-2,1.98,-3.37),(1.55,1.35,.02),'Glass blue')
 box('Window_mullion',(-2,1.98,-3.34),(.05,1.4,.025),'Sage paint');box('Window_sill',(-2,1.29,-3.26),(1.85,.08,.3),'Cream paper')
 for x in [-2.9,-1.12]:box('Curtain',(x,2,-3.24),(.22,1.6,.12),'Linen')
 box('Wall_shelf',(1.5,2.15,-3.27),(2.4,.06,.4),'Warm oak');books(.95,2.2,-3.24);plant(2.3,2.2,-3.2,.15)
 box('Door_frame',(0,1.15,3.39),(1.02,2.3,.05),'Warm oak');box('Door',(0,1.12,3.35),(.86,2.2,.04),'Sage paint')
 # A lamp's visible geometry is paired with runtime local light for stable glTF import.
 cyl('Pendant_cord',(0,2.75,0),.008,.6,'Ink metal');cyl('Pendant_shade',(0,2.44,0),.23,.17,'Sage paint');ball('Pendant_bulb',(0,2.37,0),(.09,.06,.09),'Lamp')
 plant(2.85,0,1.8,.3)
def build(r):
 global active
 rid=r['id'];active=bpy.data.collections.new(rid);bpy.context.scene.collection.children.link(active);shell(rid)
 role=rid[0];n=int(rid[1:]) if rid[1:].isdigit() else 0
 if n in [1,3,5,7] and role=='A' and n!=3:bed(-2.1,-1.5)
 if rid in ['A6','B5']:studio(role)
 elif rid in ['A3','B4']:kitchen();table(.1,.1,1.55,.9);chair(.1,1)
 elif rid=='A4':
  for x in [-1.6,0,1.6]:chair(x,-1.1)
  box('Bus_stop',(0,1.65,-2.4),(2.8,.8,.06),'Blue');label('27 / SUMMER',(-1.05,1.5,-2.36),.22)
  for i in range(3):box('Seaside_step',(2.4,.12+i*.13,-1.5-i*.35),(1.7,.24+i*.26,.8),'Linen')
  box('Store_freezer',(-2.4,.58,-2.4),(1.2,1.15,.8),'Cream paper')
 elif rid in ['B3','B7','B0']:bedroom('B')
 elif rid in ['A2','B2']:
  sofa(-1,-2.45);table(.1,-.8,1.5,.65,.43)
  for i in range(5):box('Paperwork',(-.5+i*.24,.49,-.8+i%2*.1),(.3,.006,.38),'Cream paper',.001)
  if role=='A':box('Broken_speaker',(1.8,.21,-2),(.42,.42,.28),'Ink metal');cyl('Screw_dish',(1.25,.05,-1.8),.14,.025,'Cream paper')
 elif rid in ['B1','B6']:
  table(0,-1.1,2,1);chair(-.6,-.1);chair(.6,-.1)
  for x in [-.65,0,.65]:cyl('Dinner_plate',(x,.846,-1.1),.19,.03,'Cream paper');mug(x,.83,-1.43)
 else:table(.65,-2.1,2.3,.85);chair(.7,-1.1);books(1.4,.83,-2.2)
 if rid=='A1':box('Phone_alarm',(-2.95,.64,-1.65),(.13,.035,.23),'Ink metal');label('08:47',(-.1,1.8,-3.36),.15)
 if rid=='A5':
  screen(.65,.83,-2.35,1.1,'CALENDAR')
  for i,t in enumerate(['09:00 WORK','11:00 READ','14:00 PROJECT','17:00 GYM','20:00 FILM']):label(t,(-.7,2.55-i*.18,-3.36),.12)
 if rid=='A7':box('Blank_whiteboard',(.8,1.91,-3.36),(2,1.12,.04),'Cream paper');box('Eraser',(.9,1.33,-3.28),(.16,.07,.05),'Sage paint')
 if rid=='B7':
  box('Open_suitcase',(0,.14,.4),(1,.25,.7),'Ink metal');box('Suitcase_lid',(0,.53,.05),(1,.6,.055),'Sage paint')
  for i in range(3):box('Folded_clothes',(-.15,.3+i*.04,.4),(.53,.045,.46),'Linen')
 if rid=='B4':box('Grocery_bag',(.32,1.01,.1),(.33,.38,.24),'Linen')
 if rid=='A0':
  bed(-2,-1.4)
  # Round baby dragon light with rounded head, short wings and no long serpentine body.
  ball('Baby_dragon_body',(1.55,1.00,-2.12),(.15,.19,.12),'Rose');ball('Baby_dragon_head',(1.55,1.2,-2.12),(.16,.14,.14),'Rose')
  for x in [1.36,1.74]:ball('Small_round_wing',(x,1.05,-2.12),(.09,.11,.04),'Rose')
  for x in [1.49,1.61]:ball('Dragon_eye',(x,1.24,-1.99),(.016,.02,.012),'Ink metal')
  for x in [-.2,0,.2]:box('Translucent_sample_frame',(x,.84,-1.96),(.35,.008,.35),'Lilac blue')
  for x in [-2.9,-2.65]:ball('Quirky_shoe',(x,.13,.5),(.12,.12,.25),'Rose')
  box('Mirror_frame',(2.7,1.6,-3.35),(.6,1.2,.07),'Warm oak');box('Mirror',(2.7,1.6,-3.3),(.5,1.1,.01),'Glass blue')
 # Shared physical object anchoring the 2D-to-3D match cut, named for the controller.
 box('Memory_paper_support',(0,1.25,-2.575),(1.02,.73,.03),'Warm oak',.004)
 bpy.ops.object.select_all(action='DESELECT')
 for o in active.objects:o.select_set(True)
 bpy.context.view_layer.objects.active=next(iter(active.objects))
 bpy.ops.export_scene.gltf(filepath=str(OUT/f'{rid}.glb'),use_selection=True,export_format='GLB',export_yup=True,export_cameras=False,export_lights=False)
 print('EXPORTED',rid, len(active.objects))
for room in json.loads((P/'data/meta/memories.json').read_text(encoding='utf-8'))['rooms']+[{'id':'A0'},{'id':'B0'}]:build(room)
# Keep collections individually switchable in the source file; no scene overlap in preview.
for c in bpy.data.collections:
 if c.name not in ['A6','Collection']:c.hide_viewport=True;c.hide_render=True
bpy.ops.wm.save_as_mainfile(filepath=str(P/'model_sources/Solmere_memory_rooms.blend'))
print('BLENDER_COMPLETE')
