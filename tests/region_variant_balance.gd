extends SceneTree
const Study=preload("res://tools/simulate_region_variants.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
 var matrix=Study.case_matrix();var holdout=Study.case_matrix(false,true)
 check(matrix.size()==240 and holdout.size()==240,"two all-team variants cover 240 paired templates per cohort")
 check(Study.case_matrix(true).size()==4,"quick includes both variants and both policies")
 var profiles={};var captains={};var regions={};var kinds={};var core=0;var focus=0
 for i in matrix.size():
  var case=matrix[i]
  check(case.seed!=holdout[i].seed,"independent heldout seed")
  if case.cohort=="core":core+=1
  else:focus+=1;captains[case.captain]=true;profiles[case.profile]=true
  regions[case.region]=true;kinds[case.build]=true
 check(core==96 and focus==144,"96 core and 144 actual-character focus games")
 check(captains.size()==3 and profiles.size()==2 and regions.size()==6 and kinds.size()==2,"all captain/profile/region combinations retained")
 for case in Study.case_matrix(true):
  var setup=Study.prepare_setup(case)
  check(setup.relics.size()==4,"four relic budget")
  for entry in setup.relics:
   check(Study.Relic.definition(entry).scope=="team" and entry.owner=="","all-team variants have no illegal personal binding")
  check(setup.relics.map(func(entry):return entry.id)==Study.VARIANTS[case.build],"requested guard or assault ids used")
  var a=Study.Base.prepare_battle(case,setup)
  var b=Study.Base.prepare_battle(case,Study.prepare_setup(case))
  check(a.actors==b.actors and a.order==b.order and a.obstacles==b.obstacles,"same state setup deterministic")
  var original=case.duplicate(true);original.build="cross_blood_ward"
  var template_setup=Study.Base.prepare_setup(original)
  check(template_setup.party==setup.party and template_setup.equipment==setup.equipment,"variant preserves original funded party and gear")
  check(Study.Relic.resonance_counts(setup.relics)=={"blood":2,"ward":2},"exact two plus two themes")
  var row=Study.battle(case)
  check(Study.completed(row.outcome) and row.invalid_actions==0 and row.stalls==0,"real loop completes "+case.cohort+"/"+case.build)
  check(row.raw_party==setup.party and row.relics==setup.relics,"recorded inputs match used setup")
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
