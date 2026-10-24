extends SceneTree
const Rules=preload("res://game/rules.gd")
const Relic=preload("res://game/relics.gd")
const Skills=preload("res://game/enemy_skills.gd")
const AI=preload("res://game/enemy_ai.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func fight(region="border",ids=[]):
 var entries=[]
 for id in ids:entries.append(Relic.instance(id,entries.size()+1,"hero" if Relic.definition(id).scope=="personal" else ""))
 var b=Rules.new();b.start_battle(b.default_party().slice(0,5),1,entries,{"biome":region,"seed":42,"threat":"boss"});b.obstacles=[]
 for u in b.actors:u.statuses={};u.affix="";u.armor=0;u.hp=u.max_hp;u.ap=4
 return b
func activate(b,a):
 b.order_index=b.order.find(b.actors.find(a));a.ap=4;a.enemy_used=false;a.cooldowns={};a.used_skills=[]
func _initialize():
 var b=fight("border",["blood_3"]);var a=b.find_actor("hero");var foe=b.find_actor("enemy0")
 check(is_equal_approx(b.relic_modifier(a,"lifesteal"),0.14),"unshielded banner retains14 percent lifesteal")
 b.put_status(a,"shield",a.id)
 check(is_equal_approx(b.relic_modifier(a,"lifesteal"),0.07),"shielded banner contributes only7 percent")
 a.max_hp=200;a.hp=20;foe.max_hp=300;foe.hp=300
 b.deal_damage(a,foe,100)
 check(a.hp==27,"shielded banner heal uses actual damage and real integer rounding")
 b=fight("border",["blood_1","blood_3","blood_7"]);a=b.find_actor("hero")
 b.put_status(a,"shield",a.id)
 check(is_equal_approx(b.relic_modifier(a,"lifesteal"),0.44),"banner penalty does not reduce independent blood resonance or bone needle")
 a.statuses={}
 check(is_equal_approx(b.relic_modifier(a,"lifesteal"),0.51),"losing shield restores banner contribution")
 check("7%" in Relic.description("blood_3"),"inventory explains shielded banner tradeoff")
 b=fight("border",["ward_1"]);a=b.find_actor("hero");b.begin_turn(a)
 check(10+a.statuses.shield.bonus==6,"automatic team shield is six, active shields remain independent")
 # Poison remains two finite cleansable ticks, with slightly lower attrition.
 b=fight("marsh");a=b.find_actor("hero");foe=b.find_actor("enemy0")
 b.Regional.poison(b,a,foe.id);var hp=a.hp
 b.begin_turn(a)
 check(hp-a.hp==2 and a.statuses.poison.ticks==1,"marsh first poison tick is two")
 b.begin_turn(a)
 check(not a.statuses.has("poison"),"marsh poison still expires after two turns")
 b.Regional.poison(b,a,foe.id);a.skill_ranks.cleanse=1;a.mp=100;a.max_mp=100
 activate(b,a)
 check(b.cast(a.id,"cleanse") and not a.statuses.has("poison"),"cleanse still removes poison")
 # Frost retaliation constrains midrange but preserves traps, exposure and long-range counterplay.
 for distance in [1,2,3]:
  b=fight("frost");a=b.find_actor("ranger");foe=b.find_actor("enemy3");a.cell=Vector2i.ZERO;foe.cell=Vector2i(distance,0)
  b.put_status(foe,"shield",foe.id);b.deal_damage(a,foe,20)
  check(a.statuses.has("snare")== (distance<=2),"ice retaliation follows two-cell distance "+str(distance))
 b=fight("frost");a=b.find_actor("hero");foe=b.find_actor("enemy3");a.cell=Vector2i.ZERO;foe.cell=Vector2i(1,0)
 b.put_status(foe,"shield",foe.id);b.deal_damage(a,foe,20,false)
 check(not a.statuses.has("snare"),"trap damage bypasses ice retaliation")
 b.put_status(foe,"exposed",a.id);foe.statuses.erase("shield");b.Regional.renew_barrier(b,foe)
 check(not foe.statuses.has("shield"),"expose still prevents ice shield renewal")
 # Stronger cold arrows still require actual damage before applying chill.
 b=fight("frost");a=b.find_actor("hero");foe=b.find_actor("enemy0");a.cell=Vector2i(1,0);foe.cell=Vector2i.ZERO;foe.power=13;a.max_hp=200;a.hp=200
 activate(b,foe);b.cast_enemy_skill("frostshot_skill",a.id)
 check(a.hp==188 and a.statuses.has("chill"),"cold arrow deals12 at power13 and adds chill")
 a.statuses={};b.put_status(a,"shield",a.id,30);activate(b,foe)
 b.cast_enemy_skill("frostshot_skill",a.id)
 check(a.hp==188 and not a.statuses.has("chill"),"full shield still prevents cold arrow control")
 # Ruins shield grows modestly, still declines in phase2 and remains exposed-counterable.
 b=fight("ruins");foe=b.find_actor("enemy3");b.Regional.renew_barrier(b,foe)
 check(10+foe.statuses.shield.bonus==10,"ruins phase1 has10 barrier")
 foe.boss_phase=2;foe.statuses={};b.Regional.renew_barrier(b,foe)
 check(10+foe.statuses.shield.bonus==6,"ruins phase2 barrier drops to6")
 b.put_status(foe,"exposed","hero");foe.statuses.erase("shield");b.Regional.renew_barrier(b,foe)
 check(not foe.statuses.has("shield"),"expose disables stronger core renewal")
 check(Skills.SKILLS.ruins_strike.drain==4 and Skills.SKILLS.drainer_skill.drain==4,"ruins mana pressure increases by one with same cooldowns")
 check(Skills.SKILLS.ruins_strike.cd==2 and Skills.SKILLS.frost_strike.cd==2,"regional strikes retain actor-local cooldown2")
 # Planner values only drain that can really pass a shield; changing MP must not mutate state.
 b=fight("ruins");a=b.find_actor("enemy3");foe=b.find_actor("hero")
 var intent={"source":a.id,"kind":"overload","name":"测试过载","cells":[foe.cell],"damage":12,"drain":4,"debuff":""}
 var copy=b.auto_snapshot();copy.boss_intents.append(intent)
 foe.mp=0;var dry=AI.intent_value(b,copy,a,{foe.id:1.0})
 foe.mp=20;var wet=AI.intent_value(b,copy,a,{foe.id:1.0})
 check(wet>dry,"overload planner includes viable mana drain")
 b.put_status(foe,"shield",foe.id,30)
 var blocked_wet=AI.intent_value(b,copy,a,{foe.id:1.0});foe.mp=0
 check(is_equal_approx(blocked_wet,AI.intent_value(b,copy,a,{foe.id:1.0})),"fully shielded overload has no phantom mana drain value")
 # Shield mitigation and the one-damage armor floor must match real overload mana loss.
 b=fight("ruins",["ward_2"]);a=b.find_actor("enemy3");foe=b.find_actor("hero");foe.mp=20
 b.put_status(foe,"shield",foe.id,0)
 intent={"source":a.id,"kind":"overload","name":"测试过载","cells":[foe.cell],"damage":12,"drain":4,"debuff":""}
 copy=b.auto_snapshot();copy.boss_intents.append(intent)
 var guarded_wet=AI.intent_value(b,copy,a,{foe.id:1.0});foe.mp=0
 check(is_equal_approx(guarded_wet,AI.intent_value(b,copy,a,{foe.id:1.0})),"shield-taken mitigation prevents phantom drain utility")
 foe.statuses={};foe.armor=12;foe.mp=0;dry=AI.intent_value(b,copy,a,{foe.id:1.0});foe.mp=20
 check(AI.intent_value(b,copy,a,{foe.id:1.0})>dry,"one-damage armor floor still enables real mana drain")
 # Shallow two-piece dips are weaker; completing four pieces restores the theme's full resonance.
 b=fight("border",["blood_1","blood_2"]);a=b.find_actor("hero")
 check(is_equal_approx(b.relic_modifier(a,"lifesteal"),0.12),"two blood pieces grant12 percent rather than four-piece sustain")
 b=fight("border",["blood_1","blood_2","blood_4","blood_5"]);a=b.find_actor("hero")
 check(is_equal_approx(b.relic_modifier(a,"lifesteal"),0.16),"full blood resonance retains16 percent total")
 b=fight("border",["ward_1","ward_2"]);a=b.find_actor("hero")
 check(b.relic_modifier(a,"shield_power")==2,"two ward pieces provide2 shield power")
 b=fight("border",["ward_1","ward_2","ward_3","ward_5"]);a=b.find_actor("hero")
 check(b.relic_modifier(a,"shield_power")==4,"full ward resonance retains4 shield power")
 # Ruins active siphons leak one mana through a full shield, but waste does not.
 for region in ["ruins","waste"]:
  b=fight(region);a=b.find_actor("hero");foe=b.find_actor("enemy0")
  a.cell=Vector2i(1,0);foe.cell=Vector2i.ZERO;a.mp=20;b.put_status(a,"shield",a.id,30);activate(b,foe)
  b.cast_enemy_skill("drainer_skill" if region=="ruins" else "sapper_skill",a.id)
  check(a.mp==(19 if region=="ruins" else 20),"only siphon skills leak one mana through a full shield "+region)
 b=fight("marsh");a=b.find_actor("enemy0");foe=b.find_actor("hero")
 var marsh_pressure=AI.target_weight(b,a,foe);b.biome="frost"
 check(marsh_pressure<AI.target_weight(b,a,foe),"marsh captain pursuit is gentler than frost")
 # The large personal shield trades restoration efficiency only for its wearer.
 b=fight("border",["ward_6"]);a=b.find_actor("hero");a.hp=20
 var friend=b.find_actor("blade");friend.hp=20
 check(b.heal_unit(a,20)==15,"personal auto-shield wearer pays25 percent recovery penalty")
 check(b.heal_unit(friend,20)==20,"personal recovery penalty never affects other allies")
 # Poison utility tracks the live payload instead of a stale three-damage constant.
 b=fight("marsh");a=b.find_actor("enemy0");foe=b.find_actor("hero");foe.armor=0
 var old=foe.duplicate(true);copy=b.auto_snapshot();var poisoned=copy.find_actor(foe.id)
 b.Regional.poison(copy,poisoned,a.id)
 var mild=AI.status_value(b,copy,a,old,poisoned)
 poisoned.statuses.poison.bonus=3
 check(AI.status_value(b,copy,a,old,poisoned)>mild,"poison planner reads actual per-tick payload")
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
