extends SceneTree
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func texts(node: Node) -> String:
 var result=""
 if node is Label or node is Button:result+=node.text+"\n"
 for child in node.get_children():result+=texts(child)
 return result
func find_button(node: Node,needle: String):
 if node is Button and needle in node.text:return node
 for child in node.get_children():
  var found=find_button(child,needle)
  if found!=null:return found
 return null
func _initialize():call_deferred("run")
func run():
 var scene=load("res://game/main.tscn").instantiate();root.add_child(scene);await process_frame
 scene.set_process(false);scene.close_modal()
 scene.campaign=load("res://game/campaign.gd").new("user://character-pages-test.json")
 scene.campaign.books=["focus"]
 scene.show_party_menu("角色","medic")
 check(scene.menu_tab=="详情","old character entry opens Details")
 var content=texts(scene.modal)
 check("角色基础" in content and "当前技能" not in content and "队伍装备库" not in content,"details contains identity and stats only")
 var skills=find_button(scene.modal,"技能")
 check(skills!=null,"dedicated Skills navigation exists")
 if skills==null:
  scene.queue_free();await process_frame
  print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1);return
 skills.pressed.emit()
 check(scene.menu_tab=="技能" and scene.menu_character=="medic","page switch keeps character")
 content=texts(scene.modal)
 check("回春" in content and "净护" in content and "技能书" in content and "队伍装备库" not in content,"skills page shows usable skills and learning")
 find_button(scene.modal,"沈烬").pressed.emit()
 check(scene.menu_tab=="技能" and scene.menu_character=="hero","switching character retains skills page")
 find_button(scene.modal,"技能书 · 调息 →").pressed.emit()
 check("focus" in scene.campaign.roster[0].learned and scene.menu_tab=="技能","learning remains on skills page")
 scene.show_party_menu("装备","hero")
 content=texts(scene.modal)
 check("队伍装备库" in content and "当前技能" not in content,"equipment has its own page")
 var roster_scroll=scene.modal.find_child("CharacterRosterScroll",true,false)
 var page_scroll=scene.modal.find_child("CharacterPageScroll",true,false)
 check(roster_scroll!=null and page_scroll!=null and roster_scroll!=page_scroll,"roster scrolls separately from page")
 scene.show_party_menu("物品","hero")
 check("队伍共享物品" in texts(scene.modal) and "技能书" not in texts(scene.modal),"shared inventory does not duplicate skill learning")
 scene.queue_free();await process_frame
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
