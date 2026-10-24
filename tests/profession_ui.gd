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
func _initialize():call_deferred("run")
func run():
 var scene=load("res://game/main.tscn").instantiate()
 root.add_child(scene);await process_frame
 scene.set_process(false);scene.close_modal()
 scene.campaign=preload("res://game/campaign.gd").new("user://profession-ui.json")
 scene.show_party_menu("职业","medic")
 check("营地转职" in texts(scene.modal),"profession page provides camp retraining")
 scene.show_party_menu("装备","medic")
 var content=texts(scene.modal)
 check("主手" in content and "副手" in content and "护甲" in content,"three equipment slots visible")
 check("4 → 2" in content,"plate penalty preview")
 scene.show_party_menu("职业","hero")
 check("团长" in texts(scene.modal) and "主角" in texts(scene.modal),"identity and profession separate")
 check("光环" in texts(scene.modal),"hero aura preview")
 scene.show_party_menu("技能","engineer")
 check("布设机关" in texts(scene.modal) and "震荡弹" in texts(scene.modal),"profession skills in dossier")
 scene.close_modal();scene.campaign.depart();scene.selected_ids=["engineer","hero"];scene.begin_battle(0)
 check(scene.has_method("select_skill"),"skill selector exists")
 if scene.has_method("select_skill"):
  scene.battle.order_index=scene.battle.order.find(0)
  scene.select_skill("trap")
  check(scene.battle_mode=="skill" and scene.selected_skill=="trap","specific skill selected")
  var cell=scene.battle.active().cell+Vector2i(0,-1)
  check(scene.target_cell_allowed(cell),"legal empty trap tile highlighted")
  check(scene.perform_battle_action("skill",cell),"empty tile skill executes through real UI")
  scene.presentation.advance(1.05)
  check(scene.presentation.floats.any(func(entry):return entry.node.text=="机关就绪"),"trap shows feedback on chosen cell at impact")
  scene.presentation.advance(4)
  check(scene.battle.traps.size()==1,"trap remains after presentation")
  check(scene.battle_mode=="" and scene.selected_skill=="","selection cleared after action")
 scene.campaign=preload("res://game/campaign.gd").new("user://profession-ui-dash.json")
 scene.campaign.depart();scene.selected_ids=["blade","hero"];scene.begin_battle(0)
 scene.battle.obstacles=[]
 var blade=scene.battle.active()
 blade.cell=Vector2i.ZERO
 scene.battle.actors[2].cell=Vector2i(2,0)
 scene.draw_battle()
 scene.select_skill("dash")
 check(scene.perform_battle_action("skill","enemy0"),"dash initiated")
 var origin=scene.presentation.source.position
 scene.presentation.advance(0.8)
 check(not scene.presentation.source.position.is_equal_approx(origin),"dash visibly approaches landing before impact")
 scene.presentation.advance(4)
 scene.queue_free();await process_frame
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
