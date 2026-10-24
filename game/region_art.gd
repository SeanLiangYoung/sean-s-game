extends RefCounted
const Regions=preload("res://game/regions.gd")

static func build(art,parent: Node3D,safe_radius: int,biome: String,seed_value: int) -> Node3D:
 var region=Regions.definition(biome)
 var root=Node3D.new();root.name="BattleLandscape";root.set_meta("biome",biome);root.set_meta("theme",region.theme);parent.add_child(root)
 var ground=art.terrain(root)
 ground.material_override=art.paint(Color(region.ground),0.24).duplicate()
 ground.material_override.set_shader_parameter("safe_radius",float(safe_radius) if safe_radius<4 else -1.0)
 var landmark=Node3D.new();landmark.name="RegionLandmark";root.add_child(landmark)
 var random=RandomNumberGenerator.new();random.seed=seed_value+9417
 var accent=Color(region.accent)
 if biome in ["wood","marsh"]:
  art.grass(root,seed_value,2600 if biome=="wood" else 1600,Vector2(14,13),true)
  var grass=root.get_node("WindGrass").material_override
  grass.set_shader_parameter("root_color",Color("1e3a2b") if biome=="wood" else Color("344c40"))
  grass.set_shader_parameter("tip_color",Color("6f9e54") if biome=="wood" else Color("99af7c"))
 for i in range(28):
  var angle=TAU*i/28.0+random.randf_range(-0.05,0.05)
  var radius=random.randf_range(8.2,13.0)
  var pos=Vector3(cos(angle)*radius,0,sin(angle)*radius)
  pos.y=art.terrain_height(pos.x,pos.z)
  match biome:
   "wood":
    art.tree(landmark,pos,random.randf_range(1.2,1.9))
    if i%4==0:art.rock(landmark,pos+Vector3(0,0.2,0),Vector3(1.4,0.9,1.5),Color("647661"))
   "waste":
    art.ball(landmark,pos+Vector3(0,-0.15,0),Vector3(6.0,1.7,4.0),Color("bb935c"))
    if i%4==0:
     art.cone(landmark,pos+Vector3(0,0.8,0),0.6,0.35,1.8,Color("996b49"),5)
     art.rock(landmark,pos+Vector3(0,1.8,0),Vector3(1.1,0.5,0.9),Color("d1a66f"))
   "frost":
    if i%3==0:
     art.rock(landmark,pos,Vector3(2.5,2.8,2.0),Color("7d929e"))
     art.ball(landmark,pos+Vector3(0,1.4,0),Vector3(2.2,0.65,1.8),Color("deebed"))
    else:
     art.cone(landmark,pos+Vector3(0,0.8,0),0.15,0.08,1.6,Color("6d7775"),6)
     for layer in 3:
      var height=1.0+layer*0.65
      art.cone(landmark,pos+Vector3(0,height,0),1.0-layer*0.23,0,1.7,Color("c9dfe0") if layer%2==0 else Color("658282"),7)
   "marsh":
    var tree=Node3D.new();tree.position=pos;landmark.add_child(tree)
    art.rod(tree,Vector3.ZERO,Vector3(0.12,2.7,0),0.16,Color("58675a"))
    for side in [-1,1]:
     art.rod(tree,Vector3(0,1.2,0),Vector3(side*0.9,2.1,0.15),0.10,Color("58675a"))
     art.rod(tree,Vector3(side*0.9,2.1,0.15),Vector3(side*1.1,2.7,0.22),0.055,Color("58675a"))
     art.rod(tree,Vector3(0,0.2,0),Vector3(side*0.8,0.02,0.5),0.11,Color("58675a"))
    if i%2==0:pool(art,landmark,pos+Vector3(1,-0.03,0),Vector2(3.8,2.7))
   "ruins":
    if i%3==0:
     art.ruin(landmark,pos)
    else:
     art.cone(landmark,pos+Vector3(0,0.85,0),0.4,0.3,1.8,Color("697789"),6)
     art.cone(landmark,pos+Vector3(0,1.9,0),0.3,0,0.55,accent,6)
     art.ring(landmark,pos+Vector3(0,0.05,0),0.7,accent,0.035,6)
 # Each arena has a readable silhouette landmark outside the tactical board.
 match biome:
  "wood":
   for i in 7:
    var angle=TAU*i/7
    art.rock(landmark,Vector3(-2.0+cos(angle)*2.0,0.6,-8.5+sin(angle)*1.0),Vector3(0.7,1.7,0.5),Color("8c9b79"))
  "waste":
   for x in [-3.0,0.0,3.0]:
    var pos=Vector3(x,0,-8.5)
    art.cone(landmark,pos+Vector3(0,0.7,0),1.3,0,1.7,Color("985f44"),4)
    art.rod(landmark,pos+Vector3(1.1,0,0),pos+Vector3(1.1,2.2,0),0.035,Color("6a5140"))
    art.cloth(landmark,pos+Vector3(1.5,1.85,0),0.8,0.5,Color("d49d61"))
  "frost":
   for side in [-1,1]:
    var pos=Vector3(side*3.0,0,-8.5)
    art.box(landmark,pos+Vector3(0,1.1,0),Vector3(1.0,2.3,1.1),Color("8a9daa"))
    art.box(landmark,pos+Vector3(0,2.3,0),Vector3(1.25,0.25,1.3),Color("e1ebed"))
    art.ball(landmark,pos+Vector3(0,2.7,0),Vector3(0.3,0.5,0.3),Color("f0bf7e"))
  "marsh":
   for x in range(-4,5):art.box(landmark,Vector3(x*0.5,-0.01,-8.0),Vector3(0.43,0.15,2.0),Color("657064"))
   for side in [-1,1]:art.rod(landmark,Vector3(side*2.2,0,-8),Vector3(side*2.2,1.8,-8),0.08,Color("687661"))
  "ruins":
   for i in 6:
    var angle=TAU*i/6
    var pos=Vector3(cos(angle)*2.1,0,-9+sin(angle)*1.5)
    art.cone(landmark,pos+Vector3(0,0.4,0),0.4,0.25,1.1,Color("6d8198"),6)
    art.rod(landmark,pos+Vector3(0,0.95,0),Vector3(0,2,-9),0.025,accent)
   art.ball(landmark,Vector3(0,2,-9),Vector3(0.8,1.1,0.8),accent)
 return root

