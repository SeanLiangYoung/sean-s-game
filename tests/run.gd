extends SceneTree
var failures := 0
var checks := 0
func check(value: bool, message: String):
 checks += 1
 if not value:
  failures += 1
  print("FAIL: ", message)
func _initialize():
 var script = load("res://game/rules.gd")
 if script == null:
  print("FAIL: tactical rules not implemented")
  quit(1)
  return
 var r = script.new()
 var party = r.default_party()
 r.start_battle(party.slice(0, 5), 0)
 check(r.actors.size() == 8, "five deployed and three enemies")
 check(r.active().speed == 15, "fastest actor starts")
 var actor = r.active()
 actor.hp = 20
 actor.mp = 0
 var before = actor.hp
 r.rest("hp")
 check(actor.hp > before and actor.mp == 0, "rest restores HP only")
 check(actor.ap == 0, "rest consumes all AP")
 r.start_battle(party.slice(0, 5), 0)
 actor = r.active()
 actor.hp = 20
 actor.mp = 0
 r.rest("mp")
 check(actor.hp == 20 and actor.mp > 0, "rest restores MP only")
 r.start_battle(party.slice(0, 5), 0)
 actor = r.active()
 var cell = actor.cell
 check(not r.move_to(Vector2i(99,99)), "invalid movement rejected")
 check(actor.ap == 4 and actor.cell == cell, "invalid move consumes nothing")
 r.round_no = r.round_limit
 r.order_index = r.order.size()-1
 r.finish_turn()
 check(r.outcome == "gameover", "deadline kills deployed hero and ends game")
 check(r.actors.filter(func(a): return a.side == 0 and a.hp > 0).is_empty(), "timeout kills all deployed")
 r.start_battle(party.slice(1, 3), 0)
 r.radius = 1
 for a in r.actors:
  a.cell = Vector2i(5,0)
 r.shrink()
 var live = r.actors.filter(func(a): return a.hp > 0)
 check(live.size() <= 1, "no shrink destinations kills overflow")
 r.start_battle(party.slice(0, 2), 0)
 r.actors[0].hp = 0
 r.check_outcome()
 check(r.outcome == "gameover", "hero death ends game")
 print("CHECKS: ", checks, " FAILURES: ", failures)
 quit(1 if failures else 0)
