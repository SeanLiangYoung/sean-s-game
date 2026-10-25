extends SceneTree
const Rules=preload("res://game/rules.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:
  failures+=1
  if failures<20:print("FAIL: ",message)
func connected(b,r):
 var open=b.cells().filter(func(c):return b.hex_distance(c,Vector2i.ZERO)<=r and c not in b.obstacles)
 var seen=[Vector2i.ZERO]
 var cursor=0
 while cursor<seen.size():
  var c=seen[cursor];cursor+=1
  for d in b.DIRS:
   if c+d in open and c+d not in seen:seen.append(c+d)
 return seen.size()==open.size()
func _initialize():
 var deployments={}
 var counts={}
 for biome in ["border","wood","waste","frost","marsh","ruins"]:
  var layouts={}
  var total=0
  for seed_value in range(100):
   var config={"seed":seed_value,"biome":biome,"threat":"normal"}
   var b=Rules.new();b.start_battle(b.default_party().slice(0,5),2,[],config)
   var repeat=Rules.new();repeat.start_battle(repeat.default_party().slice(0,5),2,[],config)
   check(b.obstacles==repeat.obstacles and b.actors==repeat.actors,"same seed reproduces battlefield")
   layouts[JSON.stringify(b.obstacles)]=true
   deployments[JSON.stringify(b.actors.map(func(a):return a.cell))]=true
   total+=b.obstacles.size()
   check(b.obstacles.size()>=5 and b.obstacles.size()<=10,"moderate obstacle density")
   check(b.obstacles.all(func(c):return b.hex_distance(c,Vector2i.ZERO)>1),"last seven cells stay clear")
   check(b.actors.all(func(a):return a.cell not in b.obstacles),"unblocked deployment")
   var occupied=b.actors.map(func(a):return a.cell)
   var unique={}
   for c in occupied:unique[c]=true
   check(unique.size()==occupied.size(),"unique spawn cells")
   for a in b.actors:
    check(b.DIRS.any(func(d):return b.is_free(a.cell+d)),"every unit has a free first step")
    for enemy in b.actors:
     if enemy.side!=a.side:check(b.hex_distance(a.cell,enemy.cell)>=3,"no adjacent starting opponents")
   for r in range(1,5):check(connected(b,r),"all terrain connected after each shrink")
   check(b.cells().filter(func(c):return b.hex_distance(c,Vector2i.ZERO)<=2 and c not in b.obstacles).size()>=14,"midgame evacuation capacity")
   b.shrink();b.shrink()
   check(b.actors.all(func(a):return a.hp>0 and b.hex_distance(a.cell,Vector2i.ZERO)<=2),"ten units survive first two evacuations")
   # Radius one has seven cells: exercise evacuation within its actual capacity.
   for i in range(6,b.actors.size()):b.actors[i].hp=0
   b.shrink()
   check(b.actors.slice(0,6).all(func(a):return a.hp>0 and b.hex_distance(a.cell,Vector2i.ZERO)<=1),"six survivors fit final combat ring")
   if seed_value<10:
    for size in range(1,5):
     var small=Rules.new();small.start_battle(small.default_party().slice(0,size),0,[],config)
     check(small.actors.all(func(a):return a.cell not in small.obstacles and small.DIRS.any(func(d):return small.is_free(a.cell+d))),"small parties deploy safely")
  check(layouts.size()>80,"region has varied terrain")
  counts[biome]=total
 check(deployments.size()>80,"deployment and approach direction vary")
 check(counts.wood>counts.waste and counts.ruins>counts.waste,"forest and ruins denser than desert")
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
