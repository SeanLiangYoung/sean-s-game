extends SceneTree
const Rules=preload("res://game/rules.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize():
 for tier in range(3):
  var config={"seed":123,"biome":"border","threat":"normal"}
  var normal=Rules.new()
  normal.start_battle(normal.default_party().slice(0,5),tier,[],config)
  check(normal.find_actor("enemy0").max_hp>=34+tier*12,"road enemies exert increased attrition through endurance")
  config.threat="boss"
  var boss=Rules.new()
  boss.start_battle(boss.default_party().slice(0,5),tier,[],config)
  var leader=boss.find_actor("enemy3")
  check(leader.max_hp>=90+tier*12,"boss has increased endurance")
  check(leader.power<=20,"enemy burst remains bounded")
  check(boss.actors.all(func(a):return a.hp==a.max_hp),"enemies start at actual maximum HP")
 print("CHECKS: %d FAILURES: %d"%[checks,failures])
 quit(1 if failures else 0)
