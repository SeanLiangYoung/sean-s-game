extends RefCounted
const Story=preload("res://game/village_story.gd")
static func glow(art,parent,pos,size,color):
 var n=art.box(parent,pos,size,color)
 var m=StandardMaterial3D.new();m.albedo_color=color;m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 m.emission_enabled=true;m.emission=color;m.emission_energy_multiplier=0.7;n.material_override=m
 return n
static func roof(art,parent):
 var vertices=PackedVector3Array([Vector3(-1.9,2.25,-1.8),Vector3(1.9,2.25,-1.8),Vector3(0,3.45,-1.8),Vector3(-1.9,2.25,1.8),Vector3(1.9,2.25,1.8),Vector3(0,3.45,1.8)])
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for tri in [[0,2,1],[3,4,5],[0,3,5],[0,5,2],[2,5,4],[2,4,1],[0,1,4],[0,4,3]]:
  for i in tri:st.add_vertex(vertices[i])
 st.generate_normals()
 var surface=art.mesh(parent,st.commit(),Vector3.ZERO,Color("514d50"))
 var m=StandardMaterial3D.new();m.albedo_color=Color("595c60");m.roughness=1.0;m.cull_mode=BaseMaterial3D.CULL_DISABLED
 surface.material_override=m
 for side in [-1,1]:
  for z in range(7):
   art.rod(parent,Vector3(0,3.48,-1.65+z*0.55),Vector3(side*1.92,2.27,-1.65+z*0.55),0.018,Color("727477"))
 for z in [-1.83,1.83]:
  art.rod(parent,Vector3(-1.95,2.27,z),Vector3(0,3.5,z),0.07,Color("b4a58e"))
  art.rod(parent,Vector3(0,3.5,z),Vector3(1.95,2.27,z),0.07,Color("b4a58e"))
