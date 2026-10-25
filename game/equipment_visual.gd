extends RefCounted
# Gear uses the same scene builder for live pawns and portrait renders.
const Jobs=preload("res://game/professions.gd")
const Shapes=preload("res://game/equipment_shapes.gd")
const WEAPONS={"sword":["Warrior","Warrior_Sword"],"dagger":["Rogue","Rogue_Dagger"],"bow":["Ranger","Ranger_Bow"],"staff":["Cleric","Cleric_Staff"]}
static var weapon_resources: Dictionary={}
static var animation_resources: Dictionary={}

static func signature(profile: Dictionary) -> String:
 return JSON.stringify([profile.get("appearance",""),profile.get("mainhand",""),profile.get("offhand",""),profile.get("armor","")])

static func material(color: String,metal: float=0.0) -> StandardMaterial3D:
 var result=StandardMaterial3D.new()
 result.albedo_color=Color(color)
 result.metallic=metal
 result.roughness=0.58 if metal>0 else 0.94
 return result

static func part(parent: Node3D,shape: Mesh,pos: Vector3,mat: Material,name: String="") -> MeshInstance3D:
 var mesh=MeshInstance3D.new()
 mesh.mesh=shape;mesh.position=pos;mesh.material_override=mat
 if name!="":mesh.name=name
 parent.add_child(mesh)
 return mesh

static func block(parent: Node3D,pos: Vector3,size: Vector3,mat: Material,name: String="") -> MeshInstance3D:
 var mesh=BoxMesh.new();mesh.size=size
 return part(parent,mesh,pos,mat,name)

static func ellipsoid(parent: Node3D,pos: Vector3,size: Vector3,mat: Material) -> MeshInstance3D:
 var mesh=SphereMesh.new();mesh.radius=0.5;mesh.height=1.0;mesh.radial_segments=12;mesh.rings=6
 var node=part(parent,mesh,pos,mat);node.scale=size
 return node

static func mount(skeleton: Skeleton3D,name: String,bone: String) -> BoneAttachment3D:
 if skeleton.find_bone(bone)<0:return null
 var result=BoneAttachment3D.new();result.name=name;result.bone_name=bone
 skeleton.add_child(result)
 return result

static func rest_space(skeleton: Skeleton3D,attachment: BoneAttachment3D) -> Node3D:
 var result=Node3D.new();attachment.add_child(result)
 result.transform=skeleton.get_bone_global_rest(skeleton.find_bone(attachment.bone_name)).affine_inverse()
 return result

static func weapon_resource(id: String) -> Dictionary:
 if weapon_resources.has(id):return weapon_resources[id]
 var source=WEAPONS[id]
 var donor=load("res://assets/characters/quaternius/%s.gltf"%source[0]).instantiate()
 var mesh=donor.find_child(source[1],true,false) as MeshInstance3D
 var result={"transform":mesh.transform}
 weapon_resources[id]=result
 donor.free()
 return result

static func armor_piece(skeleton: Skeleton3D,root_attachment: BoneAttachment3D,bone: String,name: String) -> Node3D:
 # Children remain under their own bones, marked for replacement along with the torso.
 var attachment=root_attachment if bone=="Torso" else mount(skeleton,name,bone)
 if attachment==null:return null
 attachment.set_meta("equipment_armor",true)
 return rest_space(skeleton,attachment)

static func edge_ring(parent: Node3D,y: float,width: float,depth: float,offset: float,mat: Material,name: String,start: float=-PI,end: float=PI):
 var points=[]
 for i in 33:
  var angle=lerpf(start,end,i/32.0)
  points.append(Vector3(sin(angle)*width,y,cos(angle)*depth+offset))
 Shapes.tube(parent,points,0.012,mat,name,6)

