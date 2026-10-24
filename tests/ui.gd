extends SceneTree
var failures=0
var checks=0
func check(value,message):
 checks+=1
 if not value:failures+=1;print("FAIL: ",message)
func _initialize():
 call_deferred("run")
func run():
 var scene=load("res://game/main.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 await process_frame
 check(scene.ui.get_child(0).size.y<100,"header remains one line")
 scene.campaign=load("res://game/campaign.gd").new("user://ashbound-ui-tests.json")
 scene.depart()
 scene.show_deploy(0)
 check(scene.selected_ids.size()==5,"deployment defaults to five")
 scene.begin_battle(0)
 check(scene.battle!=null and scene.campaign.phase=="battle","deployment starts scene battle")
 check(scene.footer.get_child_count()>0,"combat controls exist")
 scene.camera_zoom=13
 scene.draw_battle()
 check(scene.camera_zoom==13,"battle redraw preserves player zoom")
 var actor=scene.battle.active()
 var target=actor.cell+Vector2i(0,1)
 var click=InputEventMouseButton.new()
 click.button_index=MOUSE_BUTTON_LEFT
 click.pressed=true
 click.position=scene.camera.unproject_position(scene.cell_position(target))
 scene._unhandled_input(click)
 check(actor.cell==target and actor.ap==3,"projected board click moves actor and spends AP")
 scene.presentation.advance(2)
 var enemy=scene.battle.actors.filter(func(u):return u.side==1)[0]
 enemy.cell=actor.cell+Vector2i(1,0)
 var enemy_hp=enemy.hp
 scene.battle_mode="attack"
 click.position=scene.camera.unproject_position(scene.cell_position(enemy.cell)+Vector3(0,1,0))
 scene._unhandled_input(click)
 check(enemy.hp<enemy_hp,"clicking enemy model selects its own tile")
 scene.presentation.advance(2)
 scene.battle.round_no=scene.battle.round_limit
 scene.battle.order_index=scene.battle.order.size()-1
 scene.battle.finish_turn()
 scene.after_battle_action()
 check(scene.campaign.phase=="gameover" and is_instance_valid(scene.modal),"timeout exposes game-over modal")
 scene.restore()
 check(scene.battle==null and scene.campaign.phase=="camp","snapshot restores camp scene")
 scene.depart()
 scene.travel_to(0)
 scene._process(10.0)
 scene._process(0.1)
 check(is_instance_valid(scene.modal),"arrival opens deployment")
 scene.begin_battle(0)
 for unit in scene.battle.actors:
  if unit.side==1:unit.hp=0
 scene.battle.check_outcome()
 scene.after_battle_action()
 check(scene.campaign.phase=="reward","scene victory opens three-choice reward")
 var reward_button=find_button(scene.modal,"选择此奖励")
 check(reward_button!=null,"reward button reachable")
 if reward_button!=null:reward_button.pressed.emit()
 check(scene.battle==null and scene.campaign.phase=="world","reward click returns world")
 scene.travel_to(3)
 scene._process(10.0)
 scene._process(0.1)
 var extract_button=find_button(scene.modal,"结束远征")
 check(extract_button!=null,"arrival exposes extraction confirmation")
 if extract_button!=null:extract_button.pressed.emit()
 check(scene.campaign.phase=="camp" and scene.battle==null,"extraction click completes UI loop")
 print("CHECKS: ",checks," FAILURES: ",failures)
 quit(1 if failures else 0)

func find_button(node, needle):
 if node is Button and needle in node.text:return node
 for child in node.get_children():
  var found=find_button(child,needle)
  if found!=null:return found
 return null
