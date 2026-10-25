extends SceneTree
const Campaign=preload("res://game/campaign.gd")
var checks=0
var failures=0
var scene
func check(ok: bool,label: String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label)
func find_button(node,needle):
 if node is Button and needle in node.text:return node
 for child in node.get_children():
  var found=find_button(child,needle)
  if found!=null:return found
 return null
func _initialize():call_deferred("run")
func run():
 scene=load("res://game/main.tscn").instantiate();root.add_child(scene);await process_frame;scene.set_process(false)
 var path="user://village-journey-test.json"
 for suffix in ["",".relics",".achievements"]:DirAccess.remove_absolute(path+suffix)
 scene.campaign=Campaign.new(path);scene.enter_campaign()
 scene.atlas.find_child("Door_memory",true,false).pressed.emit()
 check("home_memory" in scene.campaign.story_state.seen,"house button records discovery")
 find_button(scene.modal,"走回村中").pressed.emit()
 find_button(scene.atlas,"选择远征").pressed.emit()
 check(scene.selecting_expedition,"map opened from village")
 scene.show_region("border");find_button(scene.modal,"确认出发").pressed.emit()
 check(scene.campaign.phase=="world" and scene.atlas.route_mode,"departure follows normal UI")
 check("border_approach" in scene.campaign.story_state.seen,"first journey clue")
 # Deterministic battle fixture, not a claimed natural playthrough or balance sample.
 scene.campaign.rng.seed=71023
 var n=scene.campaign.route.nodes.filter(func(node):return node.depth==0 and node.kind=="battle")[0]
 scene.select_route_node(n.id);scene.selected_ids=["hero","blade","ranger","medic","engineer"]
 scene.begin_battle(n.encounter)
 check(scene.battle!=null,"deployment opens actual battle")
 for actor in scene.battle.actors:
  if actor.side==1:actor.hp=0
 scene.battle.check_outcome();scene.after_battle_action()
 check(scene.campaign.phase=="reward","victory reaches reward UI")
 check(scene.modal.find_child("BuildPreview",true,false)!=null,"reward previews actual builds")
 check(scene.modal.find_child("RewardStory",true,false)!=null,"story clue accessible at reward")
 var index=-1
 for i in scene.campaign.choices.size():
  if scene.campaign.choices[i].type=="relic" and Campaign.Relic.definition(scene.campaign.choices[i].id).scope=="team":index=i;break
 check(index>=0,"team relic choice exists")
 check(scene.campaign.choose_reward(index),"reward accepted")
 scene.return_world()
 # Drive route transitions through existing callbacks. Battles use explicit fixtures.
 var steps=0
 while scene.campaign.phase=="world" and steps<12:
  var next=scene.campaign.route.available()
  if next.is_empty():break
  scene.select_route_node(next[0]);var current=scene.campaign.route.node(scene.campaign.route.current)
  if current.kind=="battle" and not scene.campaign.route.completed:
   scene.begin_battle(current.encounter)
   for actor in scene.battle.actors:
    if actor.side==1:actor.hp=0
   scene.battle.check_outcome();scene.after_battle_action()
   check(scene.campaign.choose_reward(0),"route reward accepts")
   scene.return_world()
  elif current.kind=="extract":
   var keep=[0] if not scene.campaign.relics.is_empty() else []
   check(scene.campaign.extract(keep),"extraction settles normally")
   scene.return_world()
  else:scene.close_modal()
  steps+=1
 check(scene.campaign.phase=="camp" and scene.scene_root.has_node("Village"),"return rebuilds village")
 check("border_trace" in scene.campaign.story_state.seen and "border_after" in scene.campaign.story_state.seen,"deep and aftermath fragments unlocked through route")
 scene.show_village_home("memory");var repair=find_button(scene.modal,"帮忙修缮")
 check(repair!=null and not repair.disabled,"repair action ready after expedition")
 if repair!=null:repair.pressed.emit()
 check("memory" in scene.campaign.story_state.repaired,"repair callback changes home")
 scene.close_modal();scene.show_village_journal()
 check(is_instance_valid(scene.modal),"journey fragments can be reread")
 scene.close_modal();scene.show_relic_strategy()
 check(is_instance_valid(scene.modal),"build page opens after returning")
 var loaded=Campaign.new(path)
 var restored=loaded.load_game()
 check(restored and loaded.story_state==scene.campaign.story_state,"whole journey persists on disk")
 scene.queue_free();await process_frame
 for suffix in ["",".relics",".achievements"]:DirAccess.remove_absolute(path+suffix)
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