static func armor(skeleton: Skeleton3D,id: String):
 var root=mount(skeleton,"EquippedArmor","Torso")
 if root==null:return
 root.set_meta("item_id",id)
 var torso=armor_piece(skeleton,root,"Torso","")
 var plate=id=="plate"
 var base=material("81959c",0.62) if plate else material("76523b")
 var edge=material("bca779",0.48) if plate else material("b9976c")
 var dark=material("38444a",0.15) if plate else material("49352a")
 var steel=material("a3afb0",0.60)
 # Rounded chest, narrow waist and raised collar: there is no flat box across the torso.
 var rows=[Vector4(1.25,0.32,0.27,0.02),Vector4(1.34,0.34,0.29,0.02),Vector4(1.51,0.44,0.355,0.015),Vector4(1.66,0.435,0.335,0.01),Vector4(1.77,0.34,0.245,0.005)]
 Shapes.shell(torso,rows,base,"Breastplate" if plate else "LeatherVest",28)
 edge_ring(torso,1.77,0.34,0.245,0.005,edge,"RolledNeckline")
 edge_ring(torso,1.265,0.325,0.275,0.02,dark,"WaistBelt")
 if plate:
  # Short overlapping curved lames track the waist instead of crossing the whole chest.
  for i in 3:
   var y=1.31-i*0.065
   var width=0.345+i*0.024
   Shapes.shell(torso,[Vector4(y-0.065,width+0.013,0.282+i*0.012,0.02),Vector4(y,width,0.278+i*0.012,0.02)],base,"WaistLame%d"%i,24)
   edge_ring(torso,y-0.063,width+0.015,0.284+i*0.012,0.02,edge,"LameEdge%d"%i,-1.65,1.65)
  Shapes.tube(torso,[Vector3(0,1.39,0.335),Vector3(0,1.52,0.379),Vector3(0,1.64,0.356),Vector3(0,1.73,0.285)],0.012,steel,"SternumRidge",6)
  for side in [-1,1]:
   Shapes.tube(torso,[Vector3(side*0.09,1.42,0.34),Vector3(side*0.20,1.55,0.332),Vector3(side*0.27,1.68,0.27)],0.008,steel,"ChestFlute",6)
   ellipsoid(torso,Vector3(side*0.24,1.69,0.292),Vector3(0.032,0.032,0.022),edge)
 else:
  for side in [-1,1]:
   Shapes.tube(torso,[Vector3(side*0.25,1.71,0.24),Vector3(side*0.27,1.60,0.29),Vector3(side*0.20,1.36,0.28)],0.026,dark,"LeatherHarness",8)
   Shapes.tube(torso,[Vector3(side*0.29,1.69,0.22),Vector3(side*0.34,1.54,0.24),Vector3(side*0.27,1.35,0.23)],0.006,edge,"VestSeam",5)
   block(torso,Vector3(side*0.25,1.61,0.326),Vector3(0.065,0.065,0.018),edge,"HarnessBuckle")
 for side in [-1,1]:
  var suffix="L" if side==1 else "R"
  var shoulder=armor_piece(skeleton,root,"UpperArm."+suffix,"EquipmentShoulder"+suffix)
  if shoulder!=null:
   var cap=Node3D.new();shoulder.add_child(cap);cap.position=Vector3(side*0.48,1.80,0.005)
   cap.rotation.z=-side*0.20
   var cap_rows=[Vector4(-0.10,0.245 if plate else 0.19,0.26,0),Vector4(0.015,0.26 if plate else 0.20,0.285,0),Vector4(0.12,0.17 if plate else 0.15,0.19,0),Vector4(0.17,0.065,0.08,0)]
   Shapes.shell(cap,cap_rows,base,"ShapedPauldron",20)
   edge_ring(cap,-0.095,0.245 if plate else 0.19,0.26,0,edge,"PauldronRolledEdge")
   if plate:
    Shapes.shell(cap,[Vector4(-0.17,0.22,0.23,0),Vector4(-0.09,0.242,0.255,0)],steel,"PauldronLowerLame",20)
    for front in [-1,1]:ellipsoid(cap,Vector3(side*0.16,-0.07,front*0.19),Vector3(0.035,0.035,0.035),edge)
  if not plate:continue
  var arm=armor_piece(skeleton,root,"LowerArm."+suffix,"EquipmentBracer"+suffix)
  if arm!=null:
   var rest=skeleton.get_bone_global_rest(skeleton.find_bone("LowerArm."+suffix)).origin
   var cuff=Node3D.new();arm.add_child(cuff);cuff.position=rest+Vector3(0,-0.25,0.04)
   Shapes.shell(cuff,[Vector4(-0.16,0.105,0.12,0),Vector4(0.03,0.15,0.15,0),Vector4(0.14,0.145,0.15,0)],base,"TaperedVambrace",16)
   edge_ring(cuff,-0.15,0.107,0.122,0,edge,"WristEdge")
  var leg=armor_piece(skeleton,root,"LowerLeg."+suffix,"EquipmentGreave"+suffix)
  if leg!=null:
   var shin=Node3D.new();leg.add_child(shin);shin.position=Vector3(side*0.205,0,0.05)
   Shapes.shell(shin,[Vector4(0.17,0.10,0.115,0),Vector4(0.32,0.125,0.16,0),Vector4(0.49,0.15,0.17,0),Vector4(0.56,0.12,0.14,0)],base,"CurvedGreave",18,-1.9,1.9)
   Shapes.tube(shin,[Vector3(0,0.20,0.13),Vector3(0,0.36,0.18),Vector3(0,0.52,0.175)],0.009,steel,"GreaveRidge",6)
   ellipsoid(shin,Vector3(0,0.57,0.13),Vector3(0.29,0.23,0.17),steel)
   edge_ring(shin,0.18,0.103,0.12,0,edge,"AnkleEdge",-1.7,1.7)

