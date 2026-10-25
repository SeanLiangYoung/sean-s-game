extends SceneTree
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
 check(ResourceLoader.exists("res://tools/simulate_enemy_ai.gd"),"paired AI study exists")
 if failures:quit(1);return
 var study=load("res://tools/simulate_enemy_ai.gd")
 var matrix=study.case_matrix(false)
 check(matrix.size()==744,"576 core and 168 mixed-affix stress games")
 for region in study.REGIONS:
  for affix in study.Skills.AFFIXES:
   var case={"region":region,"seed":42,"resource":"full","build":"ward","threat":"boss","affix":affix,"mix":"ranged","policy":"classic"}
   var a=study.prepare_battle(case);case.policy="tactical";var b=study.prepare_battle(case)
   check(a.actors==b.actors,"paired actors/resources/skills/affix "+region+affix)
   check(a.obstacles==b.obstacles,"paired maps "+region+affix)
   var enemies=a.actors.filter(func(u):return u.side==1)
   check(enemies.filter(func(u):return u.get("affix","")!="").size()==1,"exactly one affix")
   check(enemies[0].affix==affix,"forced affix is on same slot")
   var neutral_case=case.duplicate(true);neutral_case.affix=""
   var neutral=study.prepare_battle(neutral_case).find_actor("enemy0")
   var enhanced=enemies[0]
   check(enhanced.max_hp==neutral.max_hp+(maxi(1,int(ceil(neutral.max_hp*0.15))) if affix=="vigor" else 0),"vigor applies once to original HP")
   check(enhanced.power==(mini(20,neutral.power+2) if affix=="brutal" else neutral.power),"power changes only for brutal")
   check(enhanced.armor==neutral.armor+(2 if affix=="iron" else 0),"armor changes only for iron")
   check(enhanced.speed==neutral.speed+(2 if affix=="swift" else 0),"speed changes only for swift")
   check(enhanced.range==neutral.range+(1 if affix=="reach" else 0),"range changes only for reach")
   var shield=10+int(enhanced.statuses.get("shield",{}).get("bonus",-10))
   var native_shield=10+int(neutral.statuses.get("shield",{}).get("bonus",-10))
   check(shield==native_shield+(4 if affix=="warded" else 0),"warded adds four to real native barrier")
   check(enhanced.hp==enhanced.max_hp,"affix HP starts consistent")
   for unit in enemies:
    check(study.Skills.skills(unit).size()==(3 if unit.boss else 1),"archetype skill lineage")
    for id in study.Skills.skills(unit):
     check(study.Skills.SKILLS[id].cd>=2,"real skill cooldown preserved")
   check(a.find_actor("hero").max_hp==80,"no player-stat boosts")
 var sample=study.case_matrix(true)[0]
 for policy in ["classic","tactical"]:
  sample.policy=policy
  var row=study.battle(sample)
  check(row.invalid_actions==0 and row.outcome in ["victory","gameover"],"legal completed "+policy+" policy")
 print("CHECKS: %d FAILURES: %d"%[checks,failures])
 quit(0 if failures==0 else 1)
