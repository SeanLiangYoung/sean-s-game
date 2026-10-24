extends SceneTree
# Local replay of exactly the personal ward_6 blood/ward cases from the frozen matrix.
const Base=preload("res://tools/simulate_region_retune.gd")
func _initialize():call_deferred("run")
static func case_matrix(quick: bool=false,holdout: bool=false,tuning: bool=false) -> Array:
 var result=Base.case_matrix(false,holdout,tuning).filter(func(case):return case.build=="cross_blood_ward")
 if quick:
  var selected=[]
  for cohort in ["core","focus"]:
   var matches=result.filter(func(case):return case.cohort==cohort)
   if not matches.is_empty():selected.append(matches[0])
  return selected
 return result
static func source_hashes() -> Dictionary:
 var hashes=Base.source_hashes()
 hashes["tools/simulate_region_personal.gd"]=FileAccess.get_sha256("res://tools/simulate_region_personal.gd")
 return hashes
static func changed_sources(before: Dictionary) -> Array:
 var current=source_hashes();var changed=[]
 for source in before:
  if current.get(source,"")!=before[source]:changed.append(source)
 for source in current:
  if not before.has(source):changed.append(source)
 return changed
func run():
 var label="probe";var quick=false;var holdout=false;var tuning=false
 for arg in OS.get_cmdline_user_args():
  if arg=="--quick":quick=true
  elif arg=="--holdout":holdout=true
  elif arg=="--tuning":tuning=true
  elif arg.begins_with("--label="):label=arg.trim_prefix("--label=")
 if label not in ["baseline","probe","final"]:push_error("Invalid label");quit(2);return
 var hashes=source_hashes();var rows=[];var matrix=case_matrix(quick,holdout,tuning);var started=Time.get_unix_time_from_system()
 for case in matrix:
  rows.append(Base.battle(case))
  if rows.size()%12==0:
   print("REGION_PERSONAL ",rows.size(),"/",matrix.size());await process_frame
   if not changed_sources(hashes).is_empty():break
 var changed=changed_sources(hashes);var invalid=0;var stalls=0;var unfinished=0
 for row in rows:
  invalid+=row.invalid_actions;stalls+=row.stalls
  if not Base.completed(row.outcome):unfinished+=1
 var report={"label":label,"quick":quick,"holdout":holdout,"tuning":tuning,"expected_cases":matrix.size(),"completed_cases":rows.size(),"source_hashes":hashes,"changed_sources":changed,"valid":rows.size()==matrix.size() and changed.is_empty() and invalid==0 and stalls==0 and unfinished==0,"stale":not changed.is_empty(),"invalid_actions":invalid,"stalls":stalls,"unfinished":unfinished,"elapsed_seconds":Time.get_unix_time_from_system()-started,"measurement":"Direct Base.battle replay; only cross_blood_ward templates containing ward_6. Other cases are neither executed nor counted by this driver.","matrix":"120 games per seed cohort:48 core +72 focus, exact original cross_blood_ward cases; independent holdout uses original holdout seeds","results":rows,"summary":Base.summarize(rows)}
 var suffix=("-holdout" if holdout else "")+("-tuning" if tuning else "")+("-quick" if quick else "")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
 var file=FileAccess.open("res://artifacts/region-personal-"+label+suffix+".json",FileAccess.WRITE)
 if file==null:push_error("Cannot write report");quit(2);return
 file.store_string(JSON.stringify(report,"  "));file.close()
 print("REGION_PERSONAL_DONE cases=",rows.size()," valid=",report.valid," stale=",report.stale," invalid=",invalid," stalls=",stalls," unfinished=",unfinished," seconds=",report.elapsed_seconds)
 quit(0 if report.valid else 1)
