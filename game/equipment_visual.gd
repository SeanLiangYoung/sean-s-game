extends RefCounted
# Gear uses the same scene builder for live pawns and portrait renders.
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
 var result={"mesh":mesh.mesh,"transform":mesh.transform}
 weapon_resources[id]=result
 donor.free()
 return result

static func armor_piece(skeleton: Skeleton3D,root_attachment: BoneAttachment3D,bone: String,name: String) -> Node3D:
 # Children remain under their own bones, marked for replacement along with the torso.
 var attachment=root_attachment if bone=="Torso" else mount(skeleton,name,bone)
 if attachment==null:return null
 attachment.set_meta("equipment_armor",true)
 return rest_space(skeleton,attachment)

static func armor(skeleton: Skeleton3D,id: String):
 var root=mount(skeleton,"EquippedArmor","Torso")
 if root==null:return
 root.set_meta("item_id",id)
 var torso=armor_piece(skeleton,root,"Torso","")
 var plate=id=="plate"
 var base=material("899eaa",0.65) if plate else material("79563c")
 var edge=material("d3be8a",0.55) if plate else material("c19b65")
 var dark=material("3c505b",0.35) if plate else material("43352c")
 # Layered fitted cuirass, raised trim and waist plates. Underclothes stay on the body.
 ellipsoid(torso,Vector3(0,1.55,0.04),Vector3(0.92,0.72,0.76),base)
 block(torso,Vector3(0,1.54,0.40),Vector3(0.72,0.43,0.10),base,"Breastplate" if plate else "LeatherVest")
 block(torso,Vector3(0,1.30,0.31),Vector3(0.79,0.09,0.14),edge)
 block(torso,Vector3(0,1.70,0.42),Vector3(0.12,0.20,0.06),edge)
 if plate:
  for y in [1.38,1.48,1.58]:block(torso,Vector3(0,y,0.455),Vector3(0.68,0.025,0.035),dark)
 else:
  for side in [-1,1]:
   var strap=block(torso,Vector3(side*0.27,1.63,0.43),Vector3(0.085,0.49,0.055),edge)
   strap.rotation.z=side*0.16
 for side in [-1,1]:
  var suffix="L" if side==1 else "R"
  var shoulder=armor_piece(skeleton,root,"UpperArm."+suffix,"EquipmentShoulder"+suffix)
  if shoulder!=null:
   ellipsoid(shoulder,Vector3(side*0.53,1.83,0.01),Vector3(0.54 if plate else 0.38,0.27,0.61 if plate else 0.45),base)
   if plate:block(shoulder,Vector3(side*0.54,1.82,0.32),Vector3(0.43,0.07,0.06),edge)
  if not plate:continue
  var arm=armor_piece(skeleton,root,"LowerArm."+suffix,"EquipmentBracer"+suffix)
  if arm!=null:
   var rest=skeleton.get_bone_global_rest(skeleton.find_bone("LowerArm."+suffix)).origin
   ellipsoid(arm,rest+Vector3(0,-0.22,0.06),Vector3(0.29,0.36,0.32),base)
  var leg=armor_piece(skeleton,root,"LowerLeg."+suffix,"EquipmentGreave"+suffix)
  if leg!=null:
   block(leg,Vector3(side*0.205,0.36,0.20),Vector3(0.24,0.40,0.13),base)
   block(leg,Vector3(side*0.205,0.57,0.21),Vector3(0.27,0.11,0.15),edge)

static func shield(skeleton: Skeleton3D):
 var attachment=mount(skeleton,"EquippedOffhand","LowerArm.L")
 if attachment==null:return
 attachment.set_meta("item_id","shield")
 var root=rest_space(skeleton,attachment)
 var center=skeleton.get_bone_global_rest(skeleton.find_bone("LowerArm.L")).origin+Vector3(0.13,-0.24,0.25)
 var rim=CylinderMesh.new();rim.top_radius=0.43;rim.bottom_radius=0.43;rim.height=0.12;rim.radial_segments=10
 var outline=part(root,rim,center,material("b8ab86",0.55),"ShieldRim");outline.rotation.x=PI/2;outline.scale.z=1.18
 var face=CylinderMesh.new();face.top_radius=0.37;face.bottom_radius=0.37;face.height=0.135;face.radial_segments=10
 var wood=part(root,face,center+Vector3(0,0,0.02),material("87613d"),"WoodShield");wood.rotation.x=PI/2;wood.scale.z=1.18
 for x in [-0.20,0.0,0.20]:block(root,center+Vector3(x,0,0.095),Vector3(0.018,0.68 if x==0 else 0.55,0.022),material("493c2e"))
 ellipsoid(root,center+Vector3(0,0,0.14),Vector3(0.21,0.21,0.14),material("a0aab0",0.65))

static func crossbow(skeleton: Skeleton3D,attachment: BoneAttachment3D):
 var root=rest_space(skeleton,attachment)
 var hand=skeleton.get_bone_global_rest(skeleton.find_bone("Weapon.R")).origin
 var wood=material("6e4c32");var metal=material("8a9d9d",0.6);var string_mat=material("d9c99f")
 var center=hand+Vector3(0,0.03,0.21)
 block(root,center,Vector3(0.14,0.13,0.78),wood,"CrossbowStock")
 block(root,center+Vector3(0,0.015,0.25),Vector3(0.83,0.09,0.10),metal,"CrossbowLimbs")
 block(root,center+Vector3(0,0.10,0.01),Vector3(0.025,0.025,0.65),metal,"CrossbowBolt")
 for side in [-1,1]:
  var line=block(root,center+Vector3(side*0.20,0.075,0.10),Vector3(0.48,0.018,0.018),string_mat)
  line.rotation.y=side*0.63
 block(root,hand+Vector3(0,-0.10,0.05),Vector3(0.09,0.24,0.10),wood)

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
 var weapon=profile.get("mainhand","")
 if WEAPONS.has(weapon) or weapon=="crossbow":
  var attachment=mount(skeleton,"EquippedMainhand","Weapon.R")
  attachment.set_meta("item_id",weapon)
  if WEAPONS.has(weapon):
   var data=weapon_resource(weapon)
   var mesh=MeshInstance3D.new();mesh.name="EquippedWeaponMesh";mesh.mesh=data.mesh;mesh.transform=data.transform
   attachment.add_child(mesh)
  else:crossbow(skeleton,attachment)
 if profile.get("offhand","")=="shield":shield(skeleton)
 if profile.get("armor","") in ["leather","plate"]:armor(skeleton,profile.armor)
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
