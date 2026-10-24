extends SceneTree
const Jobs=preload("res://game/professions.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func _initialize():
 var kinds={}
 for id in Jobs.ITEMS:
  var d=Jobs.ITEMS[id]
  check(d.has("tier") and d.get("tier",0) in [1,2,3],"equipment has one of three tiers: "+id)
  check(d.get("mods",{}).is_empty(),"equipment has only basic stats: "+id)
  if not kinds.has(d.kind):kinds[d.kind]={}
  kinds[d.kind][d.get("tier",0)]=d
 for kind in kinds:
  check(kinds[kind].size()==3,"exactly three tiers for "+kind)
  if not kinds[kind].has(1) or not kinds[kind].has(3):continue
  var low=kinds[kind][1];var high=kinds[kind][3]
  check(low.slot==high.slot and low.get("range",0)==high.get("range",0),"same attributes and reach across tiers "+kind)
  check(high.power>=low.power and high.armor>=low.armor and high.power+high.armor>low.power+low.armor,"higher tier improves basic stats "+kind)
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
