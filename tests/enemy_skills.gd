extends SceneTree
const Rules=preload("res://game/rules.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func _initialize():
 var b=Rules.new();b.start_battle(b.default_party(),1,[],{"biome":"border","seed":42,"threat":"boss"})
 check(b.has_method("enemy_skills"),"enemy skill interface exists")
 if not b.has_method("enemy_skills"):finish();return
 var affixes={}
 for region in ["border","wood","waste","frost","marsh","ruins"]:
  for seed_value in range(20):
   b=Rules.new();b.start_battle(b.default_party(),1,[],{"biome":region,"seed":seed_value,"threat":"boss"})
   var enemies=b.actors.filter(func(a):return a.side==1)
   var empowered=enemies.filter(func(a):return a.get("affix","")!="")
   check(empowered.size()==1,"exactly one empowered enemy per encounter")
   affixes[empowered[0].affix]=true
   var clone=Rules.new();clone.start_battle(clone.default_party(),1,[],{"biome":region,"seed":seed_value,"threat":"boss"})
   check(clone.actors.filter(func(a):return a.get("affix","")!="")[0].id==empowered[0].id and clone.actors.filter(func(a):return a.get("affix","")!="")[0].affix==empowered[0].affix,"empowerment deterministic")
   for enemy in enemies:
    check(b.enemy_skills(enemy).size()>0,"every enemy has active skill")
    if enemy.get("boss",false):check(b.enemy_skills(enemy).size()>=3 and enemy.get("boss_passive","")!="" and enemy.get("trait","")!="","boss has actives, passive and regional trait")
 check(affixes.size()>=5,"random affix variety")
 # All three registered boss actives can actually be executed and charge their own cooldown.
 for region in ["border","wood","waste","frost","marsh","ruins"]:
  for slot in range(3):
   var trial=Rules.new();trial.start_battle(trial.default_party(),1,[],{"biome":region,"seed":42,"threat":"boss"})
   var leader=trial.actors[-1];var victim=trial.find_actor("hero")
   trial.order_index=trial.order.find(trial.actors.find(leader));leader.ap=4;leader.enemy_used=false;leader.cooldowns={};leader.statuses={};leader.hp-=16
   victim.cell=leader.cell+Vector2i(-1,0);victim.statuses={}
   var active_id=trial.enemy_skills(leader)[slot]
   check(trial.cast_enemy_skill(active_id,victim.id if slot==1 else null),"boss active executes: "+active_id)
   check(leader.cooldowns.has(active_id) and leader.ap==2 and leader.mp==0,"boss active pays real AP/CD without MP")
 # Ward affix must strengthen native barriers instead of being overwritten by them.
 var guarded=Rules.new();guarded.start_battle(guarded.default_party(),1,[],{"biome":"ruins","seed":42,"threat":"boss"})
 var guard=guarded.actors[-1];guard.affix="warded";guarded.begin_turn(guard)
 check(10+int(guard.statuses.shield.bonus)>=12,"ward affix adds to the boss native eight-point barrier")
 var soldier=guarded.find_actor("enemy1");guarded.order_index=guarded.order.find(guarded.actors.find(soldier));soldier.ap=4;soldier.enemy_used=false
 check(guarded.cast_enemy_skill(guarded.enemy_skills(soldier)[0]),"construct active can improve its innate barrier")
 # Owner-turn cooldown does not tick when other units take turns, and skills cost no mana.
 b=Rules.new();b.start_battle(b.default_party(),1,[],{"biome":"wood","seed":42,"threat":"boss"});b.obstacles=[]
 var boss=b.actors[-1];var skill=b.enemy_skills(boss)[0]
 b.order_index=b.order.find(b.actors.find(boss));boss.ap=4;boss.mp=0
 check(b.call("cast_enemy_skill",skill,null),"zero MP boss can prepare")
 check(boss.ap==2 and boss.mp==0,"enemy skill spends AP but no MP")
 check(not b.call("cast_enemy_skill",skill,null),"no second active in same personal turn")
 var readiness=boss.cooldowns.duplicate(true)
 b.begin_turn(b.find_actor("hero"));check(boss.cooldowns==readiness,"other actors don't tick owner cooldown")
 b.begin_turn(boss);check(not b.call("enemy_skill_ready",boss,skill),"cooldown blocks next owner turn")
 b.begin_turn(boss);check(b.call("enemy_skill_ready",boss,skill),"cooldown expires on intended owner turn")
 # Invalid target and insufficient AP don't consume cooldown.
 var strike=b.enemy_skills(boss)[1];b.order_index=b.order.find(b.actors.find(boss));boss.enemy_used=false;boss.ap=4
 check(not b.call("cast_enemy_skill",strike,"missing") and not boss.cooldowns.has(strike),"invalid target doesn't consume CD")
 boss.ap=1
 check(not b.call("cast_enemy_skill",strike,"hero") and not boss.cooldowns.has(strike),"insufficient AP doesn't consume CD")
 # Ordinary enemy skill uses the same cooldown/no-mana contract.
 var archer=b.find_actor("enemy0");archer.cell=Vector2i.ZERO
 b.find_actor("hero").cell=Vector2i(1,0);b.order_index=b.order.find(b.actors.find(archer));archer.ap=4;archer.mp=0
 check(b.call("cast_enemy_skill",b.enemy_skills(archer)[0],"hero") and archer.mp==0,"ordinary enemy active consumes no MP")
 finish()
func finish():
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
