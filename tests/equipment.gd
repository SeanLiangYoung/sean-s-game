extends SceneTree
const Campaign=preload("res://game/campaign.gd")
var failures=0
var checks=0
func check(value,message):
 checks+=1
 if not value:failures+=1;print("FAIL: ",message)
func _initialize():
 var c=Campaign.new("user://ashbound-equipment-tests.json")
 check(c.has_method("equip_item"),"equipment management exists")
 if not c.has_method("equip_item"):
  quit(1)
  return
 var original=c.roster[0].power
 check(c.equip_item(0,"hero"),"equip from inventory")
 check(c.roster[0].power==original+3,"equipment adds attack")
 check(c.equip_item(0,"hero") and c.roster[0].power==original+3,"reequip cannot stack bonus")
 check(c.equip_item(0,"blade"),"transfer weapon to another character")
 check(c.roster[0].power==original and c.roster[1].power==25,"transfer removes former bonus")
 c.equipment.append({"id":"sword","owner":""})
 check(c.equip_item(1,"blade") and c.equipment[0].owner=="","replacement returns previous weapon")
 check(c.roster[1].power==25,"replacement does not stack")
 check(c.unequip_item("blade") and c.roster[1].power==22,"unequip restores base attack")
 c.roster[1].hp=0
 check(not c.equip_item(0,"blade"),"dead character cannot equip")
 check(not c.equip_item(-1,"hero") and not c.equip_item(0,"missing"),"invalid selections rejected")
 c.equip_item(0,"hero")
 var data=c.to_data()
 var next=Campaign.new()
 check(next.load_data(data) and next.equipment==c.equipment and next.roster[0].power==original+3,"equipment ownership and stats survive load")
 var invalid=data.duplicate(true)
 invalid.equipment[0].owner="unknown"
 check(not next.load_data(invalid),"invalid equipment owner rejected")
 var pending=data.duplicate(true)
 pending.phase="reward"
 pending.choices=[Campaign.REWARDS[0].duplicate(true),Campaign.REWARDS[1].duplicate(true),Campaign.REWARDS[-1].duplicate(true)]
 pending.choices[2].desc="永久强化一名存活队员：攻击 +3"
 check(next.load_data(pending),"legacy pending equipment reward still loads")
 var legacy=data.duplicate(true)
 legacy.erase("equipment")
 check(next.load_data(legacy) and next.equipment.is_empty() and next.roster[0].power==original+3,"legacy permanent upgrades retained")
 c.depart()
 var battle=c.make_battle(["hero"],0)
 check(battle.actors[0].power==original+3,"equipped stats enter combat")
 check(not c.unequip_item("hero") and not c.equip_item(1,"hero"),"combat prevents equipment edits")
 c.phase="reward"
 c.choices=[Campaign.REWARDS[-1]]
 var count=c.equipment.size()
 check(c.choose_reward(0) and c.equipment.size()==count+1,"equipment reward becomes inventory item")
 check(c.roster[0].power==original+3,"reward does not apply hidden permanent bonus")
 print("CHECKS: ",checks," FAILURES: ",failures)
 quit(1 if failures else 0)
