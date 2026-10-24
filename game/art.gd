extends RefCounted
# Original procedural art: all assets share a restrained, painterly palette.
const PAINT=preload("res://game/shaders/painterly.gdshader")
const GRASS=preload("res://game/shaders/grass.gdshader")
const WATER=preload("res://game/shaders/water.gdshader")
const CLOTH=preload("res://game/shaders/cloth.gdshader")
const TIDE=preload("res://game/shaders/tide.gdshader")
var materials={}

func paint(color: Color,variation: float=0.12) -> ShaderMaterial:
 var key=str(color)+str(variation)
 if materials.has(key):return materials[key]
 var m=ShaderMaterial.new()
 m.shader=PAINT
 m.set_shader_parameter("base_color",color)
 m.set_shader_parameter("variation",variation)
 materials[key]=m
 return m

func mesh(parent: Node3D,geometry: Mesh,pos: Vector3,color: Color) -> MeshInstance3D:
 var n=MeshInstance3D.new()
 n.mesh=geometry
 n.position=pos
 n.material_override=paint(color)
 parent.add_child(n)
 return n

func box(parent: Node3D,pos: Vector3,size: Vector3,color: Color) -> MeshInstance3D:
 var g=BoxMesh.new()
 g.size=size
 return mesh(parent,g,pos,color)

func ball(parent: Node3D,pos: Vector3,scale_size: Vector3,color: Color) -> MeshInstance3D:
 var g=SphereMesh.new()
 g.radius=0.5
 g.height=1
 g.radial_segments=12
 g.rings=7
 var n=mesh(parent,g,pos,color)
 n.scale=scale_size
 return n

func cone(parent: Node3D,pos: Vector3,bottom: float,top: float,height: float,color: Color,sides: int=10):
 var g=CylinderMesh.new()
 g.bottom_radius=bottom
 g.top_radius=top
 g.height=height
 g.radial_segments=sides
 return mesh(parent,g,pos,color)

func rod(parent: Node3D,a: Vector3,b: Vector3,width: float,color: Color):
 var n=cone(parent,(a+b)*0.5,width,width*0.8,a.distance_to(b),color,8)
 var direction=(b-a).normalized()
 n.quaternion=Quaternion(Vector3.UP,direction)
 return n

func cloth(parent: Node3D,pos: Vector3,width: float,height: float,color: Color):
 var g=PlaneMesh.new()
 g.size=Vector2(width,height)
 g.subdivide_width=5
 g.subdivide_depth=7
 var n=mesh(parent,g,pos,color)
 n.rotation_degrees.x=90
 var m=ShaderMaterial.new()
 m.shader=CLOTH
 m.set_shader_parameter("base_color",color)
 n.material_override=m
 return n

func ring(parent: Node3D,pos: Vector3,radius: float,color: Color,width: float=0.025,sides: int=6):
 var verts=PackedVector3Array()
 var normals=PackedVector3Array()
 for i in range(sides):
  var a=PI*0.5+TAU*i/sides
  var b=PI*0.5+TAU*(i+1)/sides
  var out_a=Vector3(cos(a)*radius,0,sin(a)*radius)
  var out_b=Vector3(cos(b)*radius,0,sin(b)*radius)
  var in_a=out_a*(radius-width)/radius
  var in_b=out_b*(radius-width)/radius
  for p in [out_a,in_a,out_b,out_b,in_a,in_b]:
   verts.append(p)
   normals.append(Vector3.UP)
 var arrays=[]
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=verts
 arrays[Mesh.ARRAY_NORMAL]=normals
 var g=ArrayMesh.new()
 g.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var n=mesh(parent,g,pos,color)
 var m=StandardMaterial3D.new()
 m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 m.albedo_color=color
 m.cull_mode=BaseMaterial3D.CULL_DISABLED
 n.material_override=m
 return n

