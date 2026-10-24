extends SceneTree
const Campaign=preload("res://game/campaign.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func texts(node):
 var result=node.text+"\n" if node is Label or node is Button else ""
 for child in node.get_children():result+=texts(child)
 return result
func _initialize():call_deferred("run")
func run():
 var scene=load("res://game/main.tscn").instantiate();root.add_child(scene);await process_frame
 scene.set_process(false);scene.close_modal()
 check(scene.has_method("apply_region_style"),"regional presentation interface exists")
 if not scene.has_method("apply_region_style"):
  scene.queue_free();await process_frame;finish();return
 var colors={}
 var themes={}
 for id in ["border","wood","waste","frost","marsh","ruins"]:
  scene.campaign=Campaign.new("user://region-scene-"+id+".json");scene.campaign.cleared_regions=(["border","wood","waste","frost","marsh"] if id=="ruins" else []);scene.campaign.start_region(id)
  scene.show_region(id)
  check("搭配" in texts(scene.modal) and "首领" in texts(scene.modal),"region counter briefing "+id)
  scene.close_modal()
  var boss=scene.campaign.route.nodes.filter(func(n):return n.get("threat","")=="boss")[0]
  scene.campaign.route.current=boss.id;scene.campaign.route.completed=false
  scene.show_deploy(boss.encounter)
  check("敌人特性" in texts(scene.modal) and "预告" in texts(scene.modal),"deployment explains mechanics "+id)
  scene.begin_battle(boss.encounter);scene.close_modal();scene.draw_battle();scene.refresh_ui()
  var landscape=scene.scene_root.find_child("BattleLandscape",true,false)
  check(landscape!=null and landscape.get_meta("biome","")==id,"landscape identity "+id)
  var meadow=landscape.find_child("Meadow",true,false)
  colors[str(meadow.material_override.get_shader_parameter("base_color"))]=true
  themes[landscape.get_meta("theme","")]=true
  check(landscape.find_child("RegionLandmark",true,false)!=null,"distinct landmark "+id)
  var enemy=scene.battle.actors[-1]
  var pawn=scene.scene_root.get_node("Character_"+enemy.id)
  check(pawn.get_meta("regional_enemy","")==id and pawn.find_child("BossInsignia",true,false)!=null,"boss silhouette and regional loadout "+id)
  scene.battle.order_index=scene.battle.order.find(scene.battle.actors.find(enemy));enemy.ap=4
  # Exercise warning rendering directly; tactical selection has its own rule tests.
  check(scene.battle.cast_enemy_skill(id+"_intent"),"legal boss preparation for warning fixture "+id)
  scene.draw_battle();scene.refresh_ui()
  var warnings=scene.scene_root.find_children("BossWarning*","",true,false)
  check(not warnings.is_empty() and "预告" in texts(scene.sidebar),"visible warning and readable timeline "+id)
  scene.battle.shrink();scene.draw_battle()
  check(scene.scene_root.find_child("BattleLandscape",true,false).find_child("Meadow",true,false).material_override.get_shader_parameter("safe_radius")==3.0,"regional scene preserves shrinking visuals")
  scene.battle=null
 check(colors.size()==6 and themes.size()==6,"six ground palettes and landmarks")
 scene.campaign=Campaign.new();scene.campaign.depart();scene.draw_world()
 check(scene.get_node("WorldEnvironment").environment.background_color==Color("b6c7bc"),"world style restored after battle")
 scene.queue_free();await process_frame;finish()
func finish():
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