static func shield(skeleton: Skeleton3D):
 var attachment=mount(skeleton,"EquippedOffhand","LowerArm.L")
 if attachment==null:return
 attachment.set_meta("item_id","shield")
 var root=rest_space(skeleton,attachment)
 var center=skeleton.get_bone_global_rest(skeleton.find_bone("LowerArm.L")).origin+Vector3(0.11,-0.23,0.24)
 var face_root=Node3D.new();root.add_child(face_root);face_root.position=center
 var wood=material("795b3c");var wood_light=material("8e6d46");var rim=material("9c9e92",0.60);var trim=material("bca777",0.48);var leather=material("49372a")
 # A dished oval, with narrow alternating staves and a rounded metal rim.
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var segments=32;var rings=5
 for ring in rings:
  for i in segments:
   var angle0=TAU*i/segments;var angle1=TAU*(i+1)/segments
   var r0=float(ring)/rings;var r1=float(ring+1)/rings
   var a=Vector3(sin(angle0)*0.36*r0,cos(angle0)*0.43*r0,0.09*(1-r0*r0))
   var b=Vector3(sin(angle1)*0.36*r0,cos(angle1)*0.43*r0,0.09*(1-r0*r0))
   var c=Vector3(sin(angle1)*0.36*r1,cos(angle1)*0.43*r1,0.09*(1-r1*r1))
   var d=Vector3(sin(angle0)*0.36*r1,cos(angle0)*0.43*r1,0.09*(1-r1*r1))
   Shapes.quad(st,a,b,c,d)
 Shapes.mesh_node(face_root,st,wood,"DishedWoodShield")
 var outline=[]
 for i in 41:
  var angle=TAU*i/40
  outline.append(Vector3(sin(angle)*0.365,cos(angle)*0.435,0))
 Shapes.tube(face_root,outline,0.028,rim,"RolledShieldRim",8)
 for x in [-0.24,-0.12,0.0,0.12,0.24]:
  var height=0.43*sqrt(1-pow(x/0.36,2))
  var points=[]
  for i in 9:
   var y=lerpf(-height,height,i/8.0)
   var r2=pow(x/0.36,2)+pow(y/0.43,2)
   points.append(Vector3(x,y,0.09*(1-r2)+0.004))
  Shapes.tube(face_root,points,0.005,leather,"WoodStaveSeam",5)
 for i in 12:
  var angle=TAU*(i+0.5)/12
  ellipsoid(face_root,Vector3(sin(angle)*0.335,cos(angle)*0.40,0.035),Vector3(0.028,0.028,0.022),trim)
 ellipsoid(face_root,Vector3(0,0,0.10),Vector3(0.19,0.19,0.13),rim)
 var boss_ring=[]
 for i in 25:boss_ring.append(Vector3(cos(TAU*i/24)*0.115,sin(TAU*i/24)*0.115,0.085))
 Shapes.tube(face_root,boss_ring,0.012,trim,"BossCollar",6)
 # Rear rim and braces remain visible from the battlefield camera and on attack swings.
 var back=CylinderMesh.new();back.top_radius=0.35;back.bottom_radius=0.35;back.height=0.035;back.radial_segments=32
 var backing=part(face_root,back,Vector3(0,0,-0.025),wood_light,"ShieldBack");backing.rotation.x=PI/2;backing.scale.z=1.19
 for x in [-0.16,0.16]:
  Shapes.tube(face_root,[Vector3(x,-0.23,-0.06),Vector3(x,-0.12,-0.12),Vector3(x,0.12,-0.12),Vector3(x,0.23,-0.06)],0.026,leather,"RearArmStrap",8)
 Shapes.tube(face_root,[Vector3(-0.11,-0.03,-0.09),Vector3(0.11,-0.03,-0.09)],0.028,leather,"RearHandGrip",8)

