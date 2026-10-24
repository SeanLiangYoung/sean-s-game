extends SceneTree
const Jobs=preload("res://game/professions.gd")
const Relic=preload("res://game/relics.gd")
const Rules=preload("res://game/rules.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func _initialize():
 for skill_id in Jobs.ALL_SKILLS:
  for rank in [1,3]:
   var party=Rules.new().default_party().slice(0,2)
   var hero=party[0];hero.speed=100;hero.max_mp=100;hero.mp=100;hero.skill_ranks[skill_id]=rank
   var b=Rules.new();b.start_battle(party,0);b.obstacles=[]
   var a=b.find_actor("hero");a.cell=Vector2i.ZERO;a.hp=10
   var ally=b.find_actor("blade");ally.cell=Vector2i(-1,0);ally.hp=10;ally.mp=0
   var foe=b.find_actor("enemy0");foe.cell=Vector2i(1,0);foe.hp=500;foe.max_hp=500
   var skill=Jobs.ALL_SKILLS[skill_id]
   var target=Vector2i(0,1) if skill.target=="cell" else (foe.id if skill.target=="enemy" else ally.id)
   check(b.cast(target,skill_id),"cast real skill %s rank%d"%[skill_id,rank])
   check(a.mp>=0 and a.ap>=0,"skill cannot overspend")
   check(not b.cast(target,skill_id),"once per turn: "+skill_id)
 # Mark, gear, relic and following ally attack compose additively.
 var party=Rules.new().default_party().slice(0,3)
 var ranger=party[2];ranger.speed=100
 ranger.merge(Jobs.stats(ranger,[{"id":"mark_bow","owner":"ranger"}]),true);ranger.speed=100
 var b=Rules.new();b.start_battle(party,0,[Relic.instance("focusstone",1,"ranger"),Relic.instance("hunt",2)])
 var a=b.find_actor("ranger");a.cell=Vector2i.ZERO
 var foe=b.find_actor("enemy0");foe.cell=Vector2i(1,0);foe.hp=500;foe.max_hp=500
 check(b.cast(foe.id,"mark") and foe.statuses.mark.bonus==4,"mark bonus comes entirely from personal relic")
 var before=foe.hp;b.deal_damage(b.find_actor("hero"),foe,10)
 check(before-foe.hp==23,"ally gets base mark 5 + stone 4 + team hunt 4")
 # Kill sustain requires actual enemy death and doesn't proc from attacking corpses.
 var hero=Rules.new().default_party()[0];hero.speed=100;hero.mp=0
 hero.merge(Jobs.stats(hero,[{"id":"blood_dagger","owner":"hero"}]),true);hero.speed=100
 b=Rules.new();b.start_battle([hero],0,[Relic.instance("harvest",1,"hero")]);a=b.find_actor("hero");foe=b.find_actor("enemy0");foe.hp=1
 b.deal_damage(a,foe,100)
 check(a.mp==4,"only relic restores kill mana")
 b.deal_damage(a,foe,100);check(a.mp==4,"corpse cannot farm mana")
 # Range-reduction relic never creates zero range; refresh doesn't stack.
 hero=Rules.new().default_party()[0];hero.range=1
 b=Rules.new();b.start_battle([hero],0,[Relic.instance("bulwark",1),Relic.instance("bulwark",2)])
 a=b.find_actor("hero");b.refresh_relic_stats();check(a.range==1,"range clamped and duplicate team relic doesn't stack")
 # Lifesteal scales from real HP loss, not nominal overkill.
 hero=Rules.new().default_party()[0];hero.hp=10;hero.speed=100
 b=Rules.new();b.start_battle([hero],0,[Relic.instance("leech",1,"hero")]);a=b.find_actor("hero");foe=b.find_actor("enemy0");foe.hp=5
 b.deal_damage(a,foe,999);check(a.hp==10,"overkill does not generate inflated healing")
 # Every catalog entry carries a real benefit and risk.
 for id in Relic.CATALOG:
  var d=Relic.CATALOG[id]
  check(not d.benefit.is_empty() and not d.risk.is_empty(),"relic tradeoff "+id)
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
