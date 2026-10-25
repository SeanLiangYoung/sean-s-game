extends SceneTree
var checks=0
var failures=0
func check(ok: bool,label: String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label)
func _initialize():call_deferred("run")
func run():
 var scene=load("res://game/main.tscn").instantiate();root.add_child(scene);await process_frame
 scene.set_process(false)
 scene.campaign=preload("res://game/campaign.gd").new("user://village-ui-test.json")
 scene.selecting_expedition=true
 scene.enter_campaign()
 check(not scene.selecting_expedition,"entering campaign resets old map-selection state")
 check(scene.has_method("show_village_home"),"village interaction integrated")
 if not scene.has_method("show_village_home"):scene.queue_free();await process_frame;finish();return
 check(scene.scene_root.has_node("Village"),"native village geometry")
 check(is_instance_valid(scene.world_party),"player is present in village and accepts equipment appearance updates")
 check(scene.atlas.village_mode and not scene.atlas.route_mode,"camp presents village")
 check(scene.atlas.find_child("VillageActions",true,false)!=null,"camp controls")
 scene.show_village_home("memory");check(is_instance_valid(scene.modal),"dead resident home accessible")
 check("home_memory" in scene.campaign.story_state.seen,"exploration records testimony")
 scene.show_village_journal();check(is_instance_valid(scene.modal),"journal opens")
 var entries=scene.modal.find_children("*","Button",true,false).filter(func(b):return "主人不在" in b.text)
 check(entries.size()==1,"journal gives discoveries visible titles")
 if entries.size()==1:
  entries[0].pressed.emit();check(is_instance_valid(scene.detail_overlay),"journal title opens original fragment");scene.close_details()
 scene.close_modal();scene.depart();check(not scene.atlas.village_mode and scene.selecting_expedition,"world map preserved")
 scene.selecting_expedition=false;scene.refresh_ui();check(scene.atlas.village_mode,"return to village")
 scene.campaign.roster[1].hp=0;scene.draw_world();scene.refresh_ui()
 check(scene.scene_root.get_node("Village").has_node("Home_blade"),"dead companion house retained")
 scene.show_village_home("blade");check(is_instance_valid(scene.modal),"dead companion readable")
 scene.close_modal();scene.campaign.expedition=1
 check(scene.campaign.repair_home("memory"),"repair available after journey")
 scene.draw_world();check(scene.scene_root.get_node("Village/Home_memory").has_node("Repair"),"repair reflected visually")
 scene.campaign.start_region("border");scene.refresh_ui();check(scene.atlas.route_mode,"route map still works")
 scene.show_village_home("medic");check(not is_instance_valid(scene.modal),"house cannot interrupt expedition")
 scene.queue_free();await process_frame
 for suffix in ["",".relics",".achievements"]:DirAccess.remove_absolute("user://village-ui-test.json"+suffix)
 finish()
func finish():
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
