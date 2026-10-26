extends SceneTree
var checks=0
var failures=0
var scene
func check(ok: bool,label: String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label)
func _initialize():call_deferred("run")
func settle():
 if scene.village_camera.tween!=null and scene.village_camera.tween.is_valid() and scene.village_camera.tween.is_running():await scene.village_camera.tween.finished
 for i in range(5):await process_frame
func capture(name):
 await settle();await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/village-camera-"+name+".png")
func run():
 root.size=Vector2i(1280,800)
 scene=load("res://game/main.tscn").instantiate();root.add_child(scene);await process_frame;scene.set_process(false)
 scene.campaign=load("res://game/campaign.gd").new("user://village-camera-render.json");scene.enter_campaign()
 await settle()
 var daily_height=projected_height("memory")
 for id in scene.Campaign.VillageStory.HOMES:
  var door=scene.atlas.find_child("Door_"+id,true,false)
  check(door.visible,"daily doorway reachable "+id)
  var title=door.get_node("DoorTitle")
  check(not title.visible,"house label discreet by default "+id)
  door.mouse_entered.emit();check(title.visible,"hover reveals house name "+id);door.mouse_exited.emit()
 await capture("daily")
 scene.show_village_overview();await settle()
 check(daily_height>projected_height("memory")*1.35,"daily houses materially larger than overview")
 await capture("overview")
 scene.show_village_overview();await settle()
 for id in scene.Campaign.VillageStory.HOMES:
  scene.show_village_home(id);await settle()
  var p=scene.Campaign.VillageStory.HOMES[id].pos
  var foot=scene.camera.unproject_position(p+Vector3(0,0.15,1.5))
  var peak=scene.camera.unproject_position(p+Vector3(0,3.6,0))
  var panel=scene.modal.get_global_rect()
  check(foot.x<panel.position.x-35 and peak.x<panel.position.x-35,"house is clear of dialogue "+id)
  check(peak.y>30 and foot.y<scene.get_viewport().get_visible_rect().end.y-30,"roof and doorstep fit closeup "+id)
  check(panel.end.x<=scene.get_viewport().get_visible_rect().end.x,"dialogue panel inside screen "+id)
  var back=find_button(scene.modal,"走回村中")
  check(back!=null and scene.get_viewport().get_visible_rect().encloses(back.get_global_rect()),"return remains reachable "+id)
  await capture(id)
  scene.close_modal();await settle()
 root.size=Vector2i(1024,640);await process_frame;scene.refresh_ui();await settle()
 check(scene.get_viewport().get_visible_rect().encloses(scene.atlas.find_child("VillageActions",true,false).get_global_rect()),"small-screen dock fits")
 await capture("small")
 scene.show_village_home("memory");await settle();await capture("memory-small")
 check(scene.get_viewport().get_visible_rect().encloses(scene.modal.get_global_rect()),"small-screen dialogue fits")
 scene.close_modal();await settle()
 root.size=Vector2i(1920,1080);await process_frame;scene.refresh_ui();await settle()
 scene.show_village_home("engineer");await settle();await capture("wide")
 check(scene.get_viewport().get_visible_rect().encloses(scene.modal.get_global_rect()),"wide-screen dialogue fits")
 scene.queue_free();await process_frame
 for suffix in ["",".relics",".achievements"]:DirAccess.remove_absolute("user://village-camera-render.json"+suffix)
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
func projected_height(id):
 var p=scene.Campaign.VillageStory.HOMES[id].pos
 return scene.camera.unproject_position(p).y-scene.camera.unproject_position(p+Vector3(0,3.5,0)).y
func find_button(node,needle):
 if node is Button and needle in node.text:return node
 for child in node.get_children():
  var b=find_button(child,needle)
  if b!=null:return b
 return null
