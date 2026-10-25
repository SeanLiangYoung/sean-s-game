extends SceneTree
var checks=0
var failures=0
func check(ok: bool,label: String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label)
func _initialize():
 check(ResourceLoader.exists("res://game/relic_strategy.gd"),"strategy advisor exists")
 if not ResourceLoader.exists("res://game/relic_strategy.gd"):finish();return
 var s=load("res://game/relic_strategy.gd")
 var relic=load("res://game/relics.gd")
 var held=[relic.instance("hunt_1",1),relic.instance("hunt_6",2,"ranger"),relic.instance("ward_6",3,"medic")]
 var before=held.duplicate(true)
 check(s.applicable(held,"hero").size()==1,"personal relics do not leak across actors")
 check(s.compare(held,"hunt_2","hero").activated==[2],"team second activates threshold")
 check(s.compare(held,"hunt_2","ranger").activated.is_empty(),"already activated threshold not falsely announced")
 check(s.compare(held,"hunt_7","").requires_owner,"unbound personal requires owner choice")
 var change=s.compare(held,"ward_7","ranger")
 check(change.lost==[2] and change.replaced=="hunt_6","replacement loses old resonance")
 check(change.after.get("ward",0)==1 and change.after.get("hunt",0)==1,"replacement counts actual owner only")
 check(held==before,"advisor never mutates inventory")
 var exhausted=relic.instance("echo",4,"hero");exhausted.remaining=0
 check(s.applicable([exhausted],"hero").is_empty(),"exhausted entries excluded")
 check(s.applicable([held[0],held[0]],"hero").size()==1,"duplicate IDs count once")
 check(s.compare(held,"hunt_1","hero").activated.is_empty(),"duplicate team relic adds no resonance")
 check(not s.lore("ember").is_empty() and s.lore("bad")=="","base relic lore valid")
 for family in relic.Expansion.SETS:
  check(not s.tactic(family).is_empty(),"theme has usable tactic: "+family)
 var host=AdvisorHost.new()
 host.campaign.relics=[relic.instance("hunt_1",1),relic.instance("hunt_2",2),relic.instance("hunt_6",3,"ranger")]
 var hint=s.reward_hint(host,"hunt_3")
 check("全队底座" in hint and "4件" in hint and "鸦" in hint and relic.Expansion.SETS.hunt.four_desc in hint,"reward hint identifies actual owner's four-piece activation")
 var state=[relic.instance("hunt_1",1),relic.instance("hunt_2",2),relic.instance("hunt_3",3)]
 check(s.compare(state,"hunt_6","hero").activated==[4],"four-piece threshold")
 # Compare with the actual combat filtering and resonance calculator.
 var rules=load("res://game/rules.gd").new()
 var party=load("res://game/characters.gd").starting_party()
 rules.start_battle(party.slice(0,3),0,held)
 for actor in rules.actors:
  if actor.side==0:
   check(relic.resonance_counts(s.applicable(held,actor.id))==relic.resonance_counts(rules.applicable_relics(actor)),"advice matches real battle for "+actor.id)
 finish()
func finish():
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)

class AdvisorHost extends RefCounted:
 var campaign=preload("res://game/campaign.gd").new("user://strategy-preview-test.json")
