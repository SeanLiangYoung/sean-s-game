extends SceneTree
var failures = 0
var checks = 0
func check(value,message):
 checks += 1
 if not value:
  failures += 1
  print("FAIL: ", message)
func _initialize():
 var script = load("res://game/rules.gd")
 if script == null:
  print("FAIL: rules missing")
  quit(1)
  return
 var r = script.new()
 var party = r.default_party()
 r.start_battle(party.slice(0,5),0)
 var a = r.active()
 var enemy = r.actors.filter(func(u):return u.side == 1)[0]
 var original = a.ap
 check(not r.attack(enemy.id), "out of range attack rejected")
 check(a.ap == original, "invalid attack preserves AP")
 a.mp = 0
 check(not r.cast(enemy.id), "skill without mana rejected")
 r.start_battle(party.slice(0,5),0)
 a = r.active()
 a.hp = a.max_hp-1
 r.rest("hp")
 check(a.hp == a.max_hp,"rest clamps maximum")
 r.start_battle(party.slice(0,5),0)
 var hero = r.actors[0]
 hero.cell = Vector2i(-4,0)
 hero.hp = 2
 r.shrink()
 check(hero.hp == 0,"shrink damage can kill")
 check(r.outcome == "gameover","shrink hero death ends game")
 # Finish round three through the actual turn transition. Lethal tide damage
 # resolves the battle before round_no can advance, even though shrink occurred.
 r.start_battle(party.slice(0,5),0)
 hero = r.actors[0]
 hero.cell = Vector2i(-4,0)
 hero.hp = 2
 r.round_no = 3
 r.order_index = r.order.size()-1
 r.finish_turn()
 check(r.outcome == "gameover" and r.round_no == 3,"lethal first shrink ends game before next round")
 check(r.radius == 3 and r.events.any(func(event):return "灰潮收缩" in event),"first shrink is observable despite unchanged round counter")
 var tide_events = r.events.duplicate()
 r.finish_turn()
 check(r.radius == 3 and r.round_no == 3 and r.events == tide_events,"resolved lethal shrink cannot run twice")
 r.start_battle(party.slice(0,5),0)
 r.round_no = 10
 for u in r.actors:
  if u.side == 1:u.hp = 0
 r.check_outcome()
 check(r.outcome == "victory","victory on final round allowed")
 var count = r.events.size()
 r.finish_turn()
 check(r.outcome == "victory" and r.events.size() == count,"resolved battle cannot advance")
 print("CHECKS: ",checks," FAILURES: ",failures)
 quit(1 if failures else 0)
