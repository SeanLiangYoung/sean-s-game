extends SceneTree
const Campaign=preload("res://game/campaign.gd")
var failures=0
var checks=0
func check(value,message):
 checks+=1
 if not value:failures+=1;print("FAIL: ",message)
func _initialize():
 var c=Campaign.new("user://ashbound-relic-tests.json")
 check(c.has_method("acquire_relic"),"individual relic acquisition and binding implemented")
 if not c.has_method("acquire_relic"):
  print("CHECKS: ",checks," FAILURES: ",failures);quit(1);return
 check(c.Relic.CATALOG.size()==15,"fifteen designed relics")
 c.depart()
 check(not c.acquire_relic("echo"),"personal relic requires explicit owner")
 check(c.acquire_relic("echo","blade"),"personal relic binds on acquisition")
 check(c.personal_relic("blade").id=="echo","personal slot holds relic")
 check(c.acquire_relic("candle","blade"),"new personal relic replaces old")
 check(c.relics.size()==1 and c.personal_relic("blade").id=="candle","replaced relic exits inventory")
 check(c.acquire_relic("banner"),"team relic automatically acquired")
 var b=c.make_battle(["hero","blade"],0)
 var blade=b.find_actor("blade")
 var hero=b.find_actor("hero")
 check(b.relic_modifier(hero,"damage")==8 and b.relic_modifier(blade,"damage")==8,"team affects every ally")
 var enemy=b.find_actor("enemy0")
 check(b.relic_modifier(enemy,"damage")==0,"team excludes enemies")
 b.lose_hp(blade,999)
 check(blade.hp==1 and blade.mp==0,"candle prevents lethal once and drains mana")
 check(b.relic_state.filter(func(r):return r.id=="candle").is_empty(),"last trigger destroys candle immediately")
 b.lose_hp(blade,999)
 check(blade.hp==0,"destroyed candle cannot trigger twice")
 for a in b.actors:
  if a.side==1:a.hp=0
 b.check_outcome();c.resolve_battle(b)
 check(c.personal_relic("blade").is_empty(),"battle destruction clears personal slot")
 c.phase="world"
 check(c.acquire_relic("echo","hero"),"can bind another limited relic")
 c.personal_relic("hero").remaining=2
 check(c.save_game(),"save limited instances")
 var loaded=Campaign.new(c.save_path)
 check(loaded.load_game(),"load instance save")
 check(loaded.personal_relic("hero").remaining==2,"reload preserves remaining charges")
 var bad=c.to_data();bad.relics[-1].remaining=-2
 check(not loaded.load_data(bad),"invalid remaining count rejected")
 var legacy=c.to_data();legacy.version=3;legacy.relics=["ember","spring","lens"];legacy.collection=[]
 check(loaded.load_data(legacy),"legacy string relic saves migrate")
 check(loaded.active_relics().size()==3,"legacy relics retained")
 print("CHECKS: ",checks," FAILURES: ",failures)
 quit(1 if failures else 0)
