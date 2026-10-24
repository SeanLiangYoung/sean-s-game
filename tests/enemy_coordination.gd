extends SceneTree
const Rules=preload("res://game/rules.gd")
const AI=preload("res://game/enemy_ai.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func fixture(region="border"):
 var b=Rules.new();b.start_battle(b.default_party().slice(0,5),1,[],{"biome":region,"seed":42,"threat":"normal"});b.obstacles=[]
 for u in b.actors:u.statuses={};u.affix="";u.hp=u.max_hp;u.ap=4;u.power=0
 b.boss_intents=[];b.boss_cues=[]
 return b
func activate(b,id,ids):
 for u in b.actors:
  if u.id not in ids:u.hp=0
 var a=b.find_actor(id);b.order_index=b.order.find(b.actors.find(a));a.ap=4;a.enemy_used=true;a.cooldowns={};a.power=13;a.range=3;a.cell=Vector2i.ZERO
 return a
func _initialize():
 var b=fixture();var a=activate(b,"enemy0",["hero","ranger","enemy0"])
 var hero=b.find_actor("hero");hero.cell=Vector2i(2,0);hero.hp=40;hero.armor=0
 var ranger=b.find_actor("ranger");ranger.cell=Vector2i(1,0);ranger.hp=40;ranger.armor=0
 b.put_status(ranger,"mark",a.id,-2)
 var decision=b.enemy_decision()
 check(decision.action=="attack" and decision.get("target")=="hero","equal damage opportunities sustain captain pressure rather than arbitrary roster order")
 # Existing wound and a real allied firing opportunity should concentrate damage on that ally target.
 b=fixture();a=activate(b,"enemy0",["hero","ranger","enemy0","enemy1"]);a.power=9
 hero=b.find_actor("hero");hero.cell=Vector2i(-3,0);hero.hp=hero.max_hp;hero.armor=0
 ranger=b.find_actor("ranger");ranger.cell=Vector2i(2,0);ranger.hp=20;ranger.armor=0
 var ally=b.find_actor("enemy1");ally.cell=Vector2i(3,0);ally.range=1;ally.power=15
 decision=b.enemy_decision()
 check(decision.action=="attack" and decision.get("target")=="ranger","coordinated reachable takedown can outrank a healthy captain")
 # A protected captain does not absorb an irrational fixation when another kill is available.
 ranger.hp=2;b.put_status(hero,"shield",hero.id,80)
 check(b.enemy_decision().get("target")=="ranger","obvious kill outranks ineffectual shielded captain pressure")
 # Visible terrain blocks a melee follow-up even when hex distance says two AP is enough.
 b=fixture();a=activate(b,"enemy0",["hero","enemy0","enemy1"])
 hero=b.find_actor("hero");hero.cell=Vector2i(2,0)
 ally=b.find_actor("enemy1");ally.cell=Vector2i.ZERO;ally.range=1;ally.power=13
 a.cell=Vector2i(-3,0);a.range=1
 b.obstacles=[Vector2i(1,0),Vector2i(1,-1),Vector2i(1,1),Vector2i(0,1),Vector2i(2,-1)]
 check(AI.followers(b,ally,hero)==0,"no phantom melee follow-up through a wall")
 # Captain lethal remains mandatory; actor-local CD and immutable planning remain intact.
 b=fixture();a=activate(b,"enemy0",["hero","ranger","enemy0"])
 hero=b.find_actor("hero");hero.cell=Vector2i(2,0);hero.hp=1
 ranger=b.find_actor("ranger");ranger.cell=Vector2i(1,0);ranger.hp=1
 var before=b.actors.duplicate(true)
 decision=b.enemy_decision()
 check(decision.get("target")=="hero","captain lethal wins over another lethal")
 check(b.actors==before and decision==b.enemy_decision(),"coordination planning is pure and deterministic")
 # A spent ally cannot guarantee a finish after the target gets its next action.
 b=fixture();a=activate(b,"enemy0",["hero","ranger","enemy0","enemy1"]);a.ap=2;a.power=9;a.trait="formation"
 hero=b.find_actor("hero");hero.cell=Vector2i(-3,0);hero.armor=0
 ranger=b.find_actor("ranger");ranger.cell=Vector2i(2,0);ranger.hp=20;ranger.armor=0
 ally=b.find_actor("enemy1");ally.cell=Vector2i(3,0);ally.range=1;ally.power=15;ally.ap=0
 b.order=[b.actors.find(ally),b.actors.find(a),b.actors.find(ranger),b.actors.find(hero)];b.order_index=1
 check(b.enemy_decision().get("target")=="hero","spent ally after target turn cannot promise a coordinated finish")
 # Follow-up damage obeys real guard sharing and one-hit shield consumption.
 b=fixture();a=activate(b,"enemy1",["hero","ranger","enemy1"]);a.power=15
 hero=b.find_actor("hero");hero.cell=Vector2i(2,-1)
 ranger=b.find_actor("ranger");ranger.cell=Vector2i(2,0);ranger.hp=20;ranger.armor=0
 b.put_status(ranger,"guard",hero.id)
 check(AI.followup_damage(b,a,ranger)==14,"two guarded hits do not promise an impossible kill")
 ranger.statuses={};a.power=13;ranger.hp=30;b.put_status(ranger,"shield",ranger.id,90)
 check(AI.followup_damage(b,a,ranger)==13,"first hit consumes even a huge shield, second hit deals real damage")
 # Two melee allies cannot both occupy the only legal firing cell.
 b=fixture();a=activate(b,"enemy0",["hero","enemy0","enemy1"]);a.range=1;a.power=15;a.trait="formation"
 hero=b.find_actor("hero");hero.cell=Vector2i(2,0);hero.hp=20;hero.armor=0
 ally=b.find_actor("enemy1");ally.cell=Vector2i(1,-1);ally.range=1;ally.power=15
 b.obstacles=[Vector2i(3,0),Vector2i(3,-1),Vector2i(2,-1),Vector2i(1,1),Vector2i(2,1)]
 b.order=[b.actors.find(a),b.actors.find(ally),b.actors.find(hero)];b.order_index=0
 check(AI.followup_damage(b,a,hero)==15,"allies respect the occupied single attack lane")
 # All regional archetypes retain pure planning and real AP/CD costs.
 for region in ["border","wood","waste","frost","marsh","ruins"]:
  b=fixture(region);a=activate(b,"enemy0",["hero","ranger","enemy0"])
  hero=b.find_actor("hero");hero.cell=Vector2i(2,0);hero.hp=40;hero.armor=0
  ranger=b.find_actor("ranger");ranger.cell=Vector2i(1,0);ranger.hp=40;ranger.armor=0
  before=b.actors.duplicate(true);decision=b.enemy_decision()
  check(decision.get("target")=="hero","regional captain pressure remains attainable "+region)
  check(b.actors==before and decision==b.enemy_decision(),"regional planning is immutable "+region)
  b.enemy_step()
  check(a.ap<4 and a.mp==0 and a.cooldowns.is_empty(),"regional basic attack spends AP without phantom CD or mana "+region)
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
