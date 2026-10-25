extends SceneTree
const Rules=preload("res://game/rules.gd")
const Campaign=preload("res://game/campaign.gd")
var failures=0
var checks=0
func check(value,message):
 checks+=1
 if not value:failures+=1;print("FAIL: ",message)
func _initialize():
 var wins=0
 var total_turns=0
 for difficulty in range(3):
  var c=Campaign.new("user://ashbound-integration-tests.json")
  c.depart()
  var b=c.make_battle(["hero","blade","ranger","medic","engineer"],difficulty)
  var actions=0
  while b.outcome=="" and actions<500:
   actions+=1
   var a=b.active()
   if a.side==1:b.enemy_step();continue
   var enemies=b.actors.filter(func(u):return u.side==1 and u.hp>0)
   enemies.sort_custom(func(x,y):
    var dx=b.hex_distance(a.cell,x.cell)
    var dy=b.hex_distance(a.cell,y.cell)
    return x.hp<y.hp if dx==dy else dx<dy)
   var acted=false
   if a.id=="medic" and a.mp>=8 and a.ap>=3:
    var wounded=b.actors.filter(func(u):return u.side==0 and u.hp>0 and u.hp<u.max_hp-20 and b.hex_distance(a.cell,u.cell)<=3)
    if not wounded.is_empty():acted=b.cast(wounded[0].id)
   if acted:continue
   for enemy in enemies:
    if b.hex_distance(a.cell,enemy.cell)<=a.range and a.ap>=2:
     acted=b.attack(enemy.id);break
    if a.id!="medic" and b.hex_distance(a.cell,enemy.cell)<=3 and a.ap>=3 and a.mp>=8:
     acted=b.cast(enemy.id);break
   if acted:continue
   var candidates=b.cells().filter(func(cell):return b.is_free(cell))
   candidates.sort_custom(func(x,y):return b.hex_distance(x,enemies[0].cell)<b.hex_distance(y,enemies[0].cell))
   for cell in candidates:
    var path=b.path_to(a.cell,cell)
    if not path.is_empty() and path.size()<=maxi(1,a.ap-2):
     acted=b.move_to(cell);break
   if not acted:b.rest("hp")
  check(actions<500,"battle terminates without infinite AI loop")
  check(b.outcome!="","battle has outcome")
  if b.outcome=="victory":wins+=1
  total_turns+=b.round_no
  c.resolve_battle(b)
  if c.phase=="reward":
   c.choose_reward(0,"hero")
   check(c.extract([]),"victory to extraction is playable")
   check(c.phase=="camp","complete loop reaches camp")
  print("SIM difficulty=",difficulty," outcome=",b.outcome," rounds=",b.round_no," radius=",b.radius," actions=",actions)
 # Deep combat can now kill the captain before the tide. Exercise the tide
 # transition independently through real paid turns, without requiring AI mercy.
 var tide=Rules.new();tide.start_battle(tide.default_party().slice(0,5),2)
 var tide_actions=0
 while tide.outcome=="" and tide.radius==4 and tide_actions<100:
  if tide.active().side==0:tide.end_action()
  else:tide.rest("hp")
  tide_actions+=1
 check(tide.radius<4 and tide.events.any(func(event):return "灰潮收缩" in event),"deep encounter first shrink occurs through real turn transitions")
 # Combat may legitimately end before round 3; verify scheduled_tide scheduling independently.
 var scheduled_tide=Rules.new();scheduled_tide.start_battle(scheduled_tide.default_party(),2)
 var captain=scheduled_tide.find_actor("hero");captain.speed=100;captain.cell=Vector2i.ZERO
 scheduled_tide.order=[scheduled_tide.actors.find(captain)];scheduled_tide.order_index=0;scheduled_tide.round_no=2
 scheduled_tide.finish_turn()
 check(scheduled_tide.round_no==3 and scheduled_tide.radius==4,"scheduled_tide remains open before end of round three")
 scheduled_tide.order=[scheduled_tide.actors.find(captain)];scheduled_tide.order_index=0
 scheduled_tide.finish_turn()
 check(scheduled_tide.round_no==4 and scheduled_tide.radius==3,"first scheduled_tide shrinks precisely at end of round three")
 check(scheduled_tide.events.any(func(event):return "灰潮收缩" in event),"first shrink records its actual event")
 check(wins>=1,"at least introductory battle beatable with basic tactics")
 var c=Campaign.new("user://ashbound-integration-tests.json")
 c.depart()
 var data=c.to_data()
 var restored=Campaign.new("user://ashbound-integration-tests.json")
 check(restored.load_data(JSON.parse_string(JSON.stringify(data))),"JSON save round trip")
 check(restored.phase=="world" and restored.roster.size()==6,"round trip retains state")
 check(not restored.load_data({"version":1,"roster":[],"encounters":[]}),"truncated save rejected")
 print("CHECKS: ",checks," FAILURES: ",failures," victories=",wins)
 quit(1 if failures else 0)
