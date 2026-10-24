extends SceneTree
var checks=0
var failures=0
const Rules=preload("res://game/rules.gd")
func check(value: bool,message: String):
 checks+=1
 if not value:failures+=1;push_error(message)
func setup():
 var b=Rules.new()
 b.start_battle(b.default_party().slice(0,1),0)
 b.obstacles=[]
 b.active().cell=Vector2i.ZERO
 for i in range(1,b.actors.size()):b.actors[i].cell=Vector2i(i,0)
 return b
func _initialize():call_deferred("run")
func run():
 var b=setup()
 check(b.has_method("auto_action"),"greedy auto planner exists")
 if not b.has_method("auto_action"):
  print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1);return
 var before=b.actors.duplicate(true)
 var action=b.auto_action()
 check(action.action=="skill" and action.skill=="strike","prefer stronger legal strike")
 check(b.actors==before,"planning leaves live actors untouched")
 b.active().mp=0
 b.actors[1].hp=1
 b.actors[2].cell=Vector2i(0,1)
 action=b.auto_action()
 check(action.action=="attack" and action.target==b.actors[2].id,"cap overkill and choose more actual damage")
 b=setup()
 b.active().skill_ranks.bomb=1
 b.active().learned.append("bomb")
 action=b.auto_action()
 check(action.action=="skill" and action.skill=="bomb","sum area damage across enemies")
 b=setup()
 b.active().mp=0
 b.actors[1].cell=Vector2i(3,0)
 b.actors[2].cell=Vector2i(3,-1)
 b.actors[3].cell=Vector2i(2,1)
 action=b.auto_action()
 check(action.action=="move","close distance when no target in range")
 check(b.move_to(action.target),"planned movement is legal")
 check(b.active().side==0 and b.active().ap>=2,"movement reserves attack AP")
 check(b.auto_action().action=="attack","movement enables attack")
 b.outcome="victory"
 check(b.auto_action().is_empty(),"finished combat has no auto actions")
 b=Rules.new()
 b.start_battle(b.default_party().slice(0,5),0)
 var steps=0
 while b.outcome=="" and steps<300:
  if b.active().side==1:b.enemy_step()
  else:
   var choice=b.auto_action()
   var accepted=false
   match choice.get("action",""):
    "attack":accepted=b.attack(choice.target)
    "skill":accepted=b.cast(choice.target,choice.skill)
    "move":accepted=b.move_to(choice.target)
    "rest_mp":accepted=b.rest("mp")
    "rest_hp":accepted=b.rest("hp")
    "end":accepted=b.end_action()
   check(accepted,"auto always selects an executable action")
   if not accepted:break
  steps+=1
 check(b.outcome!="" and steps<300,"automatic battle reaches settlement without looping")
 var scene=load("res://game/main.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 scene.set_process(false)
 scene.close_modal()
 scene.campaign=preload("res://game/campaign.gd").new("user://auto-combat-test.json")
 scene.session_started=true
 scene.campaign.depart()
 scene.selected_ids=["hero","blade"]
 scene.begin_battle(0)
 check(scene.has_method("toggle_auto_battle"),"auto toggle available")
 if scene.has_method("toggle_auto_battle"):
  check(not scene.auto_battle,"battle starts manual")
  scene.toggle_auto_battle()
  check(scene.auto_battle and scene.battle_mode=="","one click enables auto")
  if "--capture-auto" in OS.get_cmdline_user_args():
   scene.set_game_hud_visible(true)
   await process_frame
   await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://artifacts/auto-combat.png")
  scene._process(0.7)
  check(scene.presentation.busy,"auto uses animated action pipeline")
  scene.toggle_auto_battle()
  check(not scene.auto_battle,"can stop during animation")
  scene.presentation.advance(4)
  scene.toggle_auto_battle()
  scene.show_pause_menu()
  var actors=scene.battle.actors.duplicate(true)
  scene._process(1)
  check(scene.battle.actors==actors,"pause menu blocks auto")
  scene.close_modal()
  scene.return_world()
  check(not scene.auto_battle,"auto resets on leaving combat")
 scene.queue_free()
 await process_frame
 print("CHECKS: %d FAILURES: %d"%[checks,failures])
 quit(1 if failures else 0)