static func crossbow(skeleton: Skeleton3D,attachment: BoneAttachment3D):
 var root=rest_space(skeleton,attachment)
 var hand=skeleton.get_bone_global_rest(skeleton.find_bone("Weapon.R")).origin
 var weapon=Node3D.new();root.add_child(weapon);weapon.position=hand+Vector3(0,0.02,0.09)
 var wood=material("674b35");var metal=material("7c8c90",0.60);var edge=material("bca777",0.45);var string_mat=material("d2c4a4")
 # Tapered stock and a raised rail instead of a rectangular block.
 var outline=[Vector2(-0.075,-0.31),Vector2(-0.09,-0.18),Vector2(-0.048,0.42),Vector2(0.048,0.42),Vector2(0.09,-0.18),Vector2(0.075,-0.31)]
 var stock=Shapes.bevel_panel(weapon,outline,0.045,-0.045,0.16,wood,"CarvedCrossbowStock");stock.rotation.x=PI/2
 Shapes.tube(weapon,[Vector3(0,0.07,-0.17),Vector3(0,0.07,0.40)],0.018,metal,"BoltRail",6)
 for side in [-1,1]:
  Shapes.tube(weapon,[Vector3(0,0.025,0.29),Vector3(side*0.18,0.02,0.31),Vector3(side*0.34,0.01,0.26),Vector3(side*0.41,0.015,0.18)],0.033,metal,"RecurvedCrossbowLimb",8)
  Shapes.tube(weapon,[Vector3(side*0.41,0.015,0.18),Vector3(0,0.08,-0.02)],0.006,string_mat,"TautCrossbowString",5)
  ellipsoid(weapon,Vector3(side*0.095,0.035,0.27),Vector3(0.045,0.045,0.045),edge)
 Shapes.tube(weapon,[Vector3(0,0.10,-0.13),Vector3(0,0.10,0.45)],0.009,wood,"LoadedBoltShaft",6)
 var tip=Shapes.blade(weapon,[Vector3(0.42,0.035,0.013),Vector3(0.52,0,0)],metal,"BoltHead");tip.rotation.x=PI/2;tip.position.y=0.10
 Shapes.tube(weapon,[Vector3(-0.035,-0.045,-0.10),Vector3(-0.04,-0.11,-0.08),Vector3(0.04,-0.11,-0.08),Vector3(0.035,-0.045,-0.10)],0.008,edge,"TriggerGuard",6)
 var grip=Shapes.bevel_panel(weapon,[Vector2(-0.045,-0.18),Vector2(-0.05,0.04),Vector2(0.05,0.04),Vector2(0.045,-0.18)],0.035,-0.035,0.17,wood,"CrossbowGrip");grip.position.z=-0.13
 for i in 4:Shapes.tube(weapon,[Vector3(-0.04,-0.04-i*0.03,-0.085),Vector3(0.04,-0.04-i*0.03,-0.085)],0.006,edge,"GripBinding",5)

