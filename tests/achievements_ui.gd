extends SceneTree
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func texts(node):
 var result=""
 if node is Label or node is Button:result+=node.text+"\n"
 for child in node.get_children():result+=texts(child)
 return result
func _initialize():call_deferred("run")
func run():
 var scene=load("res://game/main.tscn").instantiate();root.add_child(scene);await process_frame
 scene.set_process(false)
 var path="user://achievement-ui-tests.json"
 for suffix in ["",".achievements"]:DirAccess.remove_absolute(path+suffix)
 scene.campaign=load("res://game/campaign.gd").new(path)
 check(scene.has_method("show_achievements"),"achievement page exists")
 if not scene.has_method("show_achievements"):
  scene.queue_free();await process_frame
  print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1);return
 scene.show_main_menu()
 check("成就" in texts(scene.modal),"main menu exposes achievements")
 scene.show_achievements(true)
 var content=texts(scene.modal)
 check("0 / 4" in content and "灰潮归来" in content and "绝境传说" in content,"page lists all four locked achievements")
 check("攻击 +0" in content and "护甲 +0" in content,"locked achievements grant no bonuses")
 scene.campaign.cleared_regions=["border","wood","waste","frost","marsh"]
 scene.show_achievements(false)
 check("5 / 6" in texts(scene.modal),"partial region progress is visible")
 scene.campaign.cleared_regions.append("ruins");scene.campaign.save_game()
 scene.show_achievements(false)
 content=texts(scene.modal)
 check("1 / 4" in content and "已解锁" in content and "攻击 +1" in content,"completed achievement shows bonus and status")
 scene.start_new_campaign("shen")
 check(scene.campaign.cleared_regions.is_empty() and scene.campaign.completed_difficulties==[0],"new game through UI keeps achievements")
 scene.show_pause_menu()
 check("成就" in texts(scene.modal),"pause menu exposes achievements")
 for suffix in ["",".achievements"]:DirAccess.remove_absolute(path+suffix)
 scene.queue_free();await process_frame
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
