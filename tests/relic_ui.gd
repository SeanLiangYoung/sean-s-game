extends SceneTree
var checks=0
var failures=0
func check(value,message):
 checks+=1
 if not value:failures+=1;print("FAIL: ",message)
func _initialize():call_deferred("run")
func has_text(node,needle):
 if (node is Label or node is Button) and needle in node.text:return true
 for child in node.get_children():
  if has_text(child,needle):return true
 return false
func find_button(node,needle):
 if node is Button and needle in node.text:return node
 for child in node.get_children():
  var result=find_button(child,needle)
  if result!=null:return result
 return null
func run():
 var scene=load("res://game/main.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 scene.campaign=load("res://game/campaign.gd").new("user://ashbound-relic-ui.json")
 scene.show_party_menu("装备","hero")
 check(has_text(scene.modal,"遗物栏"),"independent personal slot visible alongside equipment")
 scene.campaign.depart()
 scene.campaign.acquire_relic("candle","hero")
 scene.campaign.acquire_relic("banner")
 scene.campaign.acquire_relic("prism","medic")
 scene.show_party_menu("技能","medic")
 check(has_text(scene.modal,"恢复 44") and has_text(scene.modal,"2点 / 9法力"),"current skill details include relic healing and mana cost")
 scene.show_party_menu("遗物","hero")
 check(has_text(scene.modal,"续命烛芯") and has_text(scene.modal,"裂甲战旗"),"world relic page shows owned instances")
 check(has_text(scene.modal,"剩余 1 / 1") and has_text(scene.modal,"沈烬"),"remaining charges and wearer displayed")
 check(has_text(scene.modal,"代价："),"risk displayed")
 check(not has_text(scene.modal,"封存") and not has_text(scene.modal,"卸下遗物"),"no deactivation controls")
 check(scene.has_method("show_relic_catalog"),"complete relic catalog is browseable")
 if scene.has_method("show_relic_catalog"):
  scene.show_relic_catalog("blood")
  check(has_text(scene.modal,"赤誓残卷") and has_text(scene.modal,"殉火心脏"),"theme filter shows complete blood family")
  check(not has_text(scene.modal,"湛蓝瞳环"),"theme filter excludes unrelated entries")
  scene.show_relic_catalog()
  check(has_text(scene.modal,"110") and has_text(scene.modal,"百战军册"),"full catalog includes all relics")
 scene.campaign.phase="reward"
 scene.campaign.choices=[scene.campaign.REWARDS.filter(func(r):return r.id=="echo")[0]]
 scene.show_reward()
 var choose=find_button(scene.modal,"选择此奖励")
 check(choose!=null,"reward choice reachable")
 if choose!=null:choose.pressed.emit()
 check(scene.campaign.phase=="reward","personal reward waits for explicit wearer")
 check(has_text(scene.modal,"替换并失去：续命烛芯"),"replacement warning names old relic")
 var bind=find_button(scene.modal,"绑定给 沈烬")
 check(bind!=null,"wearer confirmation reachable")
 if bind!=null:bind.pressed.emit()
 check(scene.campaign.phase=="world" and scene.campaign.personal_relic("hero").id=="echo","UI binds reward and returns world")
 print("CHECKS: ",checks," FAILURES: ",failures)
 quit(1 if failures else 0)