func tree(parent: Node3D,pos: Vector3,s: float=1.0):
 var root=Node3D.new()
 root.position=pos
 root.scale=Vector3.ONE*s
 parent.add_child(root)
 cone(root,Vector3(0,0.85,0),0.19,0.10,1.7,Color("75664c"),8)
 rod(root,Vector3(0,1.1,0),Vector3(-0.6,1.9,0.1),0.09,Color("75664c"))
 rod(root,Vector3(0,1.2,0),Vector3(0.65,1.8,-0.1),0.08,Color("75664c"))
 for entry in [[Vector3(0,2.3,0),Vector3(2.4,1.5,1.9),Color("5d8246")],[Vector3(-0.65,2,0.2),Vector3(1.6,1.25,1.6),Color("76914c")],[Vector3(0.65,2.15,0.05),Vector3(1.7,1.3,1.65),Color("648949")],[Vector3(0.1,2.75,0),Vector3(1.7,1,1.4),Color("8c9e56")]]:
  ball(root,entry[0],entry[1],entry[2])
 return root

func rock(parent: Node3D,pos: Vector3,s: Vector3,color: Color=Color("a4a18a")):
 var n=ball(parent,pos,s,color)
 n.rotation_degrees=Vector3(11,pos.x*19,17)
 return n

func terrain_height(x: float,z: float) -> float:
 var edge=clampf((Vector2(x,z).length()-7.5)/8.0,0,1)
 return -0.14+edge*(1.1+sin(x*0.37)*0.65+cos(z*0.49)*0.55)+sin(x*1.7+z)*0.018

func terrain(parent: Node3D):
 var count=70
 var extent=32.0
 var vertices=PackedVector3Array()
 var normals=PackedVector3Array()
 var colors=PackedColorArray()
 var indices=PackedInt32Array()
 for z in range(count+1):
  for x in range(count+1):
   var px=(float(x)/count-0.5)*extent
   var pz=(float(z)/count-0.5)*extent
   var y=terrain_height(px,pz)
   vertices.append(Vector3(px,y,pz))
   var dx=(terrain_height(px+0.05,pz)-terrain_height(px-0.05,pz))/0.1
   var dz=(terrain_height(px,pz+0.05)-terrain_height(px,pz-0.05))/0.1
   normals.append(Vector3(-dx,1,-dz).normalized())
 for z in range(count):
  for x in range(count):
   var i=z*(count+1)+x
   indices.append_array(PackedInt32Array([i,i+1,i+count+1,i+1,i+count+2,i+count+1]))
 var arrays=[]
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices
 arrays[Mesh.ARRAY_NORMAL]=normals
 arrays[Mesh.ARRAY_INDEX]=indices
 var g=ArrayMesh.new()
 g.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var n=mesh(parent,g,Vector3.ZERO,Color("71804b"))
 # Terrain patch colors are painted mathematically, avoiding photographic noise.
 n.material_override=paint(Color("71864e"),0.28)
 n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 n.name="Meadow"
 return n

func grass(parent: Node3D,seed_value: int,count: int,extent: Vector2,exclude_center: bool=false):
 var rng=RandomNumberGenerator.new()
 rng.seed=seed_value
 var surface=SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(3):
  var angle=PI*i/3
  var side=Vector3(cos(angle),0,sin(angle))*0.075
  for entry in [[-side,Vector2(0,0)],[Vector3(0.03,0.48,0),Vector2(0.5,1)],[side,Vector2(1,0)]]:
   surface.set_uv(entry[1])
   surface.set_normal(Vector3.UP)
   surface.add_vertex(entry[0])
 var geometry=surface.commit()
 var multi=MultiMesh.new()
 multi.transform_format=MultiMesh.TRANSFORM_3D
 multi.mesh=geometry
 multi.instance_count=count
 for i in range(count):
  var x=rng.randf_range(-extent.x,extent.x)
  var z=rng.randf_range(-extent.y,extent.y)
  if exclude_center and Vector2(x,z).length()<5.7:
   var angle=rng.randf()*TAU
   var r=rng.randf_range(6.0,10.5)
   x=cos(angle)*r
   z=sin(angle)*r
  if exclude_center and absf(x-(6.6+sin(z*0.24)*0.8))<1.4:x+=3.0
  if not exclude_center:
   if absf(z-(-10.5+sin(x*0.28)*1.2))<1.4:z+=2.8
   if absf(x-sin(z*0.24)*1.7)<1.3:x+=2.5
  var h=terrain_height(x,z) if exclude_center else -0.08
  var size=rng.randf_range(0.5,1.35)
  var basis=Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(size,size,size))
  multi.set_instance_transform(i,Transform3D(basis,Vector3(x,h,z)))
 var node=MultiMeshInstance3D.new()
 node.name="WindGrass"
 node.multimesh=multi
 var m=ShaderMaterial.new()
 m.shader=GRASS
 node.material_override=m
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 parent.add_child(node)

