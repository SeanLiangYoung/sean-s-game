extends SceneTree
const Rules=preload("res://game/rules.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func fixture(region="border",boss=false):
 var b=Rules.new();b.start_battle(b.default_party().slice(0,5),1,[],{"biome":region,"seed":42,"threat":"boss" if boss else "normal"});b.obstacles=[]
 for u in b.actors:u.statuses={};u.affix="";u.hp=u.max_hp;u.ap=4
 b.boss_intents=[];b.boss_cues=[]
 return b
func activate(b,id):
 var a=b.find_actor(id);b.order_index=b.order.find(b.actors.find(a));a.ap=4;a.enemy_used=false;a.cooldowns={};return a
func only(b,ids):
 for u in b.actors:
  if u.id not in ids:u.hp=0
func _initialize():
 var b=fixture()
 check(b.has_method("enemy_decision"),"tactical decision API exists")
 if not b.has_method("enemy_decision"):finish();return
 # Choose a reachable lethal target rather than the nearer healthy target.
 only(b,["hero","ranger","enemy0"]);var a=activate(b,"enemy0");a.cell=Vector2i.ZERO
 var hero=b.find_actor("hero");hero.cell=Vector2i(1,0);hero.hp=hero.max_hp
 var ranger=b.find_actor("ranger");ranger.cell=Vector2i(2,0);ranger.hp=3
 var before=b.actors.duplicate(true);var cue_count=b.boss_cues.size()
 var decision=b.enemy_decision()
 check(decision.get("target")==ranger.id,"enemy prioritizes affordable lethal target")
 check(b.actors==before and b.boss_cues.size()==cue_count,"planning never mutates authoritative HP/AP/CD/status/cues")
 check(decision==b.enemy_decision(),"same state gives deterministic decision")
 # Prefer an actual basic kill to setting up mark/control when that would waste a turn.
 a.trait="spotter";ranger.hp=1
 decision=b.enemy_decision();check(decision.action=="attack" and decision.target==ranger.id,"doesn't waste mark cooldown before a basic kill")
 # With only two AP at range four, a spotter marks for allies instead of moving without a shot.
 b=fixture();only(b,["hero","enemy0","enemy1"]);a=activate(b,"enemy0");a.cell=Vector2i(-3,0);a.range=3;a.ap=2
 hero=b.find_actor("hero");hero.cell=Vector2i(1,0);b.find_actor("enemy1").cell=Vector2i(2,0)
 decision=b.enemy_decision()
 check(decision.action=="skill" and decision.skill=="spotter_skill" and decision.target==hero.id,"spotter coordinates ranged mark with reachable melee ally")
 # Ranged unit retreats and still has two AP for a shot, instead of face-tanking.
 b=fixture("wood");only(b,["hero","enemy0"]);a=activate(b,"enemy0");a.cell=Vector2i.ZERO;a.enemy_used=true
 hero=b.find_actor("hero");hero.cell=Vector2i(1,0)
 decision=b.enemy_decision()
 check(decision.action=="move" and b.hex_distance(decision.target,hero.cell)>1,"ranged unit kites melee pressure")
 if decision.action=="move":
  check(b.movement_cost(a,b.path_to(a.cell,decision.target))<=2,"kite preserves attack AP")
  check(b.move_to(decision.target) and b.enemy_decision().action=="attack","kite followed by a legal shot")
 # Do not walk a known hostile trap on the shortest path when a safe detour exists.
 b=fixture("waste");only(b,["hero","enemy1"]);a=activate(b,"enemy1");a.cell=Vector2i(-2,0);a.range=1;a.enemy_used=true
 hero=b.find_actor("hero");hero.cell=Vector2i(2,0)
 b.traps=[{"source":hero.id,"side":0,"cell":Vector2i(-1,0),"damage":26}]
 decision=b.enemy_decision()
 check(decision.action=="move" and not b.path_to(a.cell,decision.target).any(func(c):return c==Vector2i(-1,0)),"path decision avoids known hostile trap")
 # Shrink safety takes priority before spending all AP on attacks.
 b=fixture();only(b,["hero","enemy0"]);a=activate(b,"enemy0");a.cell=Vector2i(4,-1);a.enemy_used=true
 hero=b.find_actor("hero");hero.cell=Vector2i(3,-1);b.round_no=3
 decision=b.enemy_decision()
 check(decision.action=="move" and b.hex_distance(decision.target,Vector2i.ZERO)<4,"enemy leaves impending shrinking edge")
 # Friendly boss telegraphs don't harm side1 in real rules and shouldn't force a false flee.
 b=fixture("wood",true);only(b,["hero","enemy0","enemy3"]);a=activate(b,"enemy0");a.cell=Vector2i.ZERO;a.enemy_used=true
 hero=b.find_actor("hero");hero.cell=Vector2i(2,0)
 b.boss_intents=[{"source":"enemy3","kind":"roots","name":"藤根","cells":[a.cell],"damage":6,"debuff":"snare","due":2}]
 decision=b.enemy_decision();check(decision.action=="attack","enemy understands friendly warning faction")
 # Don't spend a defensive skill with nobody capable of attacking before it expires.
 b=fixture("frost");only(b,["hero","enemy1"]);a=activate(b,"enemy1");a.cell=Vector2i(-3,0)
 hero=b.find_actor("hero");hero.cell=Vector2i(3,0)
 decision=b.enemy_decision();check(not(decision.action=="skill" and decision.skill=="frost_armor_skill"),"no useless shield instead of useful approach")
 # A low-health boss may choose a guaranteed kill over a tiny heal.
 b=fixture("marsh",true);only(b,["hero","enemy3"]);a=activate(b,"enemy3");a.cell=Vector2i.ZERO;a.hp=20
 hero=b.find_actor("hero");hero.cell=Vector2i(1,0);hero.hp=1
 decision=b.enemy_decision();check(decision.action in ["attack","skill"] and decision.get("target")==hero.id,"boss can finish a lethal target instead of fixed low-HP support")
 # Being trapped on the shrinking edge must not suppress a kill that opens escape.
 b=fixture();only(b,["hero","ranger","enemy1"]);a=activate(b,"enemy1");a.cell=Vector2i(4,-1);a.range=1;a.enemy_used=true
 hero=b.find_actor("hero");hero.cell=Vector2i(-3,0);hero.power=0
 ranger=b.find_actor("ranger");ranger.cell=Vector2i(3,-1);ranger.hp=3;ranger.power=0;ranger.armor=0
 b.obstacles=[Vector2i(3,0)];b.round_no=3
 decision=b.enemy_decision();check(decision.action=="attack" and decision.get("target")==ranger.id,"kill opens a safe exit when retreat is blocked")
 # The preceding round is not an immediate shrink and may still use the edge safely.
 b=fixture();only(b,["hero","enemy0"]);a=activate(b,"enemy0");a.cell=Vector2i(4,-1);a.enemy_used=true
 hero=b.find_actor("hero");hero.cell=Vector2i(3,-1);hero.power=0;b.round_no=2
 check(b.enemy_decision().action=="attack","no forced early retreat on nonshrinking round")
 # A real route may initially increase straight-line distance around a long wall.
 b=fixture();only(b,["hero","enemy1"]);a=activate(b,"enemy1");a.cell=Vector2i.ZERO;a.range=1;a.enemy_used=true
 hero=b.find_actor("hero");hero.cell=Vector2i(2,0);hero.power=0
 b.obstacles=[]
 for y in range(-3,3):b.obstacles.append(Vector2i(1,y))
 decision=b.enemy_decision()
 check(decision.action=="move","long obstacle detour advances by path distance rather than resting")
 # Repeated execution remains legal with one affix and actor-local cooldowns.
 for region in ["border","wood","waste","frost","marsh","ruins"]:
  b=fixture(region,true)
  var count=0
  while b.outcome=="" and count<500:
   count+=1
   if b.active().side==0:b.end_action()
   else:
    var old_ap=b.active().ap;var old_index=b.order_index;var old_round=b.round_no;var event_count=b.events.size()
    b.enemy_step()
    check(b.outcome!="" or b.order_index!=old_index or b.round_no!=old_round or b.active().ap<old_ap,"enemy decision always consumes AP or advances")
    check(b.events.size()>event_count,"tactical execution has readable feedback")
  check(count<500,"no enemy AI stall in "+region)
 finish()
func finish():
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
