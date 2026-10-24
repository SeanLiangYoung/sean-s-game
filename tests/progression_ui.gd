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
func button(node,needle):
 if node is Button and needle in node.text:return node
 for child in node.get_children():
  var found=button(child,needle)
  if found!=null:return found
 return null
func _initialize():call_deferred("run")
func run():
 var scene=load("res://game/main.tscn").instantiate();root.add_child(scene);await process_frame
 scene.set_process(false);scene.close_modal()
 scene.campaign=load("res://game/campaign.gd").new("user://progression-ui-test.json")
 scene.campaign.roster[1].xp=200
 scene.show_party_menu("技能","blade")
 check("可用经验 200" in texts(scene.modal) and "追斩" in texts(scene.modal) and "回旋刃" in texts(scene.modal),"tree displays both branches and balance")
 check(button(scene.modal,"解锁追斩").disabled,"prerequisite visible and blocked")
 button(scene.modal,"强化掠影突袭").pressed.emit()
 check(scene.campaign.roster[1].xp==155 and "2 / 3级" in texts(scene.modal),"real UI upgrades and refreshes")
 button(scene.modal,"解锁追斩").pressed.emit()
 check(scene.campaign.roster[1].xp==125 and "execute" in scene.campaign.Professions.skills_for(scene.campaign.roster[1]),"real UI unlocks usable skill")
 scene.campaign.depart();scene.selected_ids=["hero","blade"];scene.begin_battle(0)
 scene.show_party_menu("技能","blade")
 check(button(scene.modal,"强化掠影突袭").disabled,"battle cannot spend")
 scene.queue_free();await process_frame
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