func broken_bridge(parent: Node3D):
 var root=Node3D.new()
 root.name="BrokenBridge"
 root.position=Vector3(6.0,0,-3.0)
 root.rotation_degrees.y=-16
 parent.add_child(root)
 var stone=Color("bab49a")
 # Two broken abutments, individual paving stones, parapets and fallen masonry.
 for side in [-1,1]:
  for row in range(3):
   for col in range(3):
    box(root,Vector3(side*(1.6+col*0.48),0.2+row*0.3,0),Vector3(0.46,0.28,1.65),stone.darkened(row*0.035))
  for j in range(5):
   box(root,Vector3(side*(1.3+j*0.33),1.12,0),Vector3(0.32,0.16,1.8),stone.lightened(0.04))
  for rail in [-1,1]:
   for j in range(4):
    var n=box(root,Vector3(side*(1.5+j*0.43),1.46,rail*0.8),Vector3(0.4,0.48,0.22),stone)
    n.rotation_degrees.z=side*j*1.5
 for j in range(7):
  var n=box(root,Vector3(-0.9+j*0.3,0.05,-0.4+sin(j)*0.4),Vector3(0.4,0.32,0.5),stone.darkened(0.12))
  n.rotation_degrees=Vector3(j*9,j*37,15)
 return root

func ruin(parent: Node3D,pos: Vector3):
 var root=Node3D.new()
 root.position=pos
 parent.add_child(root)
 var stone=Color("aaa68b")
 for row in range(5):
  for col in range(4-row/2):
   var n=box(root,Vector3(col*0.48-0.65,row*0.36+0.18,0),Vector3(0.45,0.33,0.45),stone.darkened(row*0.025))
   n.rotation_degrees.y=(col-row)*1.7
 for j in range(3):
  box(root,Vector3(-0.7,0.35+j*0.35,0.5),Vector3(0.5,0.32,0.48),stone)
 rod(root,Vector3(0.7,0,0),Vector3(0.7,3.3,0),0.045,Color("746649"))
 cloth(root,Vector3(1.08,2.85,0),0.7,0.8,Color("9d6d49"))
 cone(root,Vector3(-0.5,0.05,0.25),0.4,0.38,0.1,Color("78824a"),12)

func river(parent: Node3D):
 var vertices=PackedVector3Array()
 var normals=PackedVector3Array()
 var uvs=PackedVector2Array()
 var indices=PackedInt32Array()
 for i in range(65):
  var z=-16.0+i*0.5
  var x=6.6+sin(z*0.24)*0.8
  for side in [-1,1]:
   vertices.append(Vector3(x+side*1.15,-0.07,z))
   normals.append(Vector3.UP)
   uvs.append(Vector2((side+1)*0.5,i*0.1))
  if i<64:
   var k=i*2
   indices.append_array(PackedInt32Array([k,k+1,k+2,k+1,k+3,k+2]))
 var arrays=[]
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices
 arrays[Mesh.ARRAY_NORMAL]=normals
 arrays[Mesh.ARRAY_TEX_UV]=uvs
 arrays[Mesh.ARRAY_INDEX]=indices
 var geometry=ArrayMesh.new()
 geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var n=mesh(parent,geometry,Vector3.ZERO,Color.WHITE)
 n.name="Brook"
 var m=ShaderMaterial.new()
 m.shader=WATER
 n.material_override=m
 return n

