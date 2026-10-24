extends SceneTree
const Campaign=preload("res://game/campaign.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
 var scene=load("res://game/main.tscn").instantiate()
 root.add_child(scene);await process_frame
 scene.set_process(false);scene.close_modal()
 scene.campaign=Campaign.new("user://appearance-ui-test.json")
 scene.enter_campaign()
 var c=scene.campaign
 check(scene.portraits.has_method("profile_signature"),"portraits cache by equipment profile")
 if not scene.portraits.has_method("profile_signature"):
  scene.queue_free();await process_frame
  print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1);return
 var initial_viewports=scene.portraits.get_child_count()
 var profile=c.visual_profile("hero")
 var before=scene.portraits.portrait("hero",profile)
 check(scene.portraits.portrait("hero",profile)==before,"unchanged portrait reused")
 c.equip_item(0,"hero")
 var changed=scene.portraits.portrait("hero",c.visual_profile("hero"))
 check(changed!=before,"weapon changes portrait texture")
 for item in [1,2,3,4,0]:
  c.equip_item(item,"hero")
  scene.portraits.portrait("hero",c.visual_profile("hero"))
  await process_frame
 check(scene.portraits.get_child_count()<=initial_viewports+1,"obsolete portrait viewports released")
 scene.draw_world()
 c.equip_item(2,"hero");scene.refresh_ui()
 var world_player=scene.world_party.find_child("AnimationPlayer",true,false)
 check(world_player.current_animation=="Equipment/Bow_Idle","stationary world pawn changes holding pose when equipped")
 c.unequip_item("hero");scene.refresh_ui()
 check(world_player.current_animation=="Idle","unequip restores stationary world idle")
 c.equip_item(0,"hero");scene.refresh_ui()
 scene.show_party_menu("装备","hero")
 var hero_texture=scene.portraits.textures.hero
 c.equip_item(0,"medic")
 scene.refresh_ui();scene.show_party_menu("装备","medic")
 check(scene.portraits.textures.hero!=hero_texture,"transfer invalidates previous owner portrait")
 c.equip_item(5,"hero");c.equip_item(7,"hero")
 scene.close_modal();c.depart();scene.selected_ids=["hero","medic"];scene.begin_battle(0)
 var hero_pawn=scene.pawn_nodes.filter(func(p):return p.name=="Character_hero")[0]
 var medic_pawn=scene.pawn_nodes.filter(func(p):return p.name=="Character_medic")[0]
 check(hero_pawn.find_child("EquippedMainhand",true,false)==null,"battle hero no transferred weapon")
 check(hero_pawn.find_child("EquippedOffhand",true,false)!=null and hero_pawn.find_child("EquippedArmor",true,false)!=null,"battle receives shield and armor")
 check(medic_pawn.get_meta("equipped_weapon","")=="sword","battle medic receives sword")
 var restored=Campaign.new()
 check(restored.load_data(c.snapshot) and restored.visual_profile("medic").mainhand=="sword","reload derives matching visual gear")
 scene.queue_free();await process_frame
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
