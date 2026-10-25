extends SceneTree
const Route=preload("res://game/route.gd")
const Campaign=preload("res://game/campaign.gd")
const Rules=preload("res://game/rules.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func _initialize():
 check(Route.REGIONS.size()==6,"six regions")
 if Route.REGIONS.size()!=6:
  finish();return
 var signatures={}
 var layouts={}
 for region in Route.REGIONS:
  for seed_value in range(30):
   var r=Route.new();r.call("setup",region.id,seed_value)
   var stages=r.nodes[-1].depth+1
   check(stages>=7 and stages<=9,"bounded expedition length")
   check(r.nodes.filter(func(n):return n.depth==stages-2).all(func(n):return n.kind=="battle" and n.threat=="boss"),"mandatory final boss")
   check(r.nodes.filter(func(n):return n.depth==stages-3).all(func(n):return n.kind in ["shop","supply"]),"recovery before boss")
   check(r.nodes.filter(func(n):return n.depth==1).all(func(n):return n.kind!="battle"),"early recovery")
   check(r.nodes.all(func(n):return n.kind!="battle" or n.tier in [0,1,2]),"bounded enemy tier")
   var restored=Route.new()
   check(restored.restore(JSON.parse_string(JSON.stringify(r.data()))) and restored.nodes==r.nodes,"seeded route survives JSON")
   signatures[JSON.stringify(r.nodes)]=true
   for n in r.nodes:
    if n.kind!="battle":continue
    var b=Rules.new();b.call("start_battle",Rules.new().default_party().slice(0,5),n.tier,[],n)
    layouts[JSON.stringify(b.obstacles)]=true
    check(b.actors.size()<=10 and b.actors.size()>=8,"3-5 bounded enemies")
    check(b.actors.all(func(a):return a.cell not in b.obstacles),"no blocked spawns")
    check(b.actors.all(func(a):return a.side==0 or a.power<=20),"bounded enemy burst")
    for a in b.actors:
     if a.side!=0:continue
     var adjacent=b.DIRS.map(func(d):return a.cell+d)
     check(adjacent.any(func(cell):return b.is_free(cell)),"each ally can leave spawn")
     var reachable=b.cells().filter(func(cell):return b.is_free(cell) and cell.x>=0 and not b.path_to(a.cell,cell).is_empty())
     check(not reachable.is_empty(),"ally can reach central/enemy zone")
 check(signatures.size()>100 and layouts.size()>8,"seed variation changes routes and boards")
 var c=Campaign.new("user://generated-expedition.json");c.rng.seed=12
 check(c.start_region("frost"),"new biome starts")
 var data=c.to_data();var loaded=Campaign.new()
 check(loaded.load_data(JSON.parse_string(JSON.stringify(data))) and loaded.route.nodes==c.route.nodes,"campaign round trip")
 var malformed=data.duplicate(true);malformed.route.seed="bad"
 check(not loaded.load_data(malformed),"invalid seed rejected atomically")
 var battle_nodes=c.route.nodes.filter(func(n):return n.kind=="battle")
 var ids=battle_nodes.map(func(n):return n.encounter)
 check(ids.size()==c.encounters.size() and ids.size()>3,"encounters tracked individually beyond old limit")
 # Walk every step, settle battles, then extract; ensures final indices work.
 for depth in range(c.route.nodes[-1].depth+1):
  var choices=c.route.available()
  check(not choices.is_empty() and c.enter_route(choices[0]),"enter generated stage")
  var n=c.route.node(c.route.current)
  if n.kind=="battle":
   var b=c.make_battle(["hero","blade","ranger","medic","warden"],n.encounter)
   check(b!=null,"generated encounter can deploy")
   if b==null:continue
   for a in b.actors:
    if a.side==1:a.hp=0
   b.check_outcome();check(c.resolve_battle(b),"generated battle settlement")
   check(c.choices.size()==5 and c.choices.map(func(choice):return choice.type).has("equipment") and c.choices.map(func(choice):return choice.type).has("resource") and c.choices.map(func(choice):return choice.type).has("relic"),"balanced reward categories")
   var saved=Campaign.new();check(saved.load_data(JSON.parse_string(JSON.stringify(c.to_data()))) and saved.choices==c.choices,"pending choices persist")
   check(c.choose_reward(0,"hero"),"choose generated reward")
  if n.kind=="shop":
   c.silver=500
   var stock=c.shop_inventory()
   check(stock.size()>=6 and stock.size()<=8,"limited shop stock")
   check(not c.buy("not-stocked"),"unknown or unstocked goods rejected")
   var other=Campaign.new();check(other.load_data(JSON.parse_string(JSON.stringify(c.to_data()))) and other.shop_inventory()==stock,"stock fixed after reload")
   var item=stock[0]
   check(c.buy(item,"hero" if Campaign.Relic.CATALOG.has(item) and Campaign.Relic.CATALOG[item].scope=="personal" else ""),"stock purchase succeeds")
   check(not c.buy(item,"hero"),"one purchase per good")
 check(c.extract([]),"generated route can finish")
 var legacy=Route.new();legacy.setup("border")
 check(legacy.nodes.size()==10 and legacy.restore({"region":"border","current":"0b","completed":true,"visited":["0b"]}),"old five-stage route preserved")
 finish()
func finish():
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