func landscape(parent: Node3D,safe_radius: int=4):
 var root=Node3D.new()
 root.name="BattleLandscape"
 parent.add_child(root)
 var meadow=terrain(root)
 meadow.material_override=meadow.material_override.duplicate()
 meadow.material_override.set_shader_parameter("safe_radius",float(safe_radius) if safe_radius<4 else -1.0)
 grass(root,1207,2200,Vector2(13,12),true)
 # Continuous ribbon geometry avoids the old stepped water blocks.
 river(root)
 for j in range(12):
  var z=-12.0+j*2.0
  var x=6.6+sin(z*0.24)*0.8
  rock(root,Vector3(x-1.4,0.04,z),Vector3(0.6,0.3,0.65),Color("aba88c"))
 broken_bridge(root)
 ruin(root,Vector3(-4.8,0,-5.0))
 ruin(root,Vector3(1.5,0,-6.7))
 var rng=RandomNumberGenerator.new()
 rng.seed=55017
 for i in range(36):
  var angle=rng.randf()*TAU
  var radius=rng.randf_range(7.7,13.5)
  var p=Vector3(cos(angle)*radius,0,sin(angle)*radius)
  p.y=terrain_height(p.x,p.z)
  if p.x>5.0 and p.x<8.8:continue
  if i%3==0:rock(root,p+Vector3(0,0.3,0),Vector3(1.8,1.2,1.4))
  else:tree(root,p,rng.randf_range(0.7,1.2))
 # Small wildflowers and worn stone chips inside the open meadow.
 for i in range(55):
  var x=rng.randf_range(-5.2,5.2)
  var z=rng.randf_range(-5,5)
  if Vector2(x,z).length()<2 or absf(x)<1:continue
  if i%3==0:
   cone(root,Vector3(x,0.02,z),0.08,0.07,0.06,Color("c6b873"),5)
  else:
   rock(root,Vector3(x,-0.05,z),Vector3(0.15,0.10,0.2),Color("a6a18a"))
 return root

func tide(parent: Node3D,radius: int,warning: bool):
 var root=Node3D.new()
 root.name="GreyTide"
 parent.add_child(root)
 var r=(radius+0.9)*1.35
 var vertices=PackedVector3Array()
 var uvs=PackedVector2Array()
 var segments=72
 for i in range(segments):
  var a=TAU*i/segments
  var b=TAU*(i+1)/segments
  for entry in [[Vector3(cos(a)*r,0,sin(a)*r),Vector2(0,0)],[Vector3(cos(a)*r,1.9,sin(a)*r),Vector2(0,1)],[Vector3(cos(b)*r,0,sin(b)*r),Vector2(1,0)],[Vector3(cos(b)*r,0,sin(b)*r),Vector2(1,0)],[Vector3(cos(a)*r,1.9,sin(a)*r),Vector2(0,1)],[Vector3(cos(b)*r,1.9,sin(b)*r),Vector2(1,1)]]:
   vertices.append(entry[0])
   uvs.append(entry[1])
 var arrays=[]
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices
 arrays[Mesh.ARRAY_TEX_UV]=uvs
 var geometry=ArrayMesh.new()
 geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var n=mesh(root,geometry,Vector3.ZERO,Color.WHITE)
 var m=ShaderMaterial.new()
 m.shader=TIDE
 n.material_override=m
 if warning:ring(root,Vector3(0,0.025,0),r,Color("d9a45e"),0.035,72)
 return root