static func crafted_weapon(attachment: BoneAttachment3D,id: String):
 var root=Node3D.new();root.name="EquippedWeaponMesh";attachment.add_child(root)
 # The original weapon's local handle frame keeps retargeted animations aligned.
 root.transform=weapon_resource(id).transform
 var steel=material("a5b5b9",0.72);var dark=material("4b6066",0.55);var gold=material("b9a273",0.55);var leather=material("453b32");var wood=material("694e35")
 if id in ["sword","dagger"]:
  # Sword uses native +Y; dagger uses native -Z. Bring both into a shared blade frame.
  var blade_root=Node3D.new();root.add_child(blade_root)
  if id=="dagger":blade_root.rotation.x=-PI/2
  var length=2.30 if id=="sword" else 0.88
  var width=0.115 if id=="sword" else 0.075
  var grip=0.30 if id=="sword" else 0.20
  Shapes.blade(blade_root,[Vector3(0.12,width,0.045),Vector3(length*0.70,width*0.75,0.036),Vector3(length*0.90,width*0.52,0.022),Vector3(length,0,0)],steel,"ForgedBlade")
  Shapes.tube(blade_root,[Vector3(-width*2.5,0.15,-0.012),Vector3(-width,0.11,0),Vector3(0,0.10,0),Vector3(width,0.11,0),Vector3(width*2.5,0.15,-0.012)],0.035 if id=="sword" else 0.022,gold,"SweptCrossguard",8)
  Shapes.tube(blade_root,[Vector3(0,-grip,0),Vector3(0,0.08,0)],0.055 if id=="sword" else 0.039,leather,"LeatherGrip",10)
  for i in 6:
   var y=lerpf(-grip,0.06,i/5.0)
   var points=[]
   for j in 13:points.append(Vector3(cos(TAU*j/12)*0.057,y+sin(TAU*j/12)*0.01,sin(TAU*j/12)*0.057))
   Shapes.tube(blade_root,points,0.006,dark,"GripWrap",5)
  ellipsoid(blade_root,Vector3(0,-grip-0.065,0),Vector3(0.13,0.13,0.10),gold)
  Shapes.tube(blade_root,[Vector3(0,0.25,0.046),Vector3(0,length*0.65,0.038)],0.008,dark,"BladeFuller",5)
 elif id=="bow":
  # Match the imported bow's long Z axis, with visible recurve limbs and actual string.
  for side in [-1,1]:
   Shapes.tube(root,[Vector3(0,0,side*0.10),Vector3(0.08,0,side*0.35),Vector3(0.27,0,side*0.72),Vector3(0.32,0,side*0.94),Vector3(0.22,0,side*1.08)],0.035,wood,"CarvedBowLimb",8)
   Shapes.tube(root,[Vector3(0.22,0,side*1.08),Vector3(-0.07,0,0)],0.004,material("dbd0af"),"Bowstring",5)
   ellipsoid(root,Vector3(0.22,0,side*1.06),Vector3(0.065,0.065,0.08),gold)
  Shapes.tube(root,[Vector3(0,0,-0.14),Vector3(0,0,0.14)],0.054,leather,"BowGrip",10)
  for i in 5:Shapes.tube(root,[Vector3(-0.04,0.043,-0.12+i*0.06),Vector3(0.04,0.043,-0.12+i*0.06)],0.005,gold,"BowGripWrap",5)
 elif id=="staff":
  Shapes.tube(root,[Vector3(0,0,-1.25),Vector3(0.025,0,-0.60),Vector3(0,0,0.20),Vector3(-0.025,0,0.85)],0.038,wood,"ShapedStaffShaft",10)
  for side in [-1,1]:
   Shapes.tube(root,[Vector3(0,0,0.65),Vector3(side*0.17,0,0.86),Vector3(side*0.12,0,1.05),Vector3(0,0,1.14)],0.025,gold,"StaffCrown",8)
  var gem_mat=material("78b8ac",0.18)
  gem_mat.emission_enabled=true;gem_mat.emission=Color("2a655d");gem_mat.emission_energy_multiplier=0.5
  var crystal=SurfaceTool.new();crystal.begin(Mesh.PRIMITIVE_TRIANGLES)
  var equator=[Vector3(-0.075,0,0.94),Vector3(0,-0.060,0.94),Vector3(0.075,0,0.94),Vector3(0,0.060,0.94)]
  for i in 4:
   var a=equator[i];var b=equator[(i+1)%4]
   Shapes.triangle(crystal,a,b,Vector3(0,0,1.10))
   Shapes.triangle(crystal,b,a,Vector3(0,0,0.79))
  Shapes.mesh_node(root,crystal,gem_mat,"FacetedStaffCrystal")
  for z in [-0.88,-0.12,0.15,0.62]:
   var points=[]
   for i in 17:points.append(Vector3(cos(TAU*i/16)*0.044,sin(TAU*i/16)*0.044,z))
   Shapes.tube(root,points,0.012,gold,"StaffCollar",6)
  Shapes.tube(root,[Vector3(0,0,-1.29),Vector3(0,0,-1.17)],0.044,dark,"StaffFerrule",8)

