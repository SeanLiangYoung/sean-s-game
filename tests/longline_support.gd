extends SceneTree
const Rules=preload("res://game/rules.gd")
const Characters=preload("res://game/characters.gd")
var checks=0
var failures=0
func check(value,message):
 checks+=1
 if not value:failures+=1;print("FAIL: ",message)
func fixture():
 var b=Rules.new();b.start_battle([Characters.create("lu"),Characters.create("bai","medic"),Characters.create("yue","warden")],0)
 b.obstacles=[];b.radius=5
 for u in b.actors:
  if u.side==1:u.cell=Vector2i(4,-2)
 b.find_actor("medic").cell=Vector2i.ZERO
 b.find_actor("hero").cell=Vector2i(1,0)
 b.find_actor("warden").cell=Vector2i(0,1)
 b.order_index=b.order.find(b.actors.find(b.find_actor("medic")))
 b.active().ap=4
 return b
func _initialize():
 var b=fixture()
 check(b.has_method("auto_support_action"),"game auto and study share visible-state support decisions")
 if b.has_method("auto_support_action"):
  var hero=b.find_actor("hero");hero.hp=25
  var before=b.active().mp;var choice=b.call("auto_support_action")
  check(choice.get("skill","")=="heal" and choice.get("target","")=="hero","triage heals endangered captain before damage")
  check(b.auto_action()==choice,"actual game auto uses the shared support decision")
  check(b.active().mp==before and hero.hp==25,"decision query has no mutation or free recovery")
  check(not choice.is_empty() and b.cast(choice.get("target",""),choice.get("skill","")) and b.find_actor("medic").mp==before-6,"healing pays exact real mana and AP")
  b=fixture();var healer=b.active();healer.hp=46
  for e in b.actors:
   if e.side==1:e.cell=Vector2i(1,-1);e.power=18;e.range=2
  choice=b.call("auto_support_action")
  check(choice.get("action","")=="skill" and choice.get("target","")=="medic","incoming pressure triggers healing before fixed missing-20 threshold")
  b=fixture();b.active().mp=0
  for e in b.actors:
   if e.side==1:e.cell=Vector2i(1,-1);e.power=18;e.range=1
  choice=b.call("auto_support_action")
  check(choice.get("action","")=="move","unfunded exposed healer chooses safer position")
  if choice.get("action","")=="move":check(b.call("auto_incoming_pressure",b.active(),choice.target)<b.call("auto_incoming_pressure",b.active(),b.active().cell),"retreat reduces visible pressure")
  b=fixture();choice=b.call("auto_support_action")
  check(choice.is_empty(),"healthy safe party does not waste healing mana")
  b=fixture();b.round_no=3;b.radius=3;b.active().cell=Vector2i(2,0);b.active().hp=10;b.active().mp=0
  for e in b.actors:
   if e.side==1:e.cell=Vector2i(1,0);e.power=18;e.range=1
  choice=b.call("auto_support_action")
  check(choice.get("action","")!="move" or b.hex_distance(choice.target,Vector2i.ZERO)<b.radius,"retreat must not choose the edge that shrinks this round")
  b=fixture();b.find_actor("hero").cell=Vector2i.ZERO
  b.order_index=b.order.find(b.actors.find(b.find_actor("hero")))
  b.active().ap=4;b.active().mp=0;b.active().armor=5
  b.find_actor("medic").cell=Vector2i(-3,1)
  b.find_actor("warden").cell=Vector2i(-3,0)
  for e in b.actors:
   if e.side==1:e.cell=Vector2i(3,0);e.power=20;e.range=1
  choice=b.auto_action()
  check(choice.get("action","")!="move" or b.auto_incoming_pressure(b.active(),choice.target)<b.active().hp*0.75,"captain must not advance into visible lethal focus to chase a future hit")
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
