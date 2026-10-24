extends RefCounted
const CLOTH=preload("res://game/shaders/garment.gdshader")
const PALETTES={"hero":[Color("507c77"),Color("cfbd8e")],"blade":[Color("956d50"),Color("dbc494")],"ranger":[Color("657751"),Color("c7bf91")],"medic":[Color("d3d0b6"),Color("739d88")],"engineer":[Color("968258"),Color("d1b478")],"warden":[Color("526b7b"),Color("c5bb98")]}

static func attach(model: Node3D,role: String):
 var skeleton=model.find_child("Skeleton3D",true,false) as Skeleton3D
 if skeleton==null:return
 var torso=skeleton.find_bone("Torso")
 if torso<0:return
 var attachment=BoneAttachment3D.new()
 attachment.name="Wardrobe"
 attachment.bone_name="Torso"
 skeleton.add_child(attachment)
 var inverse=skeleton.get_bone_global_rest(torso).affine_inverse()
 var palette=PALETTES.get(role,[Color("665044"),Color("af9770")])
 var material=ShaderMaterial.new()
 material.shader=CLOTH
 material.set_shader_parameter("cloth_color",palette[0])
 material.set_shader_parameter("trim_color",palette[1])
 if not role.begins_with("enemy"):
  # Tapered curved cloth pinned at the shoulders, with a shaped and trimmed hem.
  var width=0.72 if role in ["hero","warden"] else (0.40 if role=="blade" else 0.58)
  var length=1.10 if role=="warden" else (0.76 if role=="hero" else 0.46)
  if role=="engineer":length=0.26
  cloth(attachment,inverse,width,length,material,role=="blade")
  # A curved shoulder wrap adds a second layer without enclosing the moving arms.
  if role in ["hero","medic","warden"]:mantle(attachment,inverse,material)
  detail(attachment,inverse,Vector3(0.18,1.82,0.30),Vector3(0.12,0.12,0.045),palette[1])
  if role=="engineer":
   detail(attachment,inverse,Vector3(-0.48,1.20,-0.25),Vector3(0.32,0.42,0.19),Color("735d42"))
   detail(attachment,inverse,Vector3(-0.48,1.29,-0.36),Vector3(0.27,0.10,0.08),Color("b7a37c"))
 # Small facial geometry follows the head bone, not the torso/camera.
 var head=skeleton.find_bone("Head")
 if head<0:head=skeleton.find_bone("Head_2")
 if head<0:return
 var face=BoneAttachment3D.new()
 face.name="FaceDetails"
 face.bone_name=skeleton.get_bone_name(head)
 skeleton.add_child(face)
 var head_rest=skeleton.get_bone_global_rest(head)
 var face_inverse=head_rest.affine_inverse()
 var y=head_rest.origin.y
 var eye_z=0.66 if role in ["blade","enemy1"] else (0.515 if role=="medic" else 0.46)
 if role=="medic":
  detail(face,face_inverse,Vector3(0,y+0.39,0.31),Vector3(0.57,0.74,0.40),Color("c9a07c"))
  detail(face,face_inverse,Vector3(0,y+0.19,0.49),Vector3(0.085,0.018,0.025),Color("896754"))
 for side in [-1,1]:
  detail(face,face_inverse,Vector3(side*0.115,y+0.35,eye_z),Vector3(0.075,0.040,0.035),Color("353e39"))
  detail(face,face_inverse,Vector3(side*0.115,y+0.42,eye_z-0.025),Vector3(0.11,0.025,0.03),Color("514b3c"))
  detail(face,face_inverse,Vector3(side*0.11,y+0.36,eye_z+0.022),Vector3(0.014,0.015,0.012),Color("e5e5d0"))

static func cloth(parent: Node3D,inverse: Transform3D,width: float,length: float,material: Material,asymmetric: bool):
 var st=SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var cols=12
 var rows=12
 for row in range(rows):
  for col in range(cols):
   for corner in [Vector2(0,0),Vector2(0,1),Vector2(1,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
    var u=(col+corner.x)/cols
    var v=(row+corner.y)/rows
    var x=(u-0.5)*width*(1+v*0.45)
    var y=1.83-v*length+sin(u*PI)*0.10*v
    if asymmetric:y-=u*0.17
    var z=-0.28-0.13*sin(u*PI)-0.12*v+sin(u*PI*4)*0.025*v
    st.set_uv(Vector2(u,v))
    st.add_vertex(inverse*Vector3(x,y,z))
 st.generate_normals()
 var mesh=MeshInstance3D.new()
 mesh.name="TravelCloth"
 mesh.mesh=st.commit()
 mesh.material_override=material
 parent.add_child(mesh)

static func mantle(parent: Node3D,inverse: Transform3D,material: Material):
 var st=SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(24):
  for corner in [Vector2(0,0),Vector2(0,1),Vector2(1,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
   var u=(i+corner.x)/24.0
   var v=corner.y
   var a=TAU*u
   var radius=lerpf(0.22,0.53,v)
   var p=Vector3(cos(a)*radius,1.93-v*0.32,sin(a)*radius*0.64)
   st.set_uv(Vector2(u,v))
   st.add_vertex(inverse*p)
 st.generate_normals()
 var mesh=MeshInstance3D.new()
 mesh.name="ShoulderWrap"
 mesh.mesh=st.commit()
 mesh.material_override=material
 parent.add_child(mesh)

static func detail(parent: Node3D,inverse: Transform3D,pos: Vector3,size: Vector3,color: Color):
 var mesh=MeshInstance3D.new()
 var sphere=SphereMesh.new()
 sphere.radius=0.5
 sphere.height=1
 sphere.radial_segments=16
 sphere.rings=8
 mesh.mesh=sphere
 mesh.transform=inverse*Transform3D(Basis.IDENTITY.scaled(size),pos)
 var material=StandardMaterial3D.new()
 material.albedo_color=color
 material.roughness=0.9
 mesh.material_override=material
 parent.add_child(mesh)