static func apply(pawn: Node3D,profile: Dictionary):
 var model=pawn.get_node_or_null("Body")
 if model==null:return
 var key=signature(profile)
 if pawn.get_meta("equipment_signature","")==key:return
 var skeleton=model.find_child("Skeleton3D",true,false) as Skeleton3D
 if skeleton==null:return
 # Remove immediately from the skeleton so lookups and replacement never see old gear.
 for child in skeleton.get_children():
  if child.name in ["EquippedMainhand","EquippedOffhand","EquippedArmor"] or child.get_meta("equipment_armor",false):
   skeleton.remove_child(child);child.queue_free()
 for mesh in model.find_children("*","MeshInstance3D",true,false):
  if str(mesh.name) in ["Warrior_Sword","Rogue_Dagger","Ranger_Bow","Cleric_Staff"]:mesh.visible=false
  if str(mesh.name) in ["ShoulderPad_L","ShoulderPad_R","ShoulderPads","ArmGuard_L","ArmGuard_R","Guard"]:mesh.visible=profile.get("armor","")==""
 var weapon_id=profile.get("mainhand","")
 var weapon=Jobs.ITEMS.get(weapon_id,{}).get("kind",weapon_id)
 if WEAPONS.has(weapon) or weapon=="crossbow":
  var attachment=mount(skeleton,"EquippedMainhand","Weapon.R")
  attachment.set_meta("item_id",weapon_id)
  if WEAPONS.has(weapon):
   crafted_weapon(attachment,weapon)
  else:crossbow(skeleton,attachment)
 var offhand=profile.get("offhand","")
 if Jobs.ITEMS.get(offhand,{}).get("kind",offhand)=="shield":
  shield(skeleton)
  skeleton.get_node("EquippedOffhand").set_meta("item_id",offhand)
 var armor_id=profile.get("armor","")
 var armor_kind=Jobs.ITEMS.get(armor_id,{}).get("kind",armor_id)
 if armor_kind in ["leather","plate"]:
  armor(skeleton,armor_kind)
  skeleton.get_node("EquippedArmor").set_meta("item_id",armor_id)
 for attachment in skeleton.get_children():
  var id=attachment.get_meta("item_id",armor_id if attachment.get_meta("equipment_armor",false) else "")
  if Jobs.ITEMS.get(id,{}).get("mods",{}).is_empty():continue
  var tint=Color("89b9ac") if Jobs.ITEMS[id].slot=="mainhand" else Color("b1a0c7")
  for mesh in attachment.find_children("*","MeshInstance3D",true,false):
   if mesh.material_override is StandardMaterial3D:
    var variant=mesh.material_override.duplicate()
    variant.albedo_color=variant.albedo_color.lerp(tint,0.32)
    mesh.material_override=variant
 pawn.set_meta("equipment_signature",key)
 pawn.set_meta("equipped_weapon",weapon)
 pawn.set_meta("equipment_managed",true)

static func add_animations(model: Node3D):
 var player=model.find_child("AnimationPlayer",true,false) as AnimationPlayer
 if player==null or player.has_animation_library("Equipment"):return
 var skeleton=model.find_child("Skeleton3D",true,false) as Skeleton3D
 var library=AnimationLibrary.new()
 var sources={"Warrior":["Sword_Attack","Sword_Attack2","Idle_Weapon"],"Rogue":["Dagger_Attack","Dagger_Attack2","Attacking_Idle"],"Ranger":["Bow_Draw","Bow_Shoot","Idle_Weapon"],"Cleric":["Staff_Attack","Spell1","Idle_Weapon"]}
 for donor_name in sources:
  if not animation_resources.has(donor_name):
   var donor=load("res://assets/characters/quaternius/%s.gltf"%donor_name).instantiate()
   var donor_player=donor.find_child("AnimationPlayer",true,false)
   var clips={}
   for clip in sources[donor_name]:clips[clip]=donor_player.get_animation(clip)
   animation_resources[donor_name]=clips
   donor.free()
  for clip in sources[donor_name]:
   var animation=animation_resources[donor_name][clip].duplicate()
   for i in range(animation.get_track_count()-1,-1,-1):
    var path=animation.track_get_path(i)
    if path.get_subname_count()==0:animation.remove_track(i);continue
    var bone=path.get_subname(0)
    if bone=="Head" and skeleton.find_bone(bone)<0:bone="Head_2"
    if skeleton.find_bone(bone)<0:animation.remove_track(i);continue
    animation.track_set_path(i,NodePath(str(player.get_node(player.root_node).get_path_to(skeleton))+":"+bone))
   var name=clip
   if clip=="Idle_Weapon" and donor_name=="Ranger":name="Bow_Idle"
   if clip=="Idle_Weapon" and donor_name=="Cleric":name="Staff_Idle"
   if clip=="Attacking_Idle":name="Dagger_Idle"
   library.add_animation(name,animation)
   if clip=="Bow_Shoot":
    var crossbow_clip=animation.duplicate()
    # Keep a distinct crossbow action while reusing the compatible ranged release.
    library.add_animation("Crossbow_Shoot",crossbow_clip)
 player.add_animation_library("Equipment",library)
