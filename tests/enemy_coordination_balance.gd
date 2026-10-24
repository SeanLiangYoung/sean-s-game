extends SceneTree
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
 check(ResourceLoader.exists("res://tools/simulate_enemy_coordination.gd"),"expanded paired study exists")
 if failures:finish();return
 var study=load("res://tools/simulate_enemy_coordination.gd")
 # Covers all generated legal enemy HP and a wider bounded range.
 for hp in range(1,257):
  var enhanced=hp+maxi(1,int(ceil(hp*0.15)))
  var restored=int(floor(enhanced/1.15))
  check(restored==hp,"vigor inverse is exact for legal HP "+str(hp))
  check(restored+maxi(1,int(ceil(restored*0.15)))==enhanced,"vigor inverse maps back uniquely")
 var matrix=study.case_matrix()
 check(matrix.size()==2088,"1080 native and 1008 mixed-affix games")
 var tuning=study.case_matrix(false,false,true)
 check(tuning.size()==360,"tuning cohort retains six regions/resources/builds/threats/policies")
 check(tuning.all(func(case):return case.cohort=="core" and case.seed==21),"tuning uses only first training seed")
 var held_tuning=study.case_matrix(false,true,true)
 check(held_tuning.size()==360 and held_tuning.all(func(case):return case.seed==104),"held-out tuning uses independent first seed")
 var holdout=study.case_matrix(false,true)
 check(holdout.size()==matrix.size(),"held-out cohort has equal breadth")
 var themes={};var slots={};var profiles={}
 for i in range(0,matrix.size(),3):
  var case=matrix[i]
  check(matrix[i+1].duplicate().get("policy")=="previous" and matrix[i+2].policy=="current","stable paired policy order")
  if case.mix!="native":
   themes[case.build]=true;slots[case.affix_slot]=true;profiles[case.profile]=true
   check(case.seed!=holdout[i].seed,"held-out stress seed independent")
 check(profiles.size()==3,"three funded skill profiles")
 check(slots.has(0) and slots.has(3),"ordinary and boss affix slots covered")
 for theme in study.Relic.Expansion.SETS:check(themes.has(theme),"theme covered "+theme)
 for profile in ["balanced","root_focus","branch_focus"]:
  var setup=study.prepare_setup("control","full",profile)
  for unit in setup.party:
   check(unit.xp==15,"every profile spends exactly 285/300 XP")
   for id in unit.skill_ranks:
    if unit.skill_ranks[id]<=0:continue
    var prerequisite=study.Jobs.prerequisite(id)
    check(prerequisite=="" or study.Jobs.skill_rank(unit,prerequisite)>=2,"legal learned prerequisite")
  check(setup.relics.is_empty(),"control has no hidden relics")
 for build in study.stress_builds():
  var setup=study.prepare_setup(build,"depleted","branch_focus");var owners=[]
  for entry in setup.relics:
   var definition=study.Relic.definition(entry)
   check(not definition.is_empty(),"valid relic id")
   if definition.scope=="personal":
    check(entry.owner!="" and entry.owner not in owners,"one personal relic per valid owner")
    check(setup.party.any(func(u):return u.id==entry.owner),"personal relic bound to deployed actor")
    owners.append(entry.owner)
 for region in study.REGIONS:
  for affix in study.Skills.AFFIXES:
   for slot in [0,3]:
    var case={"region":region,"seed":42,"resource":"full","build":"ward","threat":"boss","policy":"classic","affix":affix,"mix":"ranged","profile":"balanced","affix_slot":slot}
    var a=study.prepare_battle(case);case.policy="previous";var b=study.prepare_battle(case)
    check(a.actors==b.actors and a.order==b.order and a.obstacles==b.obstacles,"identical paired start")
    var enemies=a.actors.filter(func(u):return u.side==1)
    check(enemies.filter(func(u):return u.get("affix","")!="").size()==1,"exactly one forced affix")
    check(enemies[slot].affix==affix,"forced affix on requested slot")
    var neutral_case=case.duplicate(true);neutral_case.affix="";var neutral=study.prepare_battle(neutral_case).find_actor(enemies[slot].id)
    var enhanced=enemies[slot]
    check(enhanced.max_hp==neutral.max_hp+(maxi(1,int(ceil(neutral.max_hp*0.15))) if affix=="vigor" else 0),"vigor applied once")
    check(enhanced.power==(mini(20,neutral.power+2) if affix=="brutal" else neutral.power),"brutal applied once")
    check(enhanced.armor==neutral.armor+(2 if affix=="iron" else 0),"iron applied once")
    check(enhanced.speed==neutral.speed+(2 if affix=="swift" else 0),"swift applied once")
    check(enhanced.range==neutral.range+(1 if affix=="reach" else 0),"reach applied once")
    var shield=10+int(enhanced.statuses.get("shield",{}).get("bonus",-10))
    var old_shield=10+int(neutral.statuses.get("shield",{}).get("bonus",-10))
    check(shield==old_shield+(4 if affix=="warded" else 0),"warded combines native barrier once")
    check(enemies[3].boss and study.Skills.skills(enemies[3]).size()==3,"boss retains regional active skills")
    check(a.active().turn_serial==1,"first actor turn starts exactly once")
 for case in study.case_matrix(true):
  var row=study.battle(case)
  check(row.invalid_actions==0 and row.stalls==0 and study.completed(row.outcome),"legal completed "+case.policy+" battle")
  check(row.captain_damage>=0 and row.other_damage>=0,"target pressure recorded")
 check(study.completed("gameover") and not study.completed("step_limit"),"real terminal defeat distinguished from unfinished battle")
 finish()
func finish():
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
