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
 check(scene.get("art")!=null,"dedicated visual factory exists")
 if scene.get("art")==null:
  print("CHECKS: ",checks," FAILURES: ",failures)
  quit(1)
  return
 scene.campaign=load("res://game/campaign.gd").new("user://ashbound-art-tests.json")
 scene.campaign.depart()
 scene.show_deploy(0)
 scene.begin_battle(0)
 var before=scene.battle.actors.duplicate(true)
 check(scene.scene_root.find_child("BattleLandscape",true,false)!=null,"battle has landscape scenery")
 check(scene.scene_root.find_child("BrokenBridge",true,false)!=null,"battle has original stone bridge")
 check(scene.scene_root.find_child("WindGrass",true,false)!=null,"battle has instanced wind grass")
 check(scene.scene_root.find_child("GreyTide",true,false)!=null,"battle has tide boundary")
 scene._process(0.5)
 check(scene.battle.actors==before,"visual animation preserves tactical state")
 scene.battle.round_no=3
 scene.draw_battle()
 scene.battle.shrink()
 scene.draw_battle()
 check(scene.scene_root.find_children("BattleLandscape","",false,false).size()==1,"rebuild removes previous landscape")
 check(scene.scene_root.find_children("GreyTide","",false,false).size()==1,"rebuild removes previous tide")
 check(scene.scene_root.find_child("WindGrass",true,false)!=null,"vegetation survives shrink rebuild")
 var meadow=scene.scene_root.find_child("Meadow",true,false)
 check(meadow!=null and meadow.material_override.get_shader_parameter("safe_radius")==3.0,"ash terrain follows current safe radius")
 print("CHECKS: ",checks," FAILURES: ",failures)
 quit(1 if failures else 0)
