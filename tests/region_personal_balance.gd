extends SceneTree
const Study=preload("res://tools/simulate_region_personal.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
 var matrix=Study.case_matrix();var holdout=Study.case_matrix(false,true)
 var originals=Study.Base.case_matrix().filter(func(case):return case.build=="cross_blood_ward")
 check(matrix.size()==120 and matrix==originals,"all and only original 120 personal ward templates")
 check(holdout.size()==120,"equal independent seed coverage")
 check(Study.case_matrix(false,false,true).size()==12,"12 focused tuning cases")
 check(Study.case_matrix(true).size()==2,"quick contains core and focus")
 var counts={"core":0,"focus":0};var regions={};var captains={};var profiles={}
 for i in matrix.size():
  var case=matrix[i];counts[case.cohort]+=1;regions[case.region]=true
  check(case.seed!=holdout[i].seed,"heldout seeds differ")
  check(case.build=="cross_blood_ward","unrelated builds not counted")
  if case.cohort=="focus":captains[case.captain]=true;profiles[case.profile]=true
 check(counts.core==48 and counts.focus==72,"48 core and 72 focus cases")
 check(regions.size()==6 and captains.size()==3 and profiles.size()==2,"same regions and actual character profiles")
 for case in Study.case_matrix(false,false,true):
  check(case.resource=="depleted" and (case.seed==21 if case.cohort=="core" else case.captain=="shen" and case.profile=="balanced"),"tuning subset stays independent of heldout")
 for case in Study.case_matrix(true):
  var setup=Study.Base.prepare_setup(case)
  check(setup.relics.map(func(entry):return entry.id)==["blood_1","blood_3","ward_1","ward_6"],"exact original personal ward loadout")
  var owner=setup.relics[-1].owner
  check(owner!="" and setup.party.any(func(unit):return unit.id==owner),"ward_6 bound to real deployed owner")
  var a=Study.Base.prepare_battle(case,setup);var b=Study.Base.prepare_battle(case)
  check(a.actors==b.actors and a.order==b.order and a.obstacles==b.obstacles,"same state starts without synthetic changes")
  var row=Study.Base.battle(case)
  check(Study.Base.completed(row.outcome) and row.invalid_actions==0 and row.stalls==0,"real Base loop exits cleanly")
  check(row.raw_party==setup.party and row.relics==setup.relics,"raw inputs retained for merged evidence")
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