static func pool(art,parent: Node3D,pos: Vector3,size: Vector2):
 var plane=PlaneMesh.new();plane.size=size
 var water=art.mesh(parent,plane,pos,Color("3c645c"));water.name="StillMarshWater"
 var material=ShaderMaterial.new();material.shader=art.WATER;material.set_shader_parameter("water_color",Color("2d514b"));water.material_override=material

static func obstacle(art,parent: Node3D,pos: Vector3,biome: String):
 match biome:
  "wood":
   art.cone(parent,pos+Vector3(0,0.25,0),0.34,0.26,0.7,Color("6c6040"),8)
   art.ball(parent,pos+Vector3(0.12,0.48,0),Vector3(0.9,0.4,0.8),Color("47734a"))
  "frost":
   for side in [-1,1]:art.cone(parent,pos+Vector3(side*0.18,0.3,0),0.26,0,0.9,Color("b4d6de"),5)
  "ruins":
   art.cone(parent,pos+Vector3(0,0.28,0),0.38,0.30,0.8,Color("708095"),6)
   art.ring(parent,pos+Vector3(0,0.7,0),0.3,Color("9dc8ed"),0.035,6)
  "marsh":
   art.rod(parent,pos+Vector3(-0.4,0.15,-0.2),pos+Vector3(0.4,0.45,0.2),0.23,Color("64725c"))
  _:
   art.rock(parent,pos+Vector3(0,0.22,0),Vector3(0.85,0.65,0.75),Color("bc9768") if biome=="waste" else Color("b1ae92"))

static func enemy(art,pawn: Node3D,unit: Dictionary):
 var region=Regions.definition(unit.biome)
 pawn.set_meta("regional_enemy",unit.biome)
 var accent=Color(region.accent)
 for mesh in pawn.find_children("*","MeshInstance3D",true,false):
  for i in range(mesh.mesh.get_surface_count()):
   var material=mesh.get_surface_override_material(i)
   if material is ShaderMaterial and material.shader==preload("res://game/shaders/character.gdshader"):
    material.set_shader_parameter("tint",Color.WHITE.lerp(accent,0.3))
 if unit.get("boss",false):
  pawn.get_node("Body").scale*=1.15
  preload("res://game/boss_visual.gd").decorate(art,pawn,unit)
