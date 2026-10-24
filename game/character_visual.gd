extends RefCounted
# CC0 Quaternius RPG characters; original sources and license in THIRD_PARTY_ASSETS.md.
const MODELS={"hero":"Warrior","blade":"Rogue","ranger":"Ranger","medic":"Cleric","engineer":"Ranger","warden":"Warrior","enemy2":"Ranger"}
const ACTIONS={"idle":"Idle","move":"Walk","hit":"RecieveHit","death":"Death","rest_hp":"PickUp","rest_mp":"PickUp"}
static func create(parent: Node3D,kind: String) -> Node3D:
 if kind.begins_with("hire_"):kind="ranger" if kind.ends_with("_0") else "medic"
 var model_name=MODELS.get(kind,"Rogue" if kind.ends_with("1") else "Warrior")
 var model=load("res://assets/characters/quaternius/%s.gltf"%model_name).instantiate()
 model.name="Body"
 model.scale=Vector3.ONE*0.54
 model.rotation.y=PI if kind.begins_with("enemy") else 0.0
 parent.add_child(model)
 parent.set_meta("role",kind)
 parent.set_meta("asset_pack","quaternius_rpg")
 parent.set_meta("archetype",model_name)
 parent.set_meta("forward_offset",0.0)
 for node in model.find_children("*","MeshInstance3D",true,false):
  if model_name=="Cleric" and node.name=="Head":node.visible=false
  for i in range(node.mesh.get_surface_count()):
   var material=node.mesh.surface_get_material(i)
   if material is StandardMaterial3D:
    var local=ShaderMaterial.new()
    local.shader=preload("res://game/shaders/character.gdshader")
    local.set_shader_parameter("source_texture",material.albedo_texture)
    local.set_shader_parameter("has_texture",material.albedo_texture!=null)
    local.set_shader_parameter("base_color",material.albedo_color)
    var tint=Color("dbc4b5") if kind.begins_with("enemy") else Color.WHITE
    local.set_shader_parameter("tint",tint)
    node.set_surface_override_material(i,local)
 preload("res://game/character_wardrobe.gd").attach(model,kind)
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
 if action=="prepare_skill":
  clip="Bow_Draw" if archetype=="Ranger" else ("Spell1" if archetype=="Cleric" else "Idle_Weapon")
  if not player.has_animation(clip):clip="Attacking_Idle"
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
 if action=="prepare_skill" and archetype=="Cleric":speed=0.55
 if action=="prepare_skill" and archetype=="Ranger":speed=2.0
 player.play(clip,0.10,speed)
 player.advance(0)
