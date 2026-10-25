extends SceneTree
const Campaign=preload("res://game/campaign.gd")
const Relic=preload("res://game/relics.gd")
const Rules=preload("res://game/rules.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func _initialize():
 var relic_api=Relic.new()
 check(relic_api.has_method("draft_rewards"),"relic draft supports continuation and alternative themes")
 if relic_api.has_method("draft_rewards"):
  var family_hits={}
  for seed_value in range(320):
   var rng=RandomNumberGenerator.new();rng.seed=seed_value
   var ids=relic_api.call("draft_rewards",rng,[],[])
   check(ids.size()==3 and ids[0]!=ids[1] and ids[1]!=ids[2] and ids[0]!=ids[2],"draft has three unique IDs")
   var first=Relic.definition(ids[0]);var second=Relic.definition(ids[1])
   check(first.scope=="team" and second.scope=="team" and first.get("family","")!="" and first.family!=second.family,"opening draft offers two distinct team foundations")
   family_hits[first.family]=family_hits.get(first.family,0)+1
   var held=[Relic.instance("blood_1",1),Relic.instance("blood_2",2)]
   ids=relic_api.call("draft_rewards",rng,held,held)
   check(Relic.definition(ids[0]).get("family","")=="blood" and Relic.definition(ids[0]).scope=="team","first reward advances current expedition theme")
   check(ids.all(func(id):return id not in ["blood_1","blood_2"]),"draft excludes all already owned IDs")
   check(Relic.definition(ids[1]).get("family","")!="blood","draft preserves cross-theme choice")
   var saved_state=rng.state
   var repeated=relic_api.call("draft_rewards",rng,held,held)
   rng.state=saved_state
   check(relic_api.call("draft_rewards",rng,held,held)==repeated,"saved RNG reproduces draft exactly")
   # Permanent collection must not dictate every subsequent expedition.
   var collection=[]
   for i in range(1,6):collection.append(Relic.instance("ward_%d"%i,10+i))
   ids=relic_api.call("draft_rewards",rng,held+collection,held)
   check(Relic.definition(ids[0]).get("family","")=="blood","current expedition outranks permanent collection for focus")
  check(family_hits.size()==8,"all eight opening themes appear")
  for family in family_hits:check(family_hits[family]>=20 and family_hits[family]<=65,"opening themes remain diverse: "+family)
 # Single team items may grant actions, but a pile of AP relics must not become compulsory.
 var b=Rules.new();b.start_battle(b.default_party().slice(0,5),2,[Relic.instance("hourglass",1),Relic.instance("command_4",2),Relic.instance("command_10",3,"hero"),Relic.instance("command_1",4),Relic.instance("command_2",5),Relic.instance("command_3",6)])
 check(b.find_actor("hero").max_ap<=6,"stacked action economy is capped at +2 AP per actor")
 var c=Campaign.new()
 var legacy=c.to_data();legacy.version=6;legacy.phase="reward"
 legacy.choices=[Campaign.REWARDS.filter(func(r):return r.id=="hourglass")[0].duplicate(true),Campaign.REWARDS[-1].duplicate(true),Campaign.REWARDS[-2].duplicate(true)]
 legacy.choices[0].desc="全队遗物\n收益：全队每次行动的行动点 +1\n代价：全队攻击与直接伤害战技 -4\n持续生效"
 check(Campaign.new().load_data(legacy),"version6 pending rewards migrate after balance descriptions change")
 var previous_balance=c.to_data();previous_balance.version=7
 for unit in previous_balance.roster:unit.erase("character_id")
 check(Campaign.new().load_data(previous_balance),"balance-only v7 saves remain loadable alongside character identity expansion")
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
