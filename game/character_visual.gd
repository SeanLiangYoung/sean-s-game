extends RefCounted
# CC0 Quaternius RPG characters; original sources and license in THIRD_PARTY_ASSETS.md.
const MODELS={"hero":"Warrior","blade":"Rogue","ranger":"Ranger","medic":"Cleric","engineer":"Ranger","warden":"Warrior","enemy2":"Ranger"}
const ACTIONS={"idle":"Idle","move":"Walk","hit":"RecieveHit","death":"Death","rest_hp":"PickUp","rest_mp":"PickUp"}
static func create(parent: Node3D,kind: String) -> Node3D:
 var model_name=MODELS.get(kind,"Rogue" if kind.ends_with("1") else "Warrior")
 var model=load("res://assets/characters/quaternius/%s.gltf"%model_name).instantiate()
 model.name="Body"
 model.scale=Vector3.ONE*0.54
 model.rotation.y=0.0 if kind.begins_with("enemy") else PI
 parent.add_child(model)
 parent.set_meta("role",kind)
 parent.set_meta("asset_pack","quaternius_rpg")
 parent.set_meta("archetype",model_name)
 parent.set_meta("forward_offset",PI)
 for node in model.find_children("*","MeshInstance3D",true,false):
  for i in range(node.mesh.get_surface_count()):
   var material=node.mesh.surface_get_material(i)
   if material is StandardMaterial3D:
    var local=material.duplicate()
    local.roughness=0.88
    local.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON
    local.rim_enabled=true
    local.rim=0.25
    local.rim_tint=0.5
    if kind.begins_with("enemy"):local.albedo_color=Color("b28b84")
    elif kind=="hero":local.albedo_color=Color("fff0d6")
    elif kind=="warden":local.albedo_color=Color("a6bccb")
    elif kind=="engineer":local.albedo_color=Color("c7ab83")
    local.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    local.albedo_color=local.albedo_color*1.18
    node.set_surface_override_material(i,local)
 play(parent,"idle")
 return model

static func effect_style(pawn: Node3D,action: String) -> String:
 var role=pawn.get_meta("role","")
 if action.begins_with("rest"):return "mana" if action=="rest_mp" else "heal"
 if action=="skill" and role=="medic":return "heal"
 if role in ["ranger","engineer","enemy2"]:return "arrow"
 if role=="medic":return "magic"
 return "slash"

static func play(pawn: Node3D,action: String):
 if not is_instance_valid(pawn):return
 var player=pawn.find_child("AnimationPlayer",true,false) as AnimationPlayer
 if player==null:return
 var archetype=pawn.get_meta("archetype","Warrior")
 var clip=ACTIONS.get(action,"Idle")
 if action in ["attack","skill"]:
  match archetype:
   "Warrior":clip="Sword_Attack2" if action=="skill" else "Sword_Attack"
   "Rogue":clip="Dagger_Attack2" if action=="skill" else "Dagger_Attack"
   "Ranger":clip="Bow_Shoot"
   "Cleric":clip="Spell1"
 if action.begins_with("rest") and archetype=="Cleric":clip="Spell1"
 if not player.has_animation(clip):return
 var animation=player.get_animation(clip)
 animation.loop_mode=Animation.LOOP_LINEAR if action in ["idle","move"] else Animation.LOOP_NONE
 # Rest uses a kneeling/recovery gesture; the timeline adds a sustained posture and particles.
 var speed=1.0
 if action=="skill":speed=1.15
 player.play(clip,0.10,speed)
 player.advance(0)
