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
 check(scene.has_method("show_party_menu"),"party menu exists")
 if scene.has_method("show_party_menu"):
  scene.show_party_menu("角色","medic")
  check(find_button(scene.modal,"白芷")!=null,"character selector reachable")
  var portrait_card=find_button(scene.modal,"白芷")
  check(portrait_card!=null and portrait_card.icon!=null,"party cards display character portraits")
  scene.show_party_menu("技能","medic")
  check(has_text(scene.modal,"恢复 32"),"medic skill details reflect rules")
  scene.show_party_menu("装备","hero")
  var equip=find_button(scene.modal,"装备此武器")
  check(equip!=null,"inventory equip action reachable")
  if equip!=null:equip.pressed.emit()
  check(scene.campaign.equipped_index("hero")==0,"UI equips selected character")
  var remove=find_button(scene.modal,"卸下当前")
  check(remove!=null,"unequip action reachable")
  if remove!=null:remove.pressed.emit()
  check(scene.campaign.equipped_index("hero")==-1,"UI unequips selected character")
  scene.campaign.relics=["ember","spring","lens"]
  scene.show_party_menu("角色","hero")
  check(has_text(scene.modal,"余烬徽印") and has_text(scene.modal,"旧世泉核"),"character details show effective relics")
  scene.close_modal()
 scene.campaign.depart()
 scene.refresh_ui()
 var world_size=scene.camera.size
 var wheel=InputEventMouseButton.new()
 wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN
 wheel.pressed=true
 scene._unhandled_input(wheel)
 check(scene.camera.size==world_size,"world ignores mouse wheel zoom")
 var ground=scene.scene_root.get_child(0)
 for viewport_size in [Vector2i(1280,800),Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(800,1000)]:
  root.size=viewport_size
  await process_frame
  for corner in [Vector2.ZERO,Vector2(viewport_size.x,0),Vector2(0,viewport_size.y),Vector2(viewport_size)]:
   var point=scene.ground_position(corner)
   check(absf(point.x-ground.position.x)<ground.mesh.size.x/2 and absf(point.z-ground.position.z)<ground.mesh.size.z/2,"world terrain covers viewport corner at %s"%viewport_size)
 root.size=Vector2i(1440,900)
 await process_frame
 scene.show_deploy(0)
 check(scene.selected_ids.size()==5,"deployment defaults to five")
 var deploy_card=find_button(scene.modal,"沈烬")
 check(deploy_card!=null and deploy_card.icon!=null,"deployment displays portrait cards")
 deploy_card.pressed.emit()
 check(not "hero" in scene.selected_ids,"portrait card toggles deployment selection")
 find_button(scene.modal,"沈烬").pressed.emit()
 check("hero" in scene.selected_ids,"portrait card restores deployment selection")
 scene.show_deploy(0)
 scene.begin_battle(0)
 check(scene.battle!=null and scene.campaign.phase=="battle","deployment starts scene battle")
 check(scene.footer.get_child_count()>0,"combat controls exist")
 scene.draw_battle()
 var fixed_size=scene.camera.size
 for direction in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
  var battle_wheel=InputEventMouseButton.new()
  battle_wheel.button_index=direction
  battle_wheel.pressed=true
  scene._unhandled_input(battle_wheel)
 check(scene.camera.size==fixed_size,"battle ignores mouse wheel zoom")
 scene.select_action("move")
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
 scene.campaign.depart()
 scene.refresh_ui()
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

func has_text(node,needle):
 if node is Label and needle in node.text:return true
 for child in node.get_children():
  if has_text(child,needle):return true
 return false
