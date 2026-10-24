extends SceneTree
var checks=0
var failures=0
func check(value, message):
 checks+=1
 if not value:failures+=1;print("FAIL: ",message)
func _initialize():
 var script=preload("res://game/campaign.gd")
 var c=script.new("user://finale-tests.json")
 check(not c.start_region("ruins"),"final region initially locked")
 check(c.phase=="camp" and c.expedition==0,"locked departure changes nothing")
 if not c.get("cleared_regions") is Array:
  print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1);return
 for region in ["border","wood","waste","frost","marsh","ruins"]:
  check(c.difficulty_level()==mini(6,c.cleared_regions.size()+1),"six progression ranks")
  check(c.start_region(region),"can start "+region)
  var boss=c.route.nodes.filter(func(n):return n.get("threat","")=="boss")[0]
  for depth in range(int(boss.depth)+1):
   c.route.enter("%da"%depth)
   if depth<int(boss.depth):c.route.completed=true
  var battle=c.make_battle(["hero"],int(boss.encounter))
  check(battle!=null,"deploy boss")
  battle.outcome="victory"
  check(c.resolve_battle(battle),"settle boss")
  check(region in c.cleared_regions,"boss records clear")
  check(c.choose_reward(0),"claim reward")
  if region!="ruins":
   check(not c.campaign_completed(),"earlier bosses do not finish campaign")
  else:
   check(c.campaign_completed(),"final boss completes campaign")
   check(c.overall_difficulty in c.completed_difficulties,"final boss settlement unlocks matching difficulty achievement")
   check("全部通关" in c.notice,"final reward preserves victory notice")
  c.phase="camp"
  if c.cleared_regions.size()<5:
   check(not c.start_region("ruins"),"all five distinct clears required")
 var rules=preload("res://game/rules.gd")
 var previous_hp=0
 var previous_power=0
 for rank in range(1,7):
  var battle=rules.new()
  battle.start_battle(battle.default_party().slice(0,5),0,[],{"seed":123,"biome":"border","threat":"normal","campaign_difficulty":rank})
  var enemy=battle.find_actor("enemy0")
  check(enemy.max_hp>previous_hp and enemy.power>previous_power,"each rank increases enemy strength")
  previous_hp=enemy.max_hp;previous_power=enemy.power
 check(c.save_game(),"save progression")
 var loaded=script.new(c.save_path)
 check(loaded.load_game() and loaded.campaign_completed(),"reload preserves completion")
 var data=c.to_data()
 data.cleared_regions=["border","border"]
 check(not loaded.load_data(data),"duplicate clears rejected")
 data=c.to_data();data.erase("cleared_regions")
 check(loaded.load_data(data) and loaded.cleared_regions.is_empty(),"old saves default to no clears")
 print("CHECKS: %d FAILURES: %d"%[checks,failures])
 quit(1 if failures else 0)
