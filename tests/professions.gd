extends SceneTree
const Campaign=preload("res://game/campaign.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func _initialize():
 var c=Campaign.new("user://profession-test.json")
 check(c.has_method("change_profession"),"camp retraining exists")
 if not c.has_method("change_profession"):
  print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1);return
 var hero=c.roster[0]
 var medic=c.roster[3]
 check(hero.profession=="hero" and hero.identity=="团长","identity separated from profession")
 medic.hp=20;medic.mp=7
 check(c.change_profession("medic","warden"),"retrain at camp")
 check(medic.hp==20 and medic.mp==7 and medic.profession==c.roster[5].profession,"same profession multiple characters; no healing")
 check(not c.change_profession("medic","hero") and not c.change_profession("hero","medic"),"hero exclusive")
 c.change_profession("medic","medic")
 var plate=-1
 for i in c.equipment.size():
  if c.equipment[i].id=="plate":plate=i
 check(plate>=0,"trial equipment available")
 check(c.equip_item(plate,"medic") and c.character_stats("medic").max_ap==2,"medic plate halves AP")
 check(c.equip_item(plate,"hero") and c.character_stats("hero").max_ap==4,"hero plate no penalty")
 check(c.character_stats("medic").max_ap==4,"transfer removes previous penalty")
 var original=hero.power
 c.equip_item(0,"hero")
 check(hero.power==original+3,"weapon bonus once")
 var data=c.to_data()
 var loaded=Campaign.new("user://profession-loaded.json")
 check(loaded.load_data(data) and loaded.load_data(loaded.to_data()),"repeat load")
 check(loaded.roster[0].power==original+3,"load no stacking")
 var before=loaded.to_data()
 var invalid=data.duplicate(true)
 invalid.roster[1].profession="hero"
 check(not loaded.load_data(invalid) and loaded.to_data()==before,"invalid profession atomic rejection")
 invalid=data.duplicate(true)
 invalid.snapshot={"version":2}
 check(not loaded.load_data(invalid),"invalid nested snapshot rejected")
 var missing_base=data.duplicate(true)
 missing_base.roster[0].erase("base_power")
 check(not loaded.load_data(missing_base),"v2 requires authoritative base stats")
 var wrong_type=data.duplicate(true)
 wrong_type.roster[1].profession=123
 check(not loaded.load_data(wrong_type),"non-string profession safely rejected")
 wrong_type=data.duplicate(true)
 wrong_type.snapshot={"snapshot":123}
 check(not loaded.load_data(wrong_type),"non-dictionary nested snapshot safely rejected")
 var legacy=data.duplicate(true)
 legacy.version=1
 legacy.snapshot={}
 for u in legacy.roster:
  u.erase("profession");u.erase("base_power");u.erase("base_range");u.erase("base_speed")
 legacy.roster[0].role="团长"
 legacy.equipment=[{"id":"sword","owner":"hero"}]
 check(loaded.load_data(legacy) and loaded.roster[0].power==original+3,"legacy sword bonus migrated once")
 c.books=["heal","sniper"]
 check(c.learn_book(0,"hero"),"hero learns another profession skill")
 check(not c.learn_book(0,"medic"),"ordinary profession learning boundary")
 check(c.change_profession("medic","ranger") and c.learn_book(0,"medic"),"learning after retraining")
 c.change_profession("medic","warden")
 check("sniper" in medic.learned,"retraining retains learned skills")
 c.depart()
 check(not c.change_profession("medic","ranger"),"no retraining outside camp")
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
