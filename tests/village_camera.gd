extends SceneTree
var checks=0
var failures=0
func check(ok: bool,label: String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label)
func _initialize():call_deferred("run")
func run():
 var s=load("res://game/main.tscn").instantiate();root.add_child(s);await process_frame;s.set_process(false)
 check(s.has_method("show_village_overview"),"preset camera integrated")
 if not s.has_method("show_village_overview"):s.queue_free();await process_frame;finish();return
 s.campaign=load("res://game/campaign.gd").new("user://village-camera-test.json");s.enter_campaign()
 var daily=s.camera.size
 check(daily<=20,"daily village significantly closer than old 28")
 for id in s.Campaign.VillageStory.HOMES:
  s.show_village_home(id)
  s.village_camera.finish(s)
  check(s.camera.size<=10,"house detail closeup "+id)
  var door=s.Campaign.VillageStory.HOMES[id].pos+Vector3(0,1,1.6)
  var projected=s.camera.unproject_position(door);var viewport=s.get_viewport().get_visible_rect().size
  check(projected.x>viewport.x*0.08 and projected.x<viewport.x*0.59 and projected.y>viewport.y*0.2 and projected.y<viewport.y*0.8,"door remains visible beside dialogue "+id)
  check(not s.atlas.visible,"village UI hidden for closeup "+id)
  s.close_modal();s.village_camera.finish(s)
  check(is_equal_approx(s.camera.size,daily) and s.atlas.visible,"return restores daily view "+id)
 s.show_village_overview();s.village_camera.finish(s)
 check(s.camera.size>=27,"overview available on demand")
 s.depart();s.selecting_expedition=false;s.refresh_ui()
 check(is_equal_approx(s.camera.size,daily),"map cancel restores daily composition after overview")
 s.show_village_overview();s.village_camera.finish(s)
 s.show_village_overview();s.village_camera.finish(s)
 check(is_equal_approx(s.camera.size,daily),"overview toggles back")
 s.show_village_home("memory");s.show_village_home("medic");s.village_camera.finish(s)
 check(s.village_camera.view=="medic","rapid focus cancels earlier transition")
 s.campaign.expedition=1
 check(s.campaign.repair_home("medic"),"repair fixture")
 s.draw_world();s.refresh_ui();s.show_village_home("medic");s.village_camera.finish(s)
 check(s.village_camera.view=="medic" and s.camera.size<10 and not s.atlas.visible,"repair rebuild retains closeup")
 s.show_village_journal();s.village_camera.finish(s)
 check(s.village_camera.view=="daily","changing page clears closeup")
 s.close_modal();s.village_camera.finish(s)
 root.size=Vector2i(1920,800);await process_frame;await process_frame
 var d=s.Campaign.VillageStory.HOMES.memory
 var projected=s.camera.unproject_position(d.pos+Vector3(0,1.1,1.8))
 check(s.atlas.find_child("Door_memory",true,false).position.is_equal_approx(projected-Vector2(17,15)),"resizing reprojects doorway without manual refresh")
 s.show_village_home("memory");s.close_modal();s.campaign.start_region("border")
  # No route battle selected yet; use the existing scene battle path through the first battle node.
 var n=s.campaign.route.nodes.filter(func(node):return node.depth==0 and node.kind=="battle")[0]
 s.campaign.enter_route(n.id);s.selected_ids=["hero","blade"];s.begin_battle(n.encounter)
 var before=s.camera.transform;var size=s.camera.size
 await create_timer(0.9).timeout
 check(s.camera.transform.is_equal_approx(before) and is_equal_approx(s.camera.size,size),"village transition cannot change battle camera")
 s.queue_free();await process_frame
 for suffix in ["",".relics",".achievements"]:DirAccess.remove_absolute("user://village-camera-test.json"+suffix)
 finish()
func finish():
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
