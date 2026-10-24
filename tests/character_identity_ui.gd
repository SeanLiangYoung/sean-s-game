extends SceneTree
const Campaign=preload("res://game/campaign.gd")
const Characters=preload("res://game/characters.gd")
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
  var result=button(child,needle)
  if result!=null:return result
 return null
func _initialize():call_deferred("run")
func run():
 var scene=load("res://game/main.tscn").instantiate();root.add_child(scene);await process_frame
 scene.set_process(false)
 var path="user://character-identity-ui-test.json"
 DirAccess.remove_absolute(path)
 scene.campaign=Campaign.new(path)
 scene.settings_path="user://character-unlock-ui-test.cfg"
 DirAccess.remove_absolute(scene.settings_path+".progression")
 scene.request_new_game()
 check(scene.menu_screen=="captain" and not FileAccess.file_exists(path),"selection happens before save creation")
 check(not button(scene.modal,"沈烬 · ").disabled,"first captain available immediately")
 check(button(scene.modal,"闻笙 · ").disabled and "通关普通" in button(scene.modal,"闻笙 · ").text,"second captain requires normal completion")
 check(button(scene.modal,"陆衡 · ").disabled and "通关噩梦" in button(scene.modal,"陆衡 · ").text,"third captain requires nightmare completion")
 var before=scene.campaign
 scene.start_new_campaign("wen")
 check(scene.campaign==before and not FileAccess.file_exists(path),"direct start cannot bypass locked captain")
 scene.show_captain_selection("lu")
 check(button(scene.modal,"以「沈烬」")!=null,"locked selection falls back to first captain")
 for difficulty in [0,1,2]:
  scene.campaign.overall_difficulty=difficulty
  scene.campaign.cleared_regions=["border","wood","waste","frost","marsh","ruins"]
  scene.show_reward()
  scene.new_game()
  check(not button(scene.modal,"闻笙 · ").disabled,"normal clear permanently unlocks second captain")
  check(button(scene.modal,"陆衡 · ").disabled==(difficulty<2),"third captain unlocks only after nightmare")
 scene.campaign.cleared_regions=[]
 for captain in Characters.CAPTAINS:
  var d=Characters.CATALOG[captain]
  button(scene.modal,d.name+" · ").pressed.emit()
  check(d.story in texts(scene.modal) and d.effect in texts(scene.modal),"captain card exposes full story and talent "+captain)
 button(scene.modal,"以「陆衡」").pressed.emit()
 check(scene.campaign.roster[0].character_id=="lu" and not is_instance_valid(scene.modal),"selected captain enters game")
 var loaded=Campaign.new(path)
 check(loaded.load_game() and loaded.roster[0].name=="陆衡","selected captain persists")
 scene.show_main_menu();scene.request_new_game()
 button(scene.modal,"确认开始").pressed.emit()
 button(scene.modal,"闻笙 · ").pressed.emit()
 button(scene.modal,"返回主菜单").pressed.emit()
 check(loaded.load_game() and loaded.roster[0].character_id=="lu","cancel captain selection retains existing save")
 DirAccess.remove_absolute(scene.settings_path+".progression")
 scene.show_main_menu()
 scene.continue_game()
 check(scene.campaign.roster[0].character_id=="lu","existing locked captain save can still be continued")
 for id in Characters.CATALOG:
  var unit=Characters.create(id)
  scene.campaign.roster=[Characters.create("shen")] if unit.id!="hero" else []
  scene.campaign.roster.append(unit)
  scene.show_party_menu("详情",unit.id)
  var content=texts(scene.modal)
  var d=Characters.CATALOG[id]
  check(d.story in content and d.talent in content and d.effect in content and d.relics in content,"details complete for "+id)
 scene.battle=null;scene.campaign=Campaign.new(path)
 scene.campaign.start_region("border");scene.campaign.route.setup("border");scene.campaign.encounters=["open","open","open"]
 scene.campaign.enter_route("0b");scene.campaign.enter_route("1b");scene.campaign.silver=1000
 scene.show_route_trade()
 var content=texts(scene.modal)
 for id in scene.campaign.recruit_candidates():check(Characters.CATALOG[id].talent in content,"recruit talent visible "+id)
 check(button(scene.modal,"已在佣兵团中")!=null,"recruit page identifies existing members")
 DirAccess.remove_absolute(scene.settings_path+".progression")
 scene.queue_free();await process_frame
 DirAccess.remove_absolute(path)
 print("CHECKS: %d FAILURES: %d"%[checks,failures])
 quit(1 if failures else 0)
