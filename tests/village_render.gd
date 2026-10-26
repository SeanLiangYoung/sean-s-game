extends SceneTree
var checks=0
var failures=0
var scene
func check(ok: bool,label: String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label)
func _initialize():call_deferred("run")
func frames():
 if scene.village_camera.tween!=null and scene.village_camera.tween.is_valid() and scene.village_camera.tween.is_running():await scene.village_camera.tween.finished
 for i in range(5):await process_frame
func capture(name: String):
 await frames();await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/"+name+".png")
func run():
 root.size=Vector2i(1280,800)
 scene=load("res://game/main.tscn").instantiate();root.add_child(scene);await process_frame;scene.set_process(false)
 scene.campaign=load("res://game/campaign.gd").new("user://village-render-only.json")
 scene.enter_campaign();await frames()
 var rects=[]
 var bounds=scene.get_viewport().get_visible_rect()
 for entry in scene.atlas.get_children():
  if entry is Button and entry.name.begins_with("Door_"):
   var rect=entry.get_global_rect()
   check(bounds.encloses(rect),"house plaque inside viewport "+entry.name)
   for previous in rects:check(not previous.intersects(rect),"house plaques do not overlap")
   rects.append(rect)
 check(rects.size()==7,"all houses accessible")
 var actions=scene.atlas.find_child("VillageActions",true,false)
 check(bounds.encloses(actions.get_global_rect()),"primary village actions inside screen")
 await capture("village-overview")
 scene.show_village_home("memory");await capture("village-memory")
 scene.close_modal();scene.campaign.expedition=1;scene.campaign.repair_home("memory");scene.draw_world();scene.refresh_ui();await capture("village-repaired")
 scene.campaign.phase="world"
 scene.campaign.acquire_relic("hunt_1");scene.campaign.acquire_relic("hunt_6","ranger");scene.campaign.acquire_relic("ward_1")
 scene.show_relic_strategy();await capture("village-builds")
 scene.campaign.phase="reward";scene.campaign.choices=[]
 for id in ["hunt_2","ward_2","blood_6","silver","bow"]:
  scene.campaign.choices.append(scene.Campaign.REWARDS.filter(func(r):return r.id==id)[0].duplicate(true))
 scene.show_reward();await frames()
 var grid=scene.modal.find_child("RewardGrid",true,false)
 check(grid.get_global_rect().end.y<=bounds.end.y,"reward comparison fits screen")
 await capture("village-reward")
 scene.show_relic_binding("ward_6",2);await capture("village-binding")
 scene.close_modal();scene.campaign.phase="camp";scene.enter_campaign()
 root.size=Vector2i(1024,640);await frames();scene.refresh_ui();await frames()
 bounds=scene.get_viewport().get_visible_rect()
 check(bounds.encloses(scene.atlas.find_child("VillageActions",true,false).get_global_rect()),"small landscape actions inside screen")
 await capture("village-small")
 scene.show_village_home("medic");await capture("village-home-small")
 scene.queue_free();await process_frame
 for suffix in ["",".relics",".achievements"]:DirAccess.remove_absolute("user://village-render-only.json"+suffix)
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
