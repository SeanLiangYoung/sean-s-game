extends SceneTree
const Study=preload("res://tools/fresh_run_simulation.gd")
const Relic=preload("res://game/relics.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func finish_win(c,ids,index):
 var b=c.make_battle(ids,index)
 if b==null:return false
 for unit in b.actors:
  if unit.side==1:unit.hp=0
 b.check_outcome()
 return c.resolve_battle(b)
func _initialize():
 var study=Study.new();var c=study.create("shen",2026102600)
 c.start_region("border")
 var first=c.route.available().map(func(id):return c.route.node(id)).filter(func(node):return node.kind=="battle")[0]
 c.enter_route(first.id)
 var ids=study.deployed(c,"balanced")
 check(finish_win(c,ids,first.encounter),"actual generated victory settlement")
 var medic=c.roster.filter(func(unit):return unit.id=="medic")[0]
 check(medic.xp==40,"first generated win awards 40 earned XP to a non-killer in a five-person team")
 c.choose_reward(c.choices.map(func(choice):return choice.type).find("resource"))
 var recovery=c.route.available().map(func(id):return c.route.node(id)).filter(func(node):return node.kind=="supply" or node.kind=="event")[0]
 c.enter_route(recovery.id)
 var second=c.route.available().map(func(id):return c.route.node(id)).filter(func(node):return node.kind=="battle")[0]
 c.enter_route(second.id);check(finish_win(c,ids,second.encounter),"second generated win pays real XP")
 c.choose_reward(c.choices.map(func(choice):return choice.type).find("resource"))
 check(c.train_skill("medic","heal") and c.train_skill("medic","cleanse"),"two real wins fund basic rank2 plus one branch without kill XP")
 c=study.create("shen",2026102600)
 check(c.has_method("shop_price"),"contextual shop price is a public gameplay API")
 if c.has_method("shop_price"):
  check(c.call("shop_price","ward_1")==55 and c.call("shop_price","fury")==35,"first relic saves 15 silver; books are unchanged")
  c.purchases=["0b:fury"]
  check(c.call("shop_price","ward_1")==55,"non-relic purchases do not consume first-relic discount")
  c.purchases.append("3a:ward_1")
  check(c.call("shop_price","arcane_1")==70,"later relics pay full price across shops")
  var data=c.to_data();var restored=study.create("shen",1)
  check(restored.load_data(data) and restored.call("shop_price","arcane_1")==70,"existing purchase history preserves the discount state on reload")
 var held=[Relic.instance("blood_1",1),Relic.instance("blood_3",2),Relic.instance("ward_1",3)]
 for seed_value in range(40):
  var rng=RandomNumberGenerator.new();rng.seed=seed_value
  var choices=Relic.draft_rewards(rng,held,held)
  check(Relic.definition(choices[0]).get("family","")=="blood","primary theme keeps its continuation slot")
  check(Relic.definition(choices[1]).get("family","")=="ward","secondary theme gets a real completion opportunity")
  check(choices.all(func(id):return id not in ["blood_1","blood_3","ward_1"]),"no duplicate owned relics are invented")
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