func character(parent: Node3D,pos: Vector3,color: Color,kind: String,active: bool) -> Node3D:
 var root=Node3D.new()
 root.position=pos
 root.name="Character_"+kind
 parent.add_child(root)
 var enemy=kind.begins_with("enemy")
 var dark=Color("383d3a")
 var leather=Color("766044")
 var skin=Color("d2b58a")
 var steel=Color("a6b6b1")
 var body=Node3D.new()
 body.name="Body"
 root.add_child(body)
 # Boots, articulated legs and a layered tunic replace the chess-pawn silhouette.
 for side in [-1,1]:
  var x=side*0.135
  box(body,Vector3(x,0.12,0.02),Vector3(0.17,0.23,0.27),leather.darkened(0.2))
  rod(body,Vector3(x,0.2,0),Vector3(x,0.57,0),0.075,dark)
 cone(body,Vector3(0,0.60,0),0.25,0.19,0.25,color.darkened(0.15),8)
 cone(body,Vector3(0,0.83,0),0.19,0.25,0.40,color,10)
 cone(body,Vector3(0,0.64,0),0.215,0.215,0.06,leather,10)
 box(body,Vector3(0,0.65,0.21),Vector3(0.075,0.065,0.03),Color("c5aa68"))
 rod(body,Vector3(-0.18,1.0,-0.02),Vector3(0.16,0.70,0.18),0.027,leather)
 ball(body,Vector3(0,1.21,0),Vector3(0.33,0.39,0.32),skin)
 # Hair cap, fringe and face direction remain readable from above.
 ball(body,Vector3(0,1.36,-0.025),Vector3(0.36,0.22,0.34),Color("554d3b") if kind!="medic" else Color("c5b995"))
 for side in [-1,1]:
  box(body,Vector3(side*0.115,1.30,0.105),Vector3(0.08,0.15,0.08),Color("554d3b") if kind!="medic" else Color("c5b995"))
  rod(body,Vector3(side*0.27,0.98,0),Vector3(side*0.32,0.73,0.02),0.082,color)
  rod(body,Vector3(side*0.32,0.73,0.02),Vector3(side*0.3,0.61,0.13),0.06,leather)
  ball(body,Vector3(side*0.3,0.61,0.13),Vector3(0.12,0.14,0.12),skin)
  ball(body,Vector3(side*0.24,1.0,0),Vector3(0.23,0.14,0.23),steel if kind in ["hero","warden"] else color.lightened(0.08))
 box(body,Vector3(-0.07,1.23,0.15),Vector3(0.025,0.025,0.015),dark)
 box(body,Vector3(0.07,1.23,0.15),Vector3(0.025,0.025,0.015),dark)
 cloth(body,Vector3(0,0.86,-0.22),0.48,0.66,color.darkened(0.20))
 # Distinct job equipment, not just recolored uniforms.
 if kind in ["hero","blade"] or enemy:
  var sword=box(body,Vector3(0.33,0.89,0.24),Vector3(0.065,0.64,0.045),steel)
  sword.rotation_degrees.z=-16
  box(body,Vector3(0.33,0.62,0.24),Vector3(0.22,0.045,0.08),Color("bc9d5e"))
  if kind=="hero":
   cone(body,Vector3(-0.34,0.79,0.07),0.21,0.21,0.06,Color("687d78"),12).rotation_degrees.z=90
  elif kind=="blade":cloth(body,Vector3(0.22,1.06,-0.1),0.7,0.12,Color("b6a879"))
 elif kind=="ranger":
  for j in range(7):
   var theta=PI*(0.1+0.8*j/6.0)
   var theta2=PI*(0.1+0.8*(j+1)/6.0)
   rod(body,Vector3(-0.35,0.82+cos(theta)*0.4,sin(theta)*0.22),Vector3(-0.35,0.82+cos(theta2)*0.4,sin(theta2)*0.22),0.025,leather)
  rod(body,Vector3(-0.35,0.45,0.07),Vector3(-0.35,1.20,0.07),0.009,Color("d3c8a9"))
  cone(body,Vector3(0.13,0.95,-0.24),0.08,0.09,0.5,leather,8)
 elif kind=="medic":
  rod(body,Vector3(0.36,0.03,0.13),Vector3(0.36,1.47,0.13),0.033,leather)
  ball(body,Vector3(0.36,1.45,0.13),Vector3(0.18,0.22,0.18),Color("7ecaba"))
  box(body,Vector3(-0.28,0.65,0.08),Vector3(0.16,0.22,0.20),Color("b5ab84"))
 elif kind=="engineer":
  box(body,Vector3(0,0.85,-0.25),Vector3(0.34,0.45,0.24),leather)
  for side in [-1,1]:cone(body,Vector3(side*0.10,1.25,0.15),0.075,0.075,0.045,Color("bf9e60"),12).rotation_degrees.x=90
  box(body,Vector3(0.35,0.67,0.20),Vector3(0.12,0.10,0.6),dark)
 elif kind=="warden":
  var shield=box(body,Vector3(-0.34,0.80,0.15),Vector3(0.11,0.65,0.46),steel)
  shield.rotation_degrees.y=-12
  box(body,Vector3(-0.40,0.80,0.15),Vector3(0.025,0.42,0.06),Color("be9b5d"))
 if active:ring(root,Vector3(0,0.035,0),0.43,Color("e1c88c"),0.045,40)
 else:ring(root,Vector3(0,0.025,0),0.34,Color("ab6a53") if enemy else Color("6faaa0"),0.018,32)
 root.rotation_degrees.y=-15 if enemy else 20
 return root
