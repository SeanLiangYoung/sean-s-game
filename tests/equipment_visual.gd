extends SceneTree
const Campaign=preload("res://game/campaign.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
 var c=Campaign.new("user://equipment-visual-tests.json")
 check(c.has_method("visual_profile"),"campaign provides visual equipment profile")
 if not c.has_method("visual_profile"):
  print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1);return
 var visual=load("res://game/character_visual.gd")
 check(c.visual_profile("hero")=={"appearance":"hero","mainhand":"","offhand":"","armor":""},"empty loadout explicit")
 c.equip_item(0,"hero");c.equip_item(5,"hero");c.equip_item(7,"hero")
 check(c.visual_profile("hero").mainhand=="sword" and c.visual_profile("hero").armor=="plate","profile follows inventory")
 c.equip_item(0,"medic")
 check(c.visual_profile("hero").mainhand=="" and c.visual_profile("medic").mainhand=="sword","transfer updates both owners")
 for character in ["hero","blade","ranger","medic","engineer","warden"]:
  for weapon in ["sword","dagger","bow","staff","crossbow",""]:
   var pawn=Node3D.new();root.add_child(pawn)
   var profile={"appearance":character,"mainhand":weapon,"offhand":"shield","armor":"plate"}
   visual.create(pawn,character,profile)
   var skeleton=pawn.find_child("Skeleton3D",true,false)
   var main=pawn.find_child("EquippedMainhand",true,false)
   check((main!=null)==(weapon!=""),"only equipped mainhand exists "+character+weapon)
   if main!=null:check(main is BoneAttachment3D and main.bone_name=="Weapon.R","weapon follows weapon bone")
   check(pawn.find_child("EquippedOffhand",true,false)!=null,"shield equipped "+character)
   check(pawn.find_child("EquippedArmor",true,false)!=null,"armor equipped "+character)
   for mesh in pawn.find_children("*","MeshInstance3D",true,false):
    if mesh.name in ["Warrior_Sword","Rogue_Dagger","Ranger_Bow","Cleric_Staff"]:check(not mesh.visible,"original weapon hidden")
   if weapon in ["bow","staff"]:
    visual.play(pawn,"idle")
    var idle_player=pawn.find_child("AnimationPlayer",true,false)
    check(idle_player.current_animation==("Equipment/Bow_Idle" if weapon=="bow" else "Equipment/Staff_Idle"),"equipped idle presents weapon rather than pointing into camera")
   visual.play(pawn,"attack")
   var player=pawn.find_child("AnimationPlayer",true,false)
   var expected={"sword":"Equipment/Sword_Attack","dagger":"Equipment/Dagger_Attack","bow":"Equipment/Bow_Shoot","staff":"Equipment/Staff_Attack","crossbow":"Equipment/Crossbow_Shoot","":"Punch"}[weapon]
   check(player.current_animation==expected,"attack follows equipped weapon "+character+weapon)
   check(visual.effect_style(pawn,"attack")==("arrow" if weapon in ["bow","crossbow"] else ("magic" if weapon=="staff" else "slash")),"effect follows weapon")
   visual.apply_loadout(pawn,{"appearance":character,"mainhand":"","offhand":"","armor":""})
   check(pawn.find_child("EquippedArmor",true,false)==null and pawn.find_child("EquippedOffhand",true,false)==null,"unequip removes attachments")
   pawn.queue_free();await process_frame
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
