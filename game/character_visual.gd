extends RefCounted
# CC0 Quaternius RPG characters; original sources and license in THIRD_PARTY_ASSETS.md.
const Equipment=preload("res://game/equipment_visual.gd")
const MODELS={"hero":"Warrior","blade":"Rogue","ranger":"Ranger","medic":"Cleric","engineer":"Ranger","warden":"Warrior","enemy2":"Ranger"}
const ACTIONS={"idle":"Idle","move":"Walk","hit":"RecieveHit","death":"Death","rest_hp":"PickUp","rest_mp":"PickUp"}
static func create(parent: Node3D,kind: String,profile: Dictionary={}) -> Node3D:
 if not profile.is_empty():kind=profile.get("appearance",kind)
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
 if not profile.is_empty():
  Equipment.add_animations(model)
  apply_loadout(parent,profile)
 play(parent,"idle")
 return model

static func apply_loadout(pawn: Node3D,profile: Dictionary):
 if pawn.get_meta("equipment_signature","")==Equipment.signature(profile):return
 var model=pawn.get_node_or_null("Body")
 if model==null:return
 Equipment.add_animations(model)
 Equipment.apply(pawn,profile)
 var previous_action=pawn.get_meta("visual_action","")
 if previous_action in ["idle","move"]:play(pawn,previous_action)

static func effect_style(pawn: Node3D,action: String) -> String:
 var role=pawn.get_meta("role","")
 if action.begins_with("rest"):return "mana" if action=="rest_mp" else "heal"
 if action=="skill" and role=="medic":return "heal"
 if pawn.get_meta("equipment_managed",false):
  var weapon=pawn.get_meta("equipped_weapon","")
  if weapon in ["bow","crossbow"]:return "arrow"
  if weapon=="staff":return "magic"
  return "slash"
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
 if pawn.get_meta("equipment_managed",false):
  var weapon=pawn.get_meta("equipped_weapon","")
  if action=="idle":
   var idles={"sword":"Idle_Weapon","dagger":"Dagger_Idle","bow":"Bow_Idle","staff":"Staff_Idle"}
   if idles.has(weapon):clip="Equipment/"+idles[weapon]
  if action in ["attack","skill"]:
   var clips={"sword":"Sword_Attack2" if action=="skill" else "Sword_Attack","dagger":"Dagger_Attack2" if action=="skill" else "Dagger_Attack","bow":"Bow_Shoot","crossbow":"Crossbow_Shoot","staff":"Staff_Attack"}
   clip="Equipment/"+clips[weapon] if clips.has(weapon) else "Punch"
  if action=="prepare_skill":clip="Equipment/Bow_Draw" if weapon=="bow" else ("Equipment/Spell1" if weapon=="staff" else "Equipment/Idle_Weapon")
 if action.begins_with("rest") and archetype=="Cleric":clip="Spell1"
 if not player.has_animation(clip):return
 pawn.set_meta("visual_action",action)
 var animation=player.get_animation(clip)
 animation.loop_mode=Animation.LOOP_LINEAR if action in ["idle","move"] else Animation.LOOP_NONE
 # Rest uses a kneeling/recovery gesture; the timeline adds a sustained posture and particles.
 var speed=1.0
 if action=="skill":speed=1.15
 if action=="prepare_skill" and archetype=="Cleric":speed=0.55
 if action=="prepare_skill" and archetype=="Ranger":speed=2.0
 player.play(clip,0.10,speed)
 player.advance(0)
