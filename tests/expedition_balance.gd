extends SceneTree
const Campaign=preload("res://game/campaign.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
# A simple visible-rules policy: heal wounded allies, focus fire, advance preserving attack AP.
func play(b):
 var steps=0
 while b.outcome=="" and steps<500:
  steps+=1
  var a=b.active()
  if a.side==1:b.enemy_step();continue
  var enemies=b.actors.filter(func(u):return u.side==1 and u.hp>0)
  enemies.sort_custom(func(x,y):return b.hex_distance(a.cell,x.cell)<b.hex_distance(a.cell,y.cell))
  var acted=false
  if a.id=="medic":
   var wounded=b.actors.filter(func(u):return u.side==0 and u.hp>0 and u.max_hp-u.hp>=20 and b.can_cast("heal",u.id))
   wounded.sort_custom(func(x,y):return x.hp<y.hp)
   if not wounded.is_empty():acted=b.cast(wounded[0].id,"heal")
  if acted:continue
  for t in enemies:
   if a.ap>=2 and b.hex_distance(a.cell,t.cell)<=a.range:acted=b.attack(t.id);break
   if a.id in ["hero","blade"] and b.can_cast(b.default_skill(a),t.id):acted=b.cast(t.id);break
  if acted:continue
  var candidates=b.cells().filter(func(c):return b.is_free(c))
  candidates.sort_custom(func(x,y):return b.hex_distance(x,enemies[0].cell)<b.hex_distance(y,enemies[0].cell))
  for cell in candidates:
   if b.hex_distance(cell,enemies[0].cell)>=b.hex_distance(a.cell,enemies[0].cell):continue
   var path=b.path_to(a.cell,cell)
   if not path.is_empty() and path.size()<=maxi(1,a.ap-2):acted=b.move_to(cell);break
  if not acted:b.rest("mp" if a.mp<a.max_mp/2 else "hp")
 return steps
func _initialize():
 var clears=0
 var wins=0
 var battles=0
 var max_round=0
 for region in Campaign.Route.REGIONS:
  var c=Campaign.new("user://balance-"+region.id+".json");c.rng.seed=21
  for pair in [[0,"hero"],[1,"blade"],[2,"ranger"],[3,"medic"],[4,"engineer"],[5,"hero"],[6,"blade"]]:c.equip_item(pair[0],pair[1])
  c.cleared_regions=(["border","wood","waste","frost","marsh"] if region.id=="ruins" else []);c.start_region(region.id)
  var route_length=c.route.nodes[-1].depth+1
  for depth in range(route_length):
   var options=c.route.available().map(func(id):return c.route.node(id))
   if options.is_empty():break
   # Take first battle, optional elites, and recovery when possible elsewhere.
   var selected=options[0]
   for n in options:
    if n.kind=="battle":selected=n;break
    if n.kind=="supply":selected=n
   c.enter_route(selected.id)
   if selected.kind=="battle":
    var b=c.make_battle(["hero","blade","ranger","medic","engineer"].filter(func(id):return c.roster.any(func(u):return u.id==id and u.hp>0)),selected.encounter)
    check(b!=null,"deploy "+region.id)
    if b==null:break
    var steps=play(b);battles+=1;max_round=maxi(max_round,b.round_no)
    check(steps<500 and b.outcome!="","battle terminates "+region.id)
    if b.outcome=="victory":wins+=1
    c.resolve_battle(b)
    if c.phase=="reward":c.choose_reward(c.choices.size()-1)
    else:break
   if c.phase=="world":
    while c.supplies>0 and c.roster.any(func(u):return u.hp>0 and (u.hp<u.max_hp*0.7 or u.mp<u.max_mp*0.5)):c.use_supply()
  var cleared=c.route.nodes.filter(func(n):return n.get("threat","")=="boss" and c.encounters[n.encounter]=="cleared").size()>0
  if cleared:
   clears+=1
   check(c.extract([]),"full expedition can extract "+region.id)
  print("REGION ",region.id," boss_cleared=",cleared)
 print("BALANCE: victories=%d/%d max_round=%d"%[wins,battles,max_round])
 # This deliberately basic attack/heal policy is a regional smoke check.
 # The actual Auto planner is calibrated separately over 100 fresh border runs.
 check(clears>=2 and float(wins)/battles>=0.8 and battles>=18,"starter policy remains viable across regions at increased difficulty")
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
