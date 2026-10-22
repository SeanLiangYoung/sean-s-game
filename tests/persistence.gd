extends SceneTree
const Campaign=preload("res://game/campaign.gd")
var failures=0
var checks=0
func check(value,message):
 checks+=1
 if not value:failures+=1;print("FAIL: ",message)
func _initialize():
 var c=Campaign.new()
 check("save_path" in c,"campaign supports independent save destination")
 if not "save_path" in c:
  print("CHECKS: ",checks," FAILURES: ",failures)
  quit(1)
  return
 c.save_path="user://ashbound-test-persistence.json"
 c.depart()
 c.silver=123
 check(c.save_game(),"atomic local save succeeds")
 var next=Campaign.new()
 next.save_path=c.save_path
 check(next.load_game(),"saved campaign loads")
 check(next.silver==123 and next.phase=="world","state retained from independent save")
 var malformed=c.to_data()
 malformed.world_position=["bad",0]
 check(not next.load_data(malformed),"invalid coordinate types rejected")
 malformed=c.to_data()
 malformed.roster[0].hp="bad"
 check(not next.load_data(malformed),"invalid health types rejected")
 malformed=c.to_data()
 malformed.encounters[0]="bad"
 check(not next.load_data(malformed),"invalid encounter states rejected")
 print("CHECKS: ",checks," FAILURES: ",failures)
 quit(1 if failures else 0)