static func home(host,parent,id):
 var d=Story.HOMES[id];var a=host.art
 var root=Node3D.new();root.name="Home_"+id;root.position=d.pos;root.rotation_degrees.y=d.angle;parent.add_child(root)
 var c=Color(d.color)
 a.box(root,Vector3(0,0.15,0),Vector3(3.5,0.3,3.1),Color("77736b"))
 a.box(root,Vector3(0,1.3,0),Vector3(3.3,2.25,3),c)
 for y in range(12):
  var shade=c.darkened(0.10 if y%3==0 else 0.025)
  a.box(root,Vector3(0,0.3+y*0.175,1.51),Vector3(3.28,0.025,0.025),shade)
  a.box(root,Vector3(-1.66,0.3+y*0.175,0),Vector3(0.025,0.025,3),shade)
 for x in [-1.68,1.68]:a.box(root,Vector3(x,1.26,1.55),Vector3(0.13,2.2,0.12),Color("d4c6a6"))
 roof(a,root)
 a.box(root,Vector3(0.7,3.15,-0.65),Vector3(0.43,1.3,0.5),Color("8a796d"))
 a.box(root,Vector3(0.7,3.84,-0.65),Vector3(0.58,0.12,0.65),Color("4e5050"))
 var unit=host.campaign.roster.filter(func(u):return u.id==d.resident)
 var absent=id=="memory" or (not unit.is_empty() and unit[0].hp<=0)
 for x in [-0.95,0.95]:
  a.box(root,Vector3(x,1.36,1.55),Vector3(0.79,0.93,0.13),Color("dfcdb0"))
  glow(a,root,Vector3(x,1.36,1.63),Vector3(0.62,0.74,0.02),Color("f0c986") if not absent else Color("6d7e82"))
  a.box(root,Vector3(x,1.36,1.66),Vector3(0.055,0.75,0.04),Color("b5a58e"))
  a.box(root,Vector3(x,1.36,1.66),Vector3(0.64,0.045,0.04),Color("b5a58e"))
  a.box(root,Vector3(x,0.87,1.65),Vector3(0.95,0.09,0.28),Color("c4b493"))
 a.box(root,Vector3(0,0.85,1.55),Vector3(0.65,1.5,0.11),Color("426b7e") if id=="memory" else c.darkened(0.3))
 a.ball(root,Vector3(0.21,0.88,1.64),Vector3(0.07,0.07,0.07),Color("cdb877"))
 for i in range(2):a.box(root,Vector3(0,0.08+i*0.09,1.8-i*0.12),Vector3(1.0,0.15,0.65),Color("9b927e"))
 # Weathering and visibly reused boards, deliberately bounded and deterministic.
 for i in range(5):
  a.box(root,Vector3(-1.5+i*0.65,0.49+(i%3)*0.41,1.535),Vector3(0.23+i*0.03,0.07,0.02),c.lerp(Color("8b8170"),0.55))
 a.box(root,Vector3(-1.13,0.21,2.0),Vector3(0.55,0.32,0.43),Color("786e56"))
 if id in host.campaign.story_state.repaired:
  var repair=Node3D.new();repair.name="Repair";root.add_child(repair)
  for i in range(3):a.box(repair,Vector3(1.69,0.9+i*0.17,0.6),Vector3(0.04,0.13,1.1),Color("cfad73"))
  a.box(repair,Vector3(0.0,2.19,1.59),Vector3(3.3,0.12,0.1),c.lightened(0.25))
 if not absent:
  var smoke=CPUParticles3D.new();smoke.name="ChimneySmoke";root.add_child(smoke);smoke.position=Vector3(0.7,4,-0.65)
  smoke.amount=9;smoke.lifetime=4;smoke.preprocess=3;smoke.direction=Vector3(-0.4,1,0);smoke.spread=10;smoke.gravity=Vector3(-0.025,0.03,0)
  smoke.initial_velocity_min=0.25;smoke.initial_velocity_max=0.4;smoke.scale_amount_min=0.2;smoke.scale_amount_max=0.55
  var puff=SphereMesh.new();puff.radius=0.45;puff.height=0.6;puff.radial_segments=8;puff.rings=4
  var mist=StandardMaterial3D.new();mist.albedo_color=Color(0.74,0.78,0.77,0.14);mist.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mist.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  puff.material=mist;smoke.mesh=puff;smoke.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 if id=="engineer":
  a.box(root,Vector3(2.1,0.65,0.7),Vector3(1.3,0.13,0.65),Color("9c8563"))
  for x in [1.65,2.55]:a.box(root,Vector3(x,0.32,0.7),Vector3(0.1,0.64,0.5),Color("6e6555"))
  for i in range(3):a.box(root,Vector3(2.0,0.79+i*0.12,0.7),Vector3(1.5,0.09,0.17),Color("b39d75"))
 if id=="medic":
  for i in range(3):
   a.cone(root,Vector3(-2,0.22,-0.6+i*0.6),0.23,0.29,0.44,Color("a98363"),8)
   for j in range(3):a.rod(root,Vector3(-2,0.4,-0.6+i*0.6),Vector3(-2.15+j*0.15,0.8,-0.6+i*0.6),0.035,Color("6e885d"))
 if id=="lodger":
  a.box(root,Vector3(-0.3,0.35,2.2),Vector3(0.65,0.4,0.35),Color("8b7050"))
  a.box(root,Vector3(-0.3,0.57,2.2),Vector3(0.3,0.04,0.04),Color("c7ae75"))
 if id=="memory":
  a.box(root,Vector3(-1.0,0.55,2.0),Vector3(0.05,0.9,0.7),Color("8d816b"))
  a.box(root,Vector3(-1.0,0.55,2.0),Vector3(0.65,0.1,0.75),Color("8d816b"))
 return root
