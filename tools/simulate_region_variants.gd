extends SceneTree
# Additional all-team blood/ward alternatives; the original retune driver remains frozen.
const Base=preload("res://tools/simulate_region_retune.gd")
const Player=Base.Player
const Mix=Base.Mix
const Relic=Base.Relic
const VARIANTS={
 "cross_blood_ward_guard":["blood_1","blood_3","ward_1","ward_2"],
 "cross_blood_ward_assault":["blood_1","blood_3","ward_1","ward_3"]}
func _initialize():call_deferred("run")
static func case_matrix(quick: bool=false,holdout: bool=false) -> Array:
 var templates=Base.case_matrix(false,holdout).filter(func(case):return case.build=="cross_blood_ward")
 if quick:
  var selected=[]
  for cohort in ["core","focus"]:
   selected.append(templates.filter(func(case):return case.cohort==cohort)[0])
  templates=selected
 var result=[]
 for template in templates:
  for variant in VARIANTS:
   var case=template.duplicate(true);case.build=variant
   result.append(case)
 return result
static func prepare_setup(case: Dictionary) -> Dictionary:
 var template=case.duplicate(true);template.build="cross_blood_ward"
 var setup=Base.prepare_setup(template);var entries=[]
 for id in VARIANTS[case.build]:entries.append(Relic.instance(id,entries.size()+1,""))
 setup.relics=entries
 return setup
static func completed(outcome: String) -> bool:
 return Base.completed(outcome)
static func battle(case: Dictionary) -> Dictionary:
 var setup=prepare_setup(case);var b=Base.prepare_battle(case,setup);var sim=Mix.new()
 var row=case.duplicate(true)
 row.merge({"outcome":"","win":false,"steps":0,"rounds":0,"deaths":0,"dead":[],"hp":0,"mp":0,"invalid_actions":0,"stalls":0,"phase2_reached":false,"actions":{},"skills":{},"enemy_skills":{},"cleanses":0,"relic_trigger_events":0,"healing_observed":0,"captain_damage":0,"other_damage":0,"raw_party":setup.party.duplicate(true),"initial_party":b.actors.filter(func(u):return u.side==0).duplicate(true),"initial_enemies":b.actors.filter(func(u):return u.side==1).duplicate(true),"map":b.obstacles.duplicate(),"relics":setup.relics.duplicate(true),"equipment":setup.equipment,"xp_budget_per_actor":setup.xp_budget_per_actor,"gear_silver":setup.gear_silver},true)
 var event_index=b.events.size();var cue_index=0
 while b.outcome=="" and row.steps<600:
  var before=JSON.stringify([b.actors,b.order_index,b.round_no,b.radius,b.boss_intents,b.outcome])
  var old_party=b.actors.filter(func(u):return u.side==0).duplicate(true)
  var old=b.active().duplicate(true);var action="focus_policy"
  var accepted=false
  if case.cohort=="core":
   var decision=Player.decide(b);action=decision.get("reason",decision.action)
   accepted=Player.execute(b,decision)
  else:
   accepted=sim.step(b)
  if not accepted:row.invalid_actions+=1;break
  row.actions[action]=int(row.actions.get(action,0))+1;row.steps+=1
  if before==JSON.stringify([b.actors,b.order_index,b.round_no,b.radius,b.boss_intents,b.outcome]):row.stalls+=1;break
  for unit in b.actors:
   if unit.get("boss",false) and int(unit.get("boss_phase",1))==2:row.phase2_reached=true
  for previous in old_party:
   var unit=b.find_actor(previous.id)
   row.healing_observed+=maxi(0,unit.hp-previous.hp)
   if old.side==1:
    var loss=maxi(0,previous.hp-unit.hp)
    row["captain_damage" if unit.id=="hero" else "other_damage"]+=loss
  while event_index<b.events.size():
   var event=str(b.events[event_index]);event_index+=1
   if event.begins_with("遗物触发"):row.relic_trigger_events+=1
  while cue_index<b.boss_cues.size():
   var cue=b.boss_cues[cue_index];cue_index+=1
   if cue.type=="enemy_skill":row.enemy_skills[cue.name]=int(row.enemy_skills.get(cue.name,0))+1
 for id in b.study_casts:row.skills[id]=int(row.skills.get(id,0))+1
 for id in row.skills:
  if id in ["cleanse","warden_ward"]:row.cleanses+=int(row.skills[id])
 row.outcome=b.outcome if b.outcome!="" else ("invalid_action" if row.invalid_actions else ("stall" if row.stalls else "step_limit"))
 row.win=row.outcome=="victory";row.rounds=b.round_no
 for unit in b.actors:
  if unit.side!=0:continue
  row.hp+=maxi(0,unit.hp);row.mp+=maxi(0,unit.mp)
  if unit.hp<=0:row.deaths+=1;row.dead.append(unit.get("character_id",unit.id))
 return row
