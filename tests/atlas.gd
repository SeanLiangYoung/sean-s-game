extends SceneTree
var checks=0
var failures=0
func check(value: bool):
 checks+=1
 if not value:failures+=1;push_error("atlas check %d"%checks)
func _initialize():call_deferred("run")
func run():
 var scene=load("res://game/main.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 scene.set_process(false)
 scene.campaign=preload("res://game/campaign.gd").new("user://atlas-test.json")
 scene.enter_campaign()
 check(is_instance_valid(scene.atlas) and not scene.atlas.route_mode)
 scene.depart()
 check(scene.selecting_expedition and scene.campaign.phase=="camp")
 scene.show_region("border")
 check(is_instance_valid(scene.modal))
 check(scene.campaign.start_region("border"))
 scene.close_modal()
 scene.campaign.silver=300
 scene.refresh_ui()
 check(scene.atlas.route_mode)
 scene.select_route_node("0b")
 check(is_instance_valid(scene.modal) and scene.campaign.at_node("shop"))
 check(scene.campaign.buy("focus"))
 scene.show_party_menu("物品","hero")
 check(is_instance_valid(scene.modal))
 check(scene.campaign.learn_book(0,"hero"))
 scene.close_modal()
 scene.select_route_node("1b")
 check(scene.campaign.hire(1))
 var recruit=scene.campaign.roster[-1]
 check(recruit.role=="行医者")
 scene.close_modal()
 scene.select_route_node("2b")
 check(is_instance_valid(scene.modal) and not scene.campaign.route.completed)
 check(not scene.campaign.enter_route("3a"))
 scene.begin_battle(1)
 check(scene.battle!=null)
 for u in scene.battle.actors:
  if u.side==1:u.hp=0
 scene.battle.check_outcome()
 scene.after_battle_action()
 check(scene.campaign.phase=="reward")
 check(scene.campaign.choose_reward(0))
 scene.return_world()
 scene.select_route_node("3b")
 check(scene.campaign.route.completed)
 scene.select_route_node("4a")
 check(is_instance_valid(scene.modal))
 check(scene.campaign.extract([]))
 scene.close_modal()
 scene.refresh_ui()
 check(not scene.atlas.route_mode and scene.campaign.phase=="camp")
 var rules=preload("res://game/rules.gd").new()
 rules.start_battle([recruit],0)
 var caster=rules.actors[0]
 rules.order_index=rules.order.find(0)
 caster.cell=Vector2i.ZERO
 caster.hp=20
 check(rules.cast(caster.id))
 check(caster.hp==46)
 scene.queue_free()
 await process_frame
 print("CHECKS: %d FAILURES: %d"%[checks,failures])
 quit(1 if failures else 0)
