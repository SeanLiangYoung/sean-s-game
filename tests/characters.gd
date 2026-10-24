extends SceneTree
var checks=0
var failures=0
func check(value,message):
 checks+=1
 if not value:failures+=1;print("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
 var visual=load("res://game/character_visual.gd")
 for role in ["hero","blade","ranger","medic","engineer","warden","enemy0","enemy1","enemy2","enemy3","enemy4"]:
  var pawn=Node3D.new()
  root.add_child(pawn)
  visual.create(pawn,role)
  check(pawn.get_meta("asset_pack","")=="quaternius_rpg","new human-proportion model: "+role)
  check(pawn.find_child("Skeleton3D",true,false)!=null,"humanoid rig exists: "+role)
  var player=pawn.find_child("AnimationPlayer",true,false)
  for action in ["idle","move","attack","skill","hit","death","rest_hp","rest_mp"]:
   player.stop()
   visual.play(pawn,action)
   check(player.is_playing(),"logical action resolves: "+role+" "+action)
  if role=="enemy2":
   visual.play(pawn,"attack")
   check(player.current_animation=="Bow_Shoot","enemy archer uses bow animation")
  if visual.has_method("effect_style"):
   check(visual.effect_style(pawn,"skill")==("heal" if role=="medic" else ("arrow" if role in ["ranger","engineer","enemy2"] else "slash")),"role skill effect: "+role)
  else:check(false,"effect profiles exist")
  player.stop()
  pawn.queue_free()
  await process_frame
 await process_frame
 print("CHECKS: ",checks," FAILURES: ",failures)
 quit(1 if failures else 0)
