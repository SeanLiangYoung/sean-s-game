extends SceneTree
const Campaign=preload("res://game/campaign.gd")
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
func preview_edges(s):
 for variant in ["normal","snare","free","trap"]:
  var b=preload("res://game/rules.gd").new();b.start_battle(b.default_party().slice(0,3),0);s.battle=b
  var actor=b.active();var target=Vector2i(999,999)
  for cell in b.cells():
   if b.path_to(actor.cell,cell).size()==2:target=cell;break
  check(target.x!=999,"two-step movement fixture")
  if target.x==999:continue
  var path=b.path_to(actor.cell,target)
  if variant=="snare":actor.statuses.snare={"source":"enemy0"}
  if variant=="free":b.Talents.state(actor).free_step=true
  if variant=="trap":b.traps=[{"cell":path[0],"side":1,"source":"enemy0","damage":1}]
  var before=actor.ap;var preview=s.movement_preview(target)
  check(not preview.is_empty(),"legal movement preview "+variant)
  check(b.move_to(target),"legal movement executes "+variant)
  check(before-actor.ap==preview.cost and actor.ap==preview.remaining,"actual AP matches preview "+variant)
  check(actor.cell==preview.path[-1],"actual destination matches preview "+variant)
  if variant=="trap":check(preview.trapped and preview.path.size()==1,"trap shows actual stopping point")
 s.battle=preload("res://game/rules.gd").new();s.battle.start_battle(s.battle.default_party().slice(0,3),0)
 var actor=s.battle.active()
 check(s.movement_preview(Vector2i(99,99)).is_empty(),"unreachable preview rejected")
 s.select_action("move")
 var reachable=[]
 for cell in s.battle.cells():
  var data=s.movement_preview(cell)
  if not data.is_empty() and data.remaining==0:reachable.append(cell)
 check(not reachable.is_empty(),"can preview spending all AP")
 if not reachable.is_empty():
  s.update_movement_preview(s.camera.unproject_position(s.cell_position(reachable[0])))
  check("将结束行动" in s.movement_label.text,"zero AP consequence visible before click")
  check(is_instance_valid(s.move_preview_root),"hover renders path")
  s.cancel_action()
  check(not is_instance_valid(s.move_preview_root),"cancel removes stale path")
 actor.statuses={"shield":{"bonus":0},"mark":{"bonus":0},"poison":{"bonus":2,"ticks":2}}
 s.select_action("skills")
 check(s.sidebar.find_child("StatusIcons",true,false).get_child_count()==3,"important active states have individual visible icons")
 var command=s.sidebar.get_node("ActionCommands")
 var grid=command.get_children().filter(func(node):return node is GridContainer)[0]
 await process_frame;await process_frame
 check(grid.get_child_count()==6,"all six common actions remain while selecting skills")
 check(grid.get_global_rect().end.y<s.sidebar.get_parent().get_global_rect().end.y,"common actions fit sidebar")
 s.select_action("rest")
 await process_frame;await process_frame
 var options=s.footer.find_child("ActionOptions",true,false)
 check(options.get_global_rect().end.y<=s.get_viewport().get_visible_rect().size.y,"rest choices fit footer without vertical overflow")

