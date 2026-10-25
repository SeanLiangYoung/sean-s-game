extends SceneTree
const Campaign=preload("res://game/campaign.gd")
const Plan=preload("res://tools/captain_training_plan.gd")
const Policy=preload("res://tools/relic_mix_simulation.gd")
class MemoryCampaign:
 extends "res://game/campaign.gd"
 func save_game() -> bool:return true
 func sync_achievements():pass
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func _initialize():
 for captain in Campaign.Characters.CAPTAINS:
  var c=MemoryCampaign.new()
  check(c.select_captain(captain),"captain selection")
  var trained=Plan.apply(c)
  var hero=c.roster[0]
  check(trained.error=="" and trained.spent==105 and trained.remaining==0,"same exact budget spent legally")
  check(hero.skill_ranks=={"strike":2,"hero_heal":1,"mark":1},"identical learned skills")
  check(c.roster.slice(1).all(func(u):return u.xp==0 and u.skill_ranks.size()==1),"companions receive no training")
  var b=c.Rules.new()
  b.start_battle([hero,c.roster[3]],0)
  b.obstacles=[]
  b.find_actor("hero").cell=Vector2i.ZERO
  b.find_actor("medic").cell=Vector2i(0,1)
  for i in range(3):
   var enemy=b.find_actor("enemy%d"%i)
   enemy.cell=Vector2i(1+i,-i)
   enemy.hp=300;enemy.max_hp=300
  check(b.active().id=="hero","fixture captain is active")
  if captain=="shen":
   check(b.cast("enemy0","strike"),"strike executes")
   check(b.events.any(func(e):return "余烬接力 · 进军号令" in e),"Shen talent activates")
  elif captain=="wen":
   b.find_actor("medic").hp-=30
   check(Policy.new().step(b),"shared policy uses legal heal")
   check(b.events.any(func(e):return "归途之约 · 保护同伴" in e),"Wen talent activates through shared policy")
   check(b.find_actor("medic").statuses.has("shield"),"Wen shield applies to ally")
  else:
   check(Policy.new().step(b) and "mark" in b.find_actor("hero").used_skills,"shared policy starts with cross-job mark")
   check(Policy.new().step(b),"shared policy follows up with damaging skill")
   check(b.events.any(func(e):return "异式演算 · 法力+4" in e),"Lu talent activates through shared policy")
   check(b.find_actor("hero").mp==16,"mark and strike paid before four mana refund")
 print("CHECKS: %d FAILURES: %d"%[checks,failures])
 quit(1 if failures else 0)
