extends SceneTree
const Rules=preload("res://game/rules.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func battle_for(region,threat="normal"):
 var party=Rules.new().default_party().slice(0,5)
 for u in party:u.max_mp=100;u.mp=100;u.skill_ranks.cleanse=1;u.skill_ranks.hero_sunder=1;u.skill_ranks.ranger_pin=1
 var b=Rules.new();b.start_battle(party,1,[],{"biome":region,"seed":42,"tier":1,"threat":threat});b.obstacles=[]
 return b
func set_active(b,unit):
 b.order_index=b.order.find(b.actors.find(unit))
 unit.ap=4;unit.used_skills=[]
func _initialize():
 var b=battle_for("wood")
 check(b.has_method("boss_warnings"),"regional combat and warning interface exists")
 if not b.has_method("boss_warnings"):finish();return
 var trait_sets={}
 for region in ["border","wood","waste","frost","marsh","ruins"]:
  b=battle_for(region,"boss")
  var enemies=b.actors.filter(func(a):return a.side==1)
  check(enemies.all(func(a):return a.has("trait") and a.has("archetype")),"enemy identities in "+region)
  check(enemies.filter(func(a):return a.get("boss",false)).size()==1,"one regional boss")
  trait_sets[enemies[0].trait]=true
  var boss=enemies[-1];set_active(b,boss)
  var hp=b.actors.filter(func(a):return a.side==0).map(func(a):return a.hp)
  b.enemy_step()
  check(not b.boss_warnings().is_empty(),"boss telegraphs "+region)
  check(hp==b.actors.filter(func(a):return a.side==0).map(func(a):return a.hp),"preparation does not instantly damage "+region)
  check(boss.ap==2,"preparation spends two AP "+region)
  check(b.boss_warnings().size()<=5,"warning cell bound")
  var copy=b.auto_snapshot()
  check(copy.boss_warnings()==b.boss_warnings(),"auto snapshot includes regional intents")
  copy.set("boss_intents",[])
  check(not b.boss_warnings().is_empty(),"snapshot intent state isolated")
  boss.hp=0;b.check_outcome()
  check(b.boss_warnings().is_empty(),"boss death cancels warning "+region)
 check(trait_sets.size()==6,"six distinct ranged enemy roles")
 # Catalog names, mechanics and equipped weapon families agree with actual range.
 b=battle_for("border")
 check(b.find_actor("enemy0").trait=="spotter" and b.find_actor("enemy1").trait=="formation","border ranged spotters and melee shield formation are assigned correctly")
 # Forest camouflage has several counters, never a hard immunity.
 b=battle_for("wood");var a=b.find_actor("ranger");var foe=b.find_actor("enemy0")
 a.cell=Vector2i(-1,0);foe.cell=Vector2i(2,0);foe.hp=200;foe.max_hp=200;foe.armor=0
 b.deal_damage(a,foe,20);check(foe.hp==184,"camouflage reduces distant direct hit by four")
 b.put_status(foe,"mark",a.id);var before=foe.hp;b.deal_damage(a,foe,20)
 check(before-foe.hp==25,"mark reveals and amplifies distant hit")
 foe.statuses={};before=foe.hp;b.deal_damage(a,foe,20,false)
 check(before-foe.hp==20,"trap damage bypasses camouflage")
 # Frost first-hit armor resets per enemy turn; exposed bypasses it.
 b=battle_for("frost");a=b.find_actor("hero");foe=b.find_actor("enemy1");foe.hp=200;foe.max_hp=200;foe.armor=0
 b.deal_damage(a,foe,20);check(foe.hp==184,"first frost armor hit reduced")
 before=foe.hp;b.deal_damage(a,foe,20);check(before-foe.hp==20,"frost armor only once per own turn")
 b.begin_turn(foe);b.put_status(foe,"exposed",a.id);before=foe.hp;b.deal_damage(a,foe,20)
 check(before-foe.hp==24,"exposed counters frost plating")
 # Poison is capped, finite and cleansable. Shielding the hit avoids the poison.
 b=battle_for("marsh");foe=b.find_actor("enemy0");a=b.find_actor("hero");foe.cell=Vector2i(-2,0);a.cell=Vector2i(-3,0)
 set_active(b,foe);b.attack(a.id)
 check(a.statuses.has("poison") and a.statuses.poison.ticks==2 and a.statuses.poison.bonus==2,"venom applies two ticks of two base damage")
 var poisoned=a.hp;b.begin_turn(a);check(a.hp==poisoned-2 and a.statuses.poison.ticks==1,"poison ticks at victim turn")
 poisoned=a.hp;b.begin_turn(a)
 check(a.hp==poisoned-2,"second poison tick deals two base damage")
 check(not a.statuses.has("poison"),"poison expires after two ticks")
 set_active(b,foe);foe.venom_used=false;b.put_status(a,"shield",a.id,20);b.attack(a.id)
 check(not a.statuses.has("poison"),"fully shielded hit does not poison")
 b.put_status(a,"poison",foe.id,3);a.statuses.poison.ticks=2;b.put_status(a,"chill",foe.id);b.put_status(a,"snare",foe.id)
 set_active(b,a);check(b.cast(a.id,"cleanse") and not a.statuses.has("poison") and not a.statuses.has("chill") and not a.statuses.has("snare"),"cleanse removes regional debuffs")
 # Movement snare charges exactly one extra AP for the first step, no zero-AP movement.
 b=battle_for("wood");a=b.find_actor("hero");a.cell=Vector2i.ZERO;set_active(b,a);b.put_status(a,"snare","enemy3")
 check(b.call("movement_cost",a,[Vector2i(0,-1)])==2,"snare preview charges extra AP")
 check(b.move_to(Vector2i(0,-1)) and a.ap==2 and not a.statuses.has("snare"),"snare consumed on actual move")
 # Ruins shields stop renewing while exposed; stagger interrupts overload.
 b=battle_for("ruins","boss");foe=b.actors[-1];a=b.find_actor("hero")
 check(foe.statuses.has("shield"),"construct starts with visible barrier")
 b.put_status(foe,"exposed",a.id);b.begin_turn(foe)
 check(not foe.statuses.has("shield"),"exposed blocks shield renewal")
 set_active(b,foe);b.enemy_step();check(not b.boss_warnings().is_empty(),"overload warning exists")
 b.put_status(foe,"stagger",a.id);b.begin_turn(foe)
 check(b.boss_warnings().is_empty(),"stagger interrupts charged overload")
 # A stationary victim takes the warned hit, moving to a safe cell avoids it.
 for escape in [false,true]:
  b=battle_for("waste","boss");foe=b.actors[-1];set_active(b,foe);b.enemy_step()
  var warning=b.boss_warnings()[0]
  a=b.find_actor("hero");a.cell=warning
  if escape:a.cell=b.cells().filter(func(c):return c not in b.boss_warnings() and b.is_free(c))[0]
  before=a.hp;b.begin_turn(foe)
  check(a.hp==before if escape else a.hp<before,"telegraph dodge path, escape="+str(escape))
 b=battle_for("wood","boss");foe=b.actors[-1];set_active(b,foe);b.enemy_step();b.shrink()
 check(b.boss_warnings().is_empty(),"shrinking board cancels obsolete intents")
 # Auto combat must step out of an announced danger area when movement is affordable.
 b=battle_for("wood","boss");foe=b.actors[-1];set_active(b,foe);b.enemy_step()
 a=b.find_actor("hero");a.cell=b.boss_warnings()[0];set_active(b,a)
 var decision=b.auto_action()
 check(decision.get("action","")=="move" and decision.get("target") not in b.boss_warnings(),"auto combat avoids telegraphed cells")
 # Escaping must not be undone by the ordinary movement decision with leftover AP.
 b=battle_for("wood","boss");a=b.find_actor("hero");foe=b.actors[-1]
 for unit in b.actors:
  if unit.id not in [a.id,foe.id]:unit.hp=0
 a.cell=Vector2i.ZERO;foe.cell=Vector2i(2,0);set_active(b,a);a.ap=2
 b.boss_intents=[{"source":foe.id,"kind":"roots","name":"藤根","cells":[Vector2i.ZERO,Vector2i(0,1),Vector2i(0,-1)],"damage":6,"debuff":"snare","due":2}]
 decision=b.auto_action();b.move_to(decision.target)
 decision=b.auto_action()
 check(decision.get("action","")!="move" or decision.target not in b.boss_warnings(),"auto combat stays out of danger after its first dodge")
 # A sand line aims through a real living target rather than an empty parallel lane.
 b=battle_for("waste","boss");foe=b.actors[-1];set_active(b,foe);b.enemy_step()
 check(b.actors.any(func(u):return u.side==0 and u.hp>0 and u.cell in b.boss_warnings()),"sand line includes its selected victim")
 # Nonhero death from a delayed poison tick advances the turn safely.
 b=battle_for("marsh");a=b.find_actor("blade");a.hp=1
 b.put_status(a,"poison","enemy0",3);a.statuses.poison.ticks=2;set_active(b,a);b.begin_turn(a)
 check(a.hp==0 and b.active().id!=a.id and b.outcome=="","poison death advances to next living actor")
 # Start-turn regenerative/shield relics provide a reliable counter to poison.
 for relic_id in ["blood_9","ward_6"]:
  var hero=Rules.new().default_party()[0]
  b=Rules.new();b.start_battle([hero],0,[preload("res://game/relics.gd").instance(relic_id,1,"hero")],{"biome":"marsh","seed":42,"threat":"normal"})
  a=b.find_actor("hero");a.hp=1;b.put_status(a,"poison","enemy0",3);a.statuses.poison.ticks=2
  set_active(b,a);b.begin_turn(a)
  check(a.hp>0 and b.outcome=="","start-turn sustain resolves before poison: "+relic_id)
 # No region mechanics on unconfigured legacy battles.
 b=Rules.new();b.start_battle(Rules.new().default_party(),0)
 check(b.boss_warnings().is_empty() and not b.actors[-1].has("trait"),"legacy battle mechanics unchanged")
 finish()
func finish():
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