func run():
 root.size=Vector2i(1280,800)
 var s=load("res://game/main.tscn").instantiate();root.add_child(s);await process_frame
 s.set_process(false)
 s.campaign=Campaign.new("user://compact-ui-test.json")
 s.show_captain_selection()
 var start=s.modal.find_child("StartJourney",true,false)
 check(start!=null,"new journey has primary start action")
 if start!=null:
  await process_frame;await process_frame
  check(start.get_global_rect().end.y<=s.get_viewport().get_visible_rect().size.y,"start action remains in viewport")
 check(s.has_method("show_details"),"secondary details preserve underlying page")
 if s.has_method("show_details"):
  var page=s.modal
  s.show_details("详情","长篇内容")
  s.close_details()
  check(s.modal==page,"closing details keeps selection page instance")
 s.close_modal();s.set_game_hud_visible(true);s.campaign.depart();s.show_deploy(0)
 await process_frame;await process_frame
 var deploy=s.modal.find_child("DeployStart",true,false)
 check(deploy!=null,"deployment primary action exists")
 if deploy!=null:check(deploy.get_global_rect().end.y<=s.get_viewport().get_visible_rect().size.y,"deployment action stays in first screen")
 s.begin_battle(0)
 check(s.has_method("movement_preview"),"movement preview available")
 if s.has_method("movement_preview"):
  var a=s.battle.active()
  var dest=Vector2i(999,999)
  for cell in s.battle.cells():
   var path=s.battle.path_to(a.cell,cell)
   if path.size()>s.battle.hex_distance(a.cell,cell) and s.battle.movement_cost(a,path)<=a.ap:dest=cell;break
  check(dest.x!=999,"fixture contains affordable detour")
  if dest.x!=999:
   var preview=s.movement_preview(dest)
   var before=a.ap
   check(not preview.is_empty() and preview.path==s.battle.path_to(a.cell,dest),"preview uses actual legal detour")
   check(a.ap==before,"preview does not spend resources")
   check(s.battle.move_to(dest) and before-a.ap==preview.cost,"actual movement agrees with preview")
  check(s.movement_preview(a.cell).is_empty(),"occupied origin cannot preview a move")
 s.refresh_ui()
 var metric=s.sidebar.find_child("CombatMetrics",true,false)
 check(metric!=null,"combat resources use compact metrics")
 check(not s.status_label.visible,"combat does not duplicate actor identity in a large empty banner")
 await preview_edges(s)
 s.campaign=Campaign.new("user://compact-ui-test.json");s.campaign.depart()
 var b=s.campaign.make_battle(["hero","blade","ranger"],0)
 var fallen_name=b.find_actor("blade").name
 b.find_actor("blade").hp=0;b.outcome="victory"
 check(s.campaign.resolve_battle(b),"casualty fixture resolves")
 check(s.campaign.to_data().has("last_battle_summary"),"casualty report persists with reward checkpoint")
 var loaded=Campaign.new("user://compact-ui-test.json")
 check(loaded.load_game(),"reward checkpoint reloads")
 s.campaign=loaded;s.battle=null;s.show_reward()
 var summary=s.modal.find_child("BattleSummary",true,false)
 check(summary!=null,"reward reload still displays casualties")
 if summary!=null:check(fallen_name in texts(summary) and "永久" in texts(summary),"casualty name and permanent consequence visible")
 var cards=s.modal.find_child("RewardGrid",true,false)
 check(cards!=null,"reward choices use compact comparison")
 if cards!=null:
  await process_frame;await process_frame
  check(cards.get_global_rect().end.y<=s.get_viewport().get_visible_rect().size.y,"all five rewards fit baseline viewport")
 var legacy=loaded.to_data();legacy.erase("last_battle_summary")
 var old=Campaign.new("user://compact-ui-test.json")
 check(old.load_data(legacy) and old.last_battle_summary.is_empty(),"old saves without report remain compatible")
 var invalid=loaded.to_data();invalid.last_battle_summary.members[0].hp="broken"
 var unchanged=old.to_data()
 check(not old.load_data(invalid) and old.to_data()==unchanged,"invalid report rejected without mutating campaign")
 var fresh=Campaign.new("user://compact-ui-test.json");fresh.depart()
 var all_alive=fresh.make_battle(["hero","blade"],0);all_alive.outcome="victory";fresh.resolve_battle(all_alive)
 s.campaign=fresh;s.show_reward()
 check("全员存活" in texts(s.modal.find_child("BattleSummary",true,false)),"zero casualties explicitly shown")
 var encounter=Campaign.new("user://compact-ui-test.json");encounter.depart()
 var defeat=encounter.make_battle(["blade","ranger"],0)
 for unit in defeat.actors:
  if unit.side==0:unit.hp=0
 defeat.outcome="defeat";encounter.resolve_battle(defeat)
 check(encounter.last_battle_summary.members.size()==2 and encounter.last_battle_summary.outcome=="defeat","defeat records only deployed members, not reserves")
 s.campaign=Campaign.new("user://compact-ui-test.json")
 check(s.campaign.load_game(),"ordinary defeat checkpoint reloads")
 s.battle=null;s.session_started=true;s.close_modal();s.show_pause_menu()
 var history=s.modal.find_children("*","Button",true,false).filter(func(entry):return "上一场战报" in entry.text)
 check(history.size()==1,"ordinary defeat report remains accessible after continue")
 if history.size()==1:
  history[0].pressed.emit()
  check("永久阵亡" in texts(s.detail_overlay),"previous report retains casualties after continue")
  s.close_details()
 s.campaign=Campaign.new("user://compact-ui-test.json")
 s.campaign.cleared_regions=["border","wood","waste","frost","marsh","ruins"]
 s.settings_path="user://missing-compact-unlock/config.cfg"
 s.show_reward()
 check("解锁记录保存失败" in texts(s.modal) and not "已解锁下一难度" in texts(s.modal),"failed unlock write never claims success")
 s.queue_free();await process_frame
 DirAccess.remove_absolute("user://compact-ui-test.json")
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
