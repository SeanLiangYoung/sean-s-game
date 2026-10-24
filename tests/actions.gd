extends SceneTree
var checks=0
var failures=0
func check(value: bool):
 checks+=1
 if not value:failures+=1;push_error("action check %d"%checks)
func _initialize():call_deferred("run")
func run():
 var rules=preload("res://game/rules.gd").new()
 rules.start_battle(rules.default_party().slice(0,2),0)
 var a=rules.active()
 a.hp=10
 check(rules.has_method("use_medicine"))
 if not rules.has_method("use_medicine"):
  print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1);return
 var ap=a.ap
 check(not rules.use_medicine("enemy0"))
 check(a.ap==ap)
 check(rules.use_medicine(a.id))
 check(a.ap==ap-2 and a.hp==10+int(a.max_hp*0.3))
 var hp=a.hp
 check(rules.end_action())
 check(a.ap==0 and a.hp==hp)
 var scene=load("res://game/main.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 scene.set_process(false)
 scene.close_modal()
 scene.campaign=preload("res://game/campaign.gd").new("user://actions-test.json")
 scene.campaign.depart()
 scene.selected_ids=["hero","blade"]
 scene.begin_battle(0)
 check(scene.battle_mode=="")
 scene.select_action("skills")
 check(scene.battle_mode=="skills")
 var current=scene.battle.active()
 var before=current.ap
 scene.select_action("skill")
 var escape=InputEventKey.new()
 escape.keycode=KEY_ESCAPE
 escape.pressed=true
 scene._unhandled_input(escape)
 check(scene.battle_mode=="" and current.ap==before)
 check(not is_instance_valid(scene.modal))
 scene.campaign.supplies=0
 current.hp=10
 check(not scene.perform_battle_action("item",current.id))
 scene.campaign.supplies=2
 check(scene.perform_battle_action("item",current.id))
 check(scene.campaign.supplies==1)
 check(not scene.perform_battle_action("item",current.id))
 scene.presentation.advance(4)
 check(scene.battle_mode=="")
 check(scene.perform_battle_action("end"))
 scene.presentation.advance(4)
 check(current.ap==0)
 scene.queue_free()
 await process_frame
 print("CHECKS: %d FAILURES: %d"%[checks,failures])
 quit(1 if failures else 0)