static func source_hashes() -> Dictionary:
 var hashes=Base.source_hashes()
 hashes["tools/simulate_region_variants.gd"]=FileAccess.get_sha256("res://tools/simulate_region_variants.gd")
 return hashes
static func changed_sources(before: Dictionary) -> Array:
 var current=source_hashes();var changed=[]
 for source in before:
  if current.get(source,"")!=before[source]:changed.append(source)
 for source in current:
  if not before.has(source):changed.append(source)
 return changed
func run():
 var label="probe";var quick=false;var holdout=false
 for arg in OS.get_cmdline_user_args():
  if arg=="--quick":quick=true
  elif arg=="--holdout":holdout=true
  elif arg.begins_with("--label="):label=arg.trim_prefix("--label=")
 if label not in ["baseline","probe","final"]:push_error("Invalid label");quit(2);return
 var hashes=source_hashes();var rows=[];var matrix=case_matrix(quick,holdout);var started=Time.get_unix_time_from_system()
 for case in matrix:
  rows.append(battle(case))
  if rows.size()%12==0:
   print("REGION_VARIANTS ",rows.size(),"/",matrix.size());await process_frame
   if not changed_sources(hashes).is_empty():break
 var changed=changed_sources(hashes);var invalid=0;var stalls=0;var unfinished=0
 for row in rows:
  invalid+=row.invalid_actions;stalls+=row.stalls
  if not completed(row.outcome):unfinished+=1
 var report={"label":label,"quick":quick,"holdout":holdout,"expected_cases":matrix.size(),"completed_cases":rows.size(),"source_hashes":hashes,"changed_sources":changed,"valid":rows.size()==matrix.size() and changed.is_empty() and invalid==0 and stalls==0 and unfinished==0,"stale":not changed.is_empty(),"invalid_actions":invalid,"stalls":stalls,"unfinished":unfinished,"elapsed_seconds":Time.get_unix_time_from_system()-started,"variants":VARIANTS,"measurement":"same loop as frozen retune driver; healing_observed is net positive HP change including turn transitions, not pure healing; casts instrument successful authoritative cast()","matrix":"240 games: 96 core and 144 focus, replacing cross_blood_ward templates with two all-team 2+2 variants; same seeds/resources/affix slots/party/gear/training/policies as original templates","results":rows,"summary":Base.summarize(rows)}
 var suffix=("-holdout" if holdout else "")+("-quick" if quick else "")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
 var file=FileAccess.open("res://artifacts/region-variants-"+label+suffix+".json",FileAccess.WRITE)
 if file==null:push_error("Cannot write report");quit(2);return
 file.store_string(JSON.stringify(report,"  "));file.close()
 print("REGION_VARIANTS_DONE cases=",rows.size()," valid=",report.valid," stale=",report.stale," invalid=",invalid," stalls=",stalls," unfinished=",unfinished," seconds=",report.elapsed_seconds)
 quit(0 if report.valid else 1)
