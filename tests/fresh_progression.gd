extends SceneTree
const Study=preload("res://tools/fresh_run_simulation.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func _initialize():
 var study=Study.new()
 for captain in Study.Campaign.Characters.CAPTAINS:
  for profile in Study.PROFILES:
   var c=study.create(captain,2026102600)
   check(c.roster.size()==6 and c.roster[0].character_id==captain,"only the real captain and starter roster")
   check(c.relics.is_empty() and c.collection.is_empty() and c.completed_difficulties.is_empty(),"no preset relic or cross-save achievement")
   check(c.silver==40 and c.supplies==3 and c.equipment.size()==8,"exact new-game resource and gear budget")
   for unit in c.roster:
    check(unit.xp==0 and unit.skill_ranks.size()==1 and unit.skill_ranks.values()[0]==1,"fresh unit has only its free basic skill")
   study.equip(c,profile)
   check(c.equipment.size()==8 and c.silver==40,"assigning gear never creates or buys extras")
   var ledger=[];study.train(c,ledger)
   check(ledger.is_empty(),"no paid training before XP is earned")
   check(study.deployed(c,profile).size()==5 and study.deployed(c,profile).all(func(id):return c.roster.any(func(unit):return unit.id==id)),"deploy only existing characters")
 var c=study.create("shen",2026102600);study.equip(c,"balanced")
 var ledger=[];c.roster[0].xp=45
 study.train(c,ledger)
 check(ledger.size()==1 and c.roster[0].xp==0 and Study.Jobs.skill_rank(c.roster[0],"strike")==2,"training uses the real API and exact XP cost")
 check(study.has_method("equipment_gain"),"equipment valuation uses deployed-party marginal gain")
 if study.has_method("equipment_gain"):check(study.call("equipment_gain",c,"dagger","balanced")==0.0,"reserve-only duplicate dagger cannot consume shopping budget")
 c=study.create("shen",2026102600);c.start_region("border")
 var first=c.route.available().map(func(id):return c.route.node(id)).filter(func(node):return node.kind=="battle")[0]
 c.enter_route(first.id);c.route.completed=true
 var recovery=c.route.available().map(func(id):return c.route.node(id)).filter(func(node):return node.kind=="supply" or node.kind=="event")[0]
 c.enter_route(recovery.id)
 check(study.select_node(c,"balanced","adaptive").kind=="battle","adaptive strategy seeks real XP/relics before a build forms")
 c=study.create("shen",2026102600);c.phase="reward"
 c.choices=[Study.Campaign.REWARDS.filter(func(reward):return reward.id=="ward_1")[0].duplicate(true),Study.Campaign.REWARDS.filter(func(reward):return reward.id=="silver")[0].duplicate(true)]
 var trace=[]
 check(study.reward(c,"balanced","relic_focus",["ward_1"],trace) and c.relics.is_empty() and c.silver==105,"declining a relic chooses an actual other reward without rerolling")
 check(study.has_method("effective_mods"),"valuation honors real action-economy caps")
 if study.has_method("effective_mods"):
  var entries=[Study.Relic.instance("hourglass",1),Study.Relic.instance("command_4",2),Study.Relic.instance("command_10",3,"hero")]
  check(study.call("effective_mods",c.roster[0],entries).max_ap==2,"no phantom AP after the cap")
  entries=[Study.Relic.instance("hunt_2",1),Study.Relic.instance("hunt_10",2,"hero")]
  check(study.call("effective_mods",c.roster[0],entries).kill_ap==1,"kill AP is valued only once")
 check(study.has_method("learn_books_for"),"books can target the actual deployment")
 if study.has_method("learn_books_for"):
  c=study.create("shen",1);c.phase="world";c.books=["fury"];trace=[]
  study.call("learn_books_for",c,"support",trace)
  check(trace.size()==1 and trace[0].actor!="aling","support profile does not spend its book on reserve blade")
 c=study.create("shen",1);c.phase="world";c.roster[1].hp=1;trace=[]
 study.supply(c,trace)
 check(c.supplies<3 and c.roster[1].hp>1,"a critically wounded deployed actor can use field supplies alone")
 check(study.has_method("retention"),"extraction chooses useful live-party relics")
 if study.has_method("retention"):
  c=study.create("shen",1);c.phase="world"
  c.acquire_relic("lens");c.acquire_relic("candle","warden");c.acquire_relic("ward_1");c.acquire_relic("ward_3")
  check(study.call("retention",c,"balanced")==[2,3],"later active core outranks reserve-only or spent acquisition perks")
 check(study.has_method("battle_step"),"combat supply use is available through real paid actions")
 if study.has_method("battle_step"):
  c=study.create("shen",1);c.depart()
  var b=c.make_battle(study.deployed(c,"balanced"),0)
  var hero=b.find_actor("hero");hero.hp=10;hero.ap=4;b.order_index=b.order.find(b.actors.find(hero));trace=[]
  check(study.call("battle_step",c,b,trace) and hero.hp==34 and hero.ap==2 and c.supplies==2,"emergency medicine spends two AP and one real supply")
 c=study.create("shen",1);c.phase="world";c.books=["fury"];trace=[]
 study.learn_books_for(c,"support",trace)
 check(trace.size()==1 and trace[0].actor!="li","damage book is not spent on a trap-only starter")
 c=study.create("shen",1);c.roster[1].xp=1000;ledger=[]
 study.train(c,ledger)
 check(Study.Jobs.JOBS.blade.skills.all(func(id):return Study.Jobs.skill_rank(c.roster[1],id)==3),"long-run growth keeps spending legitimately earned XP after initial plan")
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
