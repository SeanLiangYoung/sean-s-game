extends RefCounted
# CC0 KayKit characters; see THIRD_PARTY_ASSETS.md for provenance.
const MODELS={"hero":"Knight","blade":"Barbarian","ranger":"Rogue","medic":"Mage","engineer":"Rogue","warden":"Knight","enemy2":"Rogue"}
const ACTIONS={"idle":"Idle","move":"Walking_A","attack":"1H_Melee_Attack_Chop","skill":"Spellcast_Shoot","hit":"Hit_A","death":"Death_A","rest_hp":"Sit_Floor_Down","rest_mp":"Spellcast_Raise"}
static func create(parent: Node3D,kind: String) -> Node3D:
 var model_name=MODELS.get(kind,"Barbarian" if kind.ends_with("1") else "Knight")
 var model=load("res://assets/characters/kaykit/%s.glb"%model_name).instantiate()
 model.name="Body"
 model.scale=Vector3.ONE*0.63
 model.rotation.y=PI if kind.begins_with("enemy") else 0.0
 parent.add_child(model)
 parent.set_meta("role",kind)
 var keep=[]
 match model_name:
  "Knight":keep=["1H_Sword","Rectangle_Shield" if kind=="warden" else "Round_Shield","Knight_Helmet","Knight_Cape"]
  "Barbarian":keep=["1H_Axe","Barbarian_Round_Shield"]
  "Rogue":keep=["2H_Crossbow"]
  "Mage":keep=["2H_Staff"]
 for node in model.find_children("*","MeshInstance3D",true,false):
  if node.get_parent() is BoneAttachment3D:node.visible=node.name in keep
  # Smooth normal shading keeps large curved parts from reading as stone facets.
  for i in range(node.mesh.get_surface_count()):
   var material=node.mesh.surface_get_material(i)
   if material is StandardMaterial3D:
    var local=material.duplicate()
    local.roughness=0.85
    if kind.begins_with("enemy"):local.albedo_color=Color("a47d79")
    elif kind=="hero":local.albedo_color=Color("fff0c9")
    local.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    node.set_surface_override_material(i,local)
 play(parent,"idle")
 return model

static func play(pawn: Node3D,action: String):
 if not is_instance_valid(pawn):return
 var player=pawn.find_child("AnimationPlayer",true,false) as AnimationPlayer
 if player==null:return
 var role=pawn.get_meta("role","")
 var clip=ACTIONS.get(action,"Idle")
 if action=="attack" and role in ["ranger","engineer","enemy2"]:clip="2H_Ranged_Shoot"
 if action=="attack" and role=="medic":clip="Spellcast_Shoot"
 if not player.has_animation(clip):return
 # Imported Animation resources are shared; configure once, identically for all instances.
 var animation=player.get_animation(clip)
 animation.loop_mode=Animation.LOOP_LINEAR if action in ["idle","move"] else Animation.LOOP_NONE
 player.play(clip,0.10,1.35 if action=="rest_mp" else 1.0)
 player.advance(0)
