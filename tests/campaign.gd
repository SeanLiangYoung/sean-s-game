extends SceneTree
var failures = 0
var checks = 0
func check(value, message):
 checks += 1
 if not value:
  failures += 1
  print("FAIL: ", message)
func _initialize():
 var script = load("res://game/campaign.gd")
 if script == null:
  print("FAIL: campaign not implemented")
  quit(1)
  return
 var c = script.new("user://ashbound-tests.json")
 check(c.roster.size() == 6, "six initial recruits")
 check(c.depart(), "can depart from camp")
 var before = c.roster[1].hp
 var b = c.make_battle(["hero","blade","ranger","medic","engineer"],0)
 check(b != null, "can deploy five")
 b.actors[1].hp = 7
 for a in b.actors:
  if a.side == 1: a.hp = 0
 b.check_outcome()
 c.resolve_battle(b)
 check(c.roster[1].hp == 7, "wounds persist")
 check(c.choices.size() == 5, "five rewards")
 check(c.choices[0].id != c.choices[1].id, "distinct reward choices")
 check(c.choose_reward(0,"hero"), "first reward claim accepted")
 check(not c.choose_reward(0,"hero"), "repeat reward claim rejected")
 check(c.make_battle(["hero"],0) == null, "completed encounter cannot retry")
 b = c.make_battle(["blade","ranger"],1)
 check(b != null, "hero may remain in reserve")
 b.round_no = b.round_limit
 b.order_index = b.order.size()-1
 b.finish_turn()
 c.resolve_battle(b)
 check(c.roster[1].hp == 0 and c.roster[2].hp == 0, "deployed die on timeout")
 check(c.roster[0].hp > 0, "reserve hero survives")
 check(c.encounters[1] == "failed", "failure persisted")
 check(c.make_battle(["hero"],1) == null, "failed encounter cannot retry")
 check(c.phase == "world", "survivors return to world")
 c.relics = ["ember","spring","lens"]
 check(not c.extract([0,1,2]), "cannot retain three relics")
 check(c.extract([0,2]), "can retain two relics")
 check(c.collection.size() == 2, "two relics become permanent")
 check(c.phase == "camp", "extraction returns camp")
 var snap = c.snapshot.duplicate(true)
 check(c.restore_snapshot(), "can load departure snapshot")
 check(c.roster[1].hp == before, "snapshot restores deaths and wounds")
 check(c.encounters[0] == "open", "snapshot restores world encounters")
 check(not c.load_data({"version":999}), "invalid save schema rejected")
 print("CHECKS: ",checks," FAILURES: ",failures)
 quit(1 if failures else 0)