static func build(host):
 host.apply_region_style("border")
 host.clear_scene()
 var a=host.art;var village=Node3D.new();village.name="Village";host.scene_root.add_child(village)
 a.box(village,Vector3(0,-0.5,-5),Vector3(180,0.8,120),Color("666e68"))
 # A cold inlet behind the houses and flattened, wind-worn tundra.
 var sea=a.box(village,Vector3(-2,-0.07,-30),Vector3(170,0.02,60),Color("526d78"))
 var water=ShaderMaterial.new();water.shader=preload("res://game/shaders/village_water.gdshader");water.set_shader_parameter("water_color",Color("506c75"));sea.material_override=water
 var rng=RandomNumberGenerator.new();rng.seed=382713
 var ground=SurfaceTool.new();ground.begin(Mesh.PRIMITIVE_TRIANGLES);ground.set_normal(Vector3.UP)
 var beach=SurfaceTool.new();beach.begin(Mesh.PRIMITIVE_TRIANGLES);beach.set_normal(Vector3.UP)
 for i in range(64):
  var x=-85+i*2.7;var next=x+2.7
  var edge=-18.3+sin(x*0.15)*1.8+sin(x*0.41)*0.4
  var next_edge=-18.3+sin(next*0.15)*1.8+sin(next*0.41)*0.4
  for p in [Vector3(x,0,edge),Vector3(next,0,next_edge),Vector3(x,0,55),Vector3(next,0,next_edge),Vector3(next,0,55),Vector3(x,0,55)]:ground.add_vertex(p)
  for p in [Vector3(x,0.01,edge),Vector3(next,0.01,next_edge),Vector3(x,0.01,edge+0.75),Vector3(next,0.01,next_edge),Vector3(next,0.01,next_edge+0.75),Vector3(x,0.01,edge+0.75)]:beach.add_vertex(p)
  if i%2==0:a.ball(village,Vector3(x,0.1,edge+0.8),Vector3(0.7,0.3,0.6),Color("626c67"))
 for pair in [[ground,Color("666e68")],[beach,Color("818574")]]:
  var n=a.mesh(village,pair[0].commit(),Vector3.ZERO,pair[1])
  var terrain_material=a.paint(pair[1],0.28).duplicate();terrain_material.shader=preload("res://game/shaders/village_ground.gdshader");n.material_override=terrain_material
 for i in range(105):
  var p=Vector3(rng.randf_range(-55,55),0,rng.randf_range(-16,26))
  if absf(p.x)<12 and absf(p.z)<12:continue
  var size=rng.randf_range(0.4,2.2)
  a.ball(village,p,Vector3(size,0.28*size,size*0.65),Color("666e69"))
 for i in range(32):
  var hill=a.ball(village,Vector3(-65+i*4.5,-0.1,-43-rng.randf_range(0,9)),Vector3(rng.randf_range(7,14),rng.randf_range(2,7),8),Color("747e7b"))
  hill.rotation_degrees.y=rng.randf_range(0,180)
 for z in range(-15,20):
  a.box(village,Vector3(sin(z*0.17)*1.1,-0.04,z),Vector3(2.2,0.08,1.12),Color("8c8879"))
 for id in Story.HOMES:
  home(host,village,id)
  var p=Story.HOMES[id].pos+Vector3(0,0,2.3)
  for i in range(1,8):
   var step=p.lerp(Vector3(0,0,p.z),i/7.0)
   a.ball(village,step,Vector3(0.65,0.07,0.48),Color("b0a48a"))
 # Dry bent grass makes the boundary between habitation and waste tangible.
 for i in range(260):
  var p=Vector3(rng.randf_range(-22,22),0,rng.randf_range(-15,19))
  if absf(p.x)<10 and absf(p.z)<11:continue
  for j in range(2):
   a.rod(village,p+Vector3(j*0.06,0,0),p+Vector3(0.15+j*0.04,rng.randf_range(0.18,0.4),-0.08),0.012,Color("8d8b69"))
 # Bare fencing, a shared well, and small signs of ordinary work.
 for x in range(-11,12):
  if absi(x)<2:continue
  a.box(village,Vector3(x,0.45,11.5),Vector3(0.09,0.9,0.09),Color("8d8067"))
  a.rod(village,Vector3(x,0.6,11.5),Vector3(x+0.9,0.53,11.5),0.045,Color("9e9077"))
 a.cone(village,Vector3(3,0.35,1),0.65,0.7,0.7,Color("8a8b7a"),10)
 a.cone(village,Vector3(3,0.72,1),0.48,0.48,0.04,Color("344d53"),10)
 for x in [2.3,3.7]:a.box(village,Vector3(x,1.1,1),Vector3(0.12,2.2,0.12),Color("8e7b5d"))
 a.rod(village,Vector3(2.25,2.1,1),Vector3(3.75,2.1,1),0.10,Color("8e7b5d"))
 a.rod(village,Vector3(3,2.1,1),Vector3(3,0.8,1),0.025,Color("564c3c"))
 for i in range(4):
  a.rod(village,Vector3(8.9+i*0.16,0.18,1.2),Vector3(9.5+i*0.16,0.2,3.4),0.065,Color("c5ab7c"))
 for x in [-7,-2]:a.box(village,Vector3(x,1.0,-3.0),Vector3(0.09,2,0.09),Color("84775e"))
 a.rod(village,Vector3(-7,1.88,-3),Vector3(-2,1.88,-3),0.015,Color("d4cbb1"))
 for i in range(4):a.cloth(village,Vector3(-6.4+i,1.48,-3),0.6,0.7,Color("c3b6a1") if i%2 else Color("8e9d95"))
 # Faraway suspended land: no explanation, no glowing villain silhouette.
 var rock=Node3D.new();rock.name="SuspendedRock";rock.position=Vector3(-12,6,-21);rock.scale=Vector3.ONE*0.65;village.add_child(rock)
 a.cone(rock,Vector3.ZERO,1.1,5.3,5.2,Color("535f61"),7)
 a.ball(rock,Vector3(0,2.5,0),Vector3(11,1.1,7),Color("74796a"))
 for i in range(6):
  var shard=a.ball(rock,Vector3(-3.0+i*1.1,1.0-absf(i-2.5)*0.1,1.1-sin(i)*0.5),Vector3(1.5,2.0+i%2,1.7),Color("606b6a"))
  shard.rotation_degrees.z=-22+i*8
 for i in range(5):a.box(rock,Vector3(-2+i,3.0,-0.3),Vector3(0.7,0.8+i%2*0.4,0.8),Color("81867b"))
 # The player remains a real dressed pawn, so camp equipment changes stay visible.
 host.world_party=a.character(village,Vector3(-3,0,4),Color("c58c45"),"hero",false,host.campaign.visual_profile("hero"))
 host.pawn_nodes.append(host.world_party)
 host.world_target=host.world_party.position
 # Residents are few; their homes are much more numerous than the people outdoors.
 for id in ["engineer","medic","ranger"]:
  var d=Story.HOMES[id];var u=host.campaign.roster.filter(func(unit):return unit.id==d.resident and unit.hp>0)
  if u.is_empty():continue
  var pawn=a.character(village,d.pos+Vector3(-2,0,2),Color(d.color),id,false,host.campaign.visual_profile(id))
  pawn.scale=Vector3.ONE*0.8
 var env=host.get_node("WorldEnvironment").environment
 env.background_color=Color("aab8b6");env.ambient_light_color=Color("a9bbc6");env.ambient_light_energy=0.48
 env.fog_light_color=Color("aab8b6");env.fog_density=0.0025
 var sun=host.get_node("RegionSun");sun.light_color=Color("ffe0bc");sun.light_energy=0.65;sun.rotation_degrees=Vector3(-31,-32,0)
 host.camera_angle=0;host.camera_zoom=32
 host.camera.position=Vector3(21,18,36);host.camera.size=28;host.camera.look_at(Vector3(1,2,-3))
