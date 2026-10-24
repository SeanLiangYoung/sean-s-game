extends SceneTree
var checks=0
var failures=0
func check(value,message):
 checks+=1
 if not value:failures+=1;print("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
 var scene=load("res://game/main.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 await process_frame
 scene.campaign=load("res://game/campaign.gd").new("user://ashbound-presentation-tests.json")
 scene.campaign.equip_item(2,"ranger")
 scene.campaign.depart()
 scene.show_deploy(0)
 scene.begin_battle(0)
 check(scene.has_method("perform_battle_action"),"combat commands expose a presentation timeline")
 var pawn=scene.pawn_nodes[0]
 check(pawn.find_child("AnimationPlayer",true,false)!=null,"characters have real skeletal animation")
 if scene.has_method("perform_battle_action"):
  scene.set_process(false)
  var actor=scene.battle.active()
  var enemy=scene.battle.actors.filter(func(u):return u.side==1)[0]
  enemy.cell=actor.cell+Vector2i(1,0)
  scene.draw_battle()
  var hp=enemy.hp
  scene.perform_battle_action("attack",enemy.id)
  check(scene.presentation.busy,"attack locks input while playing")
  scene.perform_battle_action("attack",enemy.id)
  check(enemy.hp==maxi(0,hp-actor.power),"repeated input cannot apply damage twice")
  check(scene.presentation.impact_count==0,"damage feedback waits for impact")
  scene.presentation.advance(0.45)
  check(scene.presentation.impact_count==1,"impact feedback occurs once")
  check(scene.presentation.get_child_count()>0,"impact produces visible feedback")
  scene.presentation.advance(2)
  check(not scene.presentation.busy,"attack completes and unlocks")
  actor.hp=maxi(1,actor.hp-20)
  scene.perform_battle_action("rest_hp")
  check(scene.presentation.busy,"rest plays recovery animation")
  scene.presentation.advance(2)
  check(not scene.presentation.busy,"rest completes")
  scene.begin_battle(0)
  actor=scene.battle.active()
  check(not scene.perform_battle_action("move",actor.cell) and not scene.presentation.busy,"invalid move produces no playback")
  actor.mp=0
  var old_mp=actor.mp
  scene.perform_battle_action("rest_mp")
  check(scene.presentation.mode=="rest_mp" and actor.mp>old_mp,"mana rest restores mana and selects distinct presentation")
  scene.presentation.advance(0.45)
  check(scene.presentation.get_child_count()>0,"mana recovery produces visible feedback")
  scene.presentation.advance(2)
  # Final kill must not expose reward over the attack wind-up.
  scene.begin_battle(0)
  actor=scene.battle.active()
  for unit in scene.battle.actors:
   if unit.side==1:unit.hp=0
  enemy=scene.battle.actors.filter(func(u):return u.side==1)[0]
  enemy.hp=1
  enemy.cell=actor.cell+Vector2i(1,0)
  scene.draw_battle()
  scene.perform_battle_action("attack",enemy.id)
  check(scene.campaign.phase=="battle" and not is_instance_valid(scene.modal),"final kill waits before reward")
  var death_clip=scene.presentation.pawn_for(enemy.id).find_child("AnimationPlayer",true,false).get_animation("Death")
  check(scene.presentation.duration-scene.presentation.impact_time>=death_clip.length,"lethal timeline preserves the complete death clip")
  scene.presentation.advance(2)
  check(scene.campaign.phase=="reward","reward appears after death feedback")
 # A movement that spends the last AP can trigger shrinking and damage.
  scene.close_modal()
  scene.campaign=load("res://game/campaign.gd").new("user://ashbound-presentation-tests.json")
  scene.campaign.equip_item(2,"ranger")
  scene.campaign.depart()
  scene.show_deploy(0)
  scene.begin_battle(0)
  actor=scene.battle.active()
  scene.battle.obstacles=[]
  actor.cell=Vector2i(4,-1)
  actor.ap=1
  scene.battle.order=[scene.battle.actors.find(actor)]
  scene.battle.order_index=0
  scene.battle.round_no=3
  scene.draw_battle()
  check(scene.perform_battle_action("move",Vector2i(4,0)),"edge movement accepted")
  scene.presentation.advance(0.56)
  check(scene.presentation.busy and scene.presentation.get_child_count()>0,"movement-triggered shrink retains a visible hit recovery segment")
  scene.presentation.advance(2)
  scene.begin_battle(0)
  var archer=scene.battle.find_actor("enemy2")
  scene.battle.order=[scene.battle.actors.find(archer)]
  scene.battle.order_index=0
  archer.cell=Vector2i(0,0)
  scene.draw_battle()
  scene.perform_battle_action("enemy")
  var archer_pawn=scene.presentation.pawn_for("enemy2")
  var player=archer_pawn.find_child("AnimationPlayer",true,false) if archer_pawn!=null else null
  check(player!=null and player.current_animation=="Bow_Shoot","enemy archer plays ranged attack")
  check(is_instance_valid(scene.presentation.projectile),"enemy ranged attack has a projectile")
  scene.presentation.advance(2)
  scene.begin_battle(0)
  actor=scene.battle.find_actor("ranger")
  scene.battle.order=[scene.battle.actors.find(actor)]
  scene.battle.order_index=0
  enemy=scene.battle.find_actor("enemy0")
  enemy.cell=actor.cell+Vector2i(1,0)
  scene.draw_battle()
  scene.perform_battle_action("skill",enemy.id)
  var bow_player=scene.presentation.source.find_child("AnimationPlayer",true,false)
  check(bow_player.current_animation=="Equipment/Bow_Draw","ranged skill draws bow before shooting")
  check(not scene.presentation.projectile.visible,"skill projectile hidden before release")
  scene.presentation.advance(0.15)
  check(not scene.presentation.projectile.visible and scene.presentation.impact_count==0,"charge cannot show a projectile or impact early")
  scene.presentation.advance(0.6)
  check(bow_player.current_animation=="Equipment/Bow_Shoot","release transitions to shooting")
  scene.presentation.advance(2)
  check(not scene.presentation.busy and scene.presentation.impact_count==1,"coarse skill frames finish with exactly one impact")
  scene.begin_battle(0)
  actor=scene.battle.find_actor("blade")
  actor.cell=Vector2i(0,0)
  actor.ap=3
  enemy=scene.battle.find_actor("enemy0")
  enemy.cell=Vector2i(1,0)
  scene.battle.find_actor("hero").cell=Vector2i(4,0)
  scene.battle.order=[scene.battle.actors.find(actor)]
  scene.battle.order_index=0
  scene.battle.round_no=3
  scene.battle.obstacles=[]
  scene.draw_battle()
  scene.perform_battle_action("skill",enemy.id)
  check(scene.presentation.projectile_target.is_equal_approx(scene.cell_position(Vector2i(1,0))+Vector3(0,0.8,0)),"skill targets chosen enemy even when shrink damages another actor")
  scene.presentation.advance(3)
  scene.begin_battle(0)
  actor=scene.battle.find_actor("medic")
  actor.cell=Vector2i(0,0)
  var patient=scene.battle.find_actor("hero")
  patient.cell=Vector2i(1,0)
  patient.hp=patient.max_hp-30
  scene.battle.order=[scene.battle.actors.find(actor)]
  scene.battle.order_index=0
  scene.draw_battle()
  scene.perform_battle_action("skill",patient.id)
  check(scene.presentation.style=="heal" and not scene.presentation.projectile.visible,"healing charges with a hidden green projectile")
  scene.presentation.advance(0.7)
  check(scene.presentation.release_count==1 and scene.presentation.impact_count==0,"healing releases before recovery feedback")
  scene.presentation.advance(0.4)
  check(scene.presentation.impact_count==1 and scene.presentation.floats[0].node.text.begins_with("+"),"healing impact displays actual positive recovery")
  scene.presentation.advance(3)
 scene.queue_free()
 await process_frame
 print("CHECKS: ",checks," FAILURES: ",failures)
 quit(1 if failures else 0)
