extends SceneTree
const Campaign=preload("res://game/campaign.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func prepare(id):
 var c=Campaign.new("user://reward-settlement-test.json")
 c.depart()
 var b=c.make_battle(["hero","blade"],0)
 b.find_actor("blade").kills=2
 for a in b.actors:
  if a.side==1:a.hp=0
 b.check_outcome();c.resolve_battle(b)
 var reward=Campaign.REWARDS.filter(func(r):return r.id==id)[0]
 c.choices=[reward.duplicate(true),Campaign.REWARDS[-1].duplicate(true),Campaign.REWARDS[-2].duplicate(true)]
 return c
func _initialize():
 var c=prepare("echo")
 var before=c.to_data()
 check(not c.choose_reward(0) and c.to_data()==before,"personal reward waits without consuming state")
 check(not c.choose_reward(0,"missing") and c.to_data()==before,"invalid wearer cannot claim")
 c.roster[1].hp=0
 before=c.to_data()
 check(not c.choose_reward(0,"blade") and c.to_data()==before,"dead wearer cannot claim")
 var xp=c.roster[0].xp
 check(c.choose_reward(0,"hero") and c.phase=="world" and c.choices.is_empty(),"binding finishes settlement")
 check(c.personal_relic("hero").id=="echo","personal relic bound to selected wearer")
 var after=c.to_data()
 check(not c.choose_reward(0,"hero") and c.to_data()==after,"duplicate claim rejected atomically")
 check(c.roster[0].xp==xp,"reward claiming cannot award experience twice")
 var loaded=Campaign.new(c.save_path)
 check(loaded.load_game() and loaded.phase=="world" and loaded.personal_relic("hero").id=="echo","bound reward survives reload")
 c=prepare("banner")
 check(c.choose_reward(0) and c.phase=="world","team reward needs no wearer")
 check(c.relics.size()==1 and c.relics[0].owner=="","team reward remains unbound")
 c=prepare("banner")
 check(c.choose_reward(0,"hero") and c.relics[0].owner=="","generic claim helper never binds team reward")
 c=prepare("silver");var silver=c.silver
 check(c.choose_reward(0) and c.silver==silver+65 and c.phase=="world","silver settles directly")
 c=prepare("medicine");var supplies=c.supplies
 check(c.choose_reward(0) and c.supplies==supplies+2 and c.phase=="world","supplies settle directly")
 c=prepare("sword");var items=c.equipment.size()
 check(c.choose_reward(0) and c.equipment.size()==items+1 and c.phase=="world","equipment settles directly")
 c=prepare("echo")
 check(c.acquire_relic("candle","hero"),"existing wearer item prepared")
 check(c.choose_reward(0,"hero") and c.relics.size()==1 and c.personal_relic("hero").id=="echo","confirmed binding replaces old personal relic once")
 check(c.extract([0]) and c.phase=="camp" and c.collection[0].owner=="hero","reward can be extracted with wearer retained")
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
