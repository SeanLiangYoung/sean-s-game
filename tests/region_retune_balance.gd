extends SceneTree
const Study=preload("res://tools/simulate_region_retune.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
 var matrix=Study.case_matrix();var holdout=Study.case_matrix(false,true)
 check(matrix.size()==768,"480 core and 288 actual-character focus games")
 check(Study.case_matrix(false,false,true).size()==84,"84 tuning cases")
 check(holdout.size()==matrix.size(),"equal independent validation breadth")
 var affixes={};var slots={};var themes={};var captains={};var profiles={}
 for i in matrix.size():
  var case=matrix[i]
  check(case.seed!=holdout[i].seed,"independent validation seeds")
  affixes[case.affix]=true;slots[case.affix_slot]=true;themes[case.build]=true
  if case.cohort=="focus":captains[case.captain]=true;profiles[case.profile]=true
 check(affixes.size()==7 and slots.size()==2,"all seven affixes and two recipient slots")
 check(captains.size()==3 and profiles.size()==2,"all captains with two real party profiles")
 for theme in Study.Relic.Expansion.SETS:check(themes.has(theme),"theme represented "+theme)
 for cohort in ["core","focus"]:
  for build in (Study.core_builds() if cohort=="core" else Study.FOCUS_BUILDS):
   var case={"cohort":cohort,"region":"frost","seed":42,"resource":"depleted","build":build,"threat":"boss","captain":"shen","profile":"balanced","affix":"warded","affix_slot":3}
   var setup=Study.prepare_setup(case);var owners=[]
   check(setup.relics.size()==(0 if build=="control" else 4),"equal relic slot budget")
   for entry in setup.relics:
    if Study.Relic.definition(entry).scope=="personal":
     check(entry.owner!="" and entry.owner not in owners,"unique personal owner")
     check(setup.party.any(func(u):return u.id==entry.owner),"owner belongs to deployed party")
     owners.append(entry.owner)
   var a=Study.prepare_battle(case,setup);var b=Study.prepare_battle(case)
   check(a.actors==b.actors and a.order==b.order and a.obstacles==b.obstacles,"deterministic identical start")
   check(a.active().get("turn_serial",0)==1,"only one real first turn")
   var enemies=a.actors.filter(func(u):return u.side==1)
   check(enemies.filter(func(u):return u.get("affix","")!="").size()==1,"one affix total")
   check(enemies[3].affix=="warded" and enemies[3].boss,"boss receives requested affix")
   var neutral_case=case.duplicate(true);neutral_case.affix="vigor"
   var native=Study.prepare_battle(neutral_case).find_actor("enemy3")
   var expected=10+int(native.statuses.shield.bonus)
   check(10+int(enemies[3].statuses.shield.bonus)==expected+4,"native barrier and affix stack once")
 var wrap=Study.prepare_battle(Study.case_matrix(true)[0])
 var authoritative=JSON.stringify([wrap.actors,wrap.order,wrap.order_index,wrap.round_no,wrap.preparing])
 var rollover=wrap.auto_snapshot()
 check(not rollover.preparing,"snapshot preserves completed preparation state")
 rollover.order_index=rollover.order.size()-1;rollover.active().ap=2
 var next_id=rollover.actors[rollover.order[0]].id
 var prior_serial=int(rollover.find_actor(next_id).get("turn_serial",0))
 var prior_round=rollover.round_no
 check(rollover.rest("hp"),"snapshot last actor can spend its final AP")
 check(rollover.round_no==prior_round+1 and rollover.order_index==0,"snapshot round boundary rebuilds initiative")
 check(rollover.active().id==next_id and int(rollover.active().get("turn_serial",0))==prior_serial+1,"snapshot round boundary starts the next actor turn")
 check(authoritative==JSON.stringify([wrap.actors,wrap.order,wrap.order_index,wrap.round_no,wrap.preparing]),"snapshot round rollover does not mutate authoritative battle")
 var sample=Study.case_matrix(true)[0];var tracked=Study.prepare_battle(sample)
 var actor=tracked.active();tracked.find_actor("enemy0").cell=actor.cell+Vector2i(1,0)
 var hits=tracked.auto_hits().filter(func(choice):return choice.action=="skill")
 check(not hits.is_empty(),"successful cast instrumentation fixture has legal skill")
 if not hits.is_empty():
  var choice=hits[0];var copy=tracked.auto_snapshot()
  check(copy.cast(choice.target,choice.skill) and copy.study_casts.size()==1 and tracked.study_casts.is_empty(),"snapshot forecasts never enter real cast metrics")
  check(tracked.cast(choice.target,choice.skill) and tracked.study_casts==[choice.skill],"successful authoritative cast counted once")
 for case in Study.case_matrix(true):
  var row=Study.battle(case)
  check(Study.completed(row.outcome) and row.invalid_actions==0 and row.stalls==0,"real completed "+case.cohort+" battle")
  check(row.raw_party.size()==5 and row.initial_party.size()==5,"raw and processed inputs recorded")
  check(row.hp>=0 and row.mp>=0 and row.healing_observed>=0,"resource metrics bounded")
 check(Study.completed("gameover") and not Study.completed("step_limit"),"defeat and unfinished states distinguished")
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
