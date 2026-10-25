extends SceneTree
# Same case matrix and real rules in a frozen baseline project and the live project.
const Shared=preload("res://tools/simulate_enemy_coordination.gd")
const Player=preload("res://tools/simulate_boss_balance.gd")
const Mix=preload("res://tools/relic_mix_simulation.gd")
const Rules=preload("res://game/rules.gd")
const Relic=preload("res://game/relics.gd")
const Skills=preload("res://game/enemy_skills.gd")
const Region=preload("res://game/region_combat.gd")
const REGIONS=Player.REGIONS
const FOCUS_BUILDS=["cross_blood_ward","cross_arcane_pilgrim","blood","ward"]
const FOCUS_PROFILES=["balanced","hunt_guard"]
class StudyRules extends Rules:
 var preparing=true
 func auto_snapshot():
  var copy=super.auto_snapshot()
  copy.preparing=preparing
  return copy
 var study_casts=[]
 func cast(target,skill_id: String="") -> bool:
  var chosen=skill_id if skill_id!="" else default_skill(active())
  var accepted=super.cast(target,skill_id)
  if accepted:study_casts.append(chosen)
  return accepted
 func rebuild_order():
  if not preparing:super.rebuild_order()
func _initialize():call_deferred("run")
static func core_builds() -> Array:
 return ["control"]+Relic.Expansion.SETS.keys()+["cross_blood_ward"]
static func case_matrix(quick: bool=false,holdout: bool=false,tuning: bool=false) -> Array:
 var result=[];var seeds=[104,137] if holdout else [21,42]
 for ri in (1 if quick else REGIONS.size()):
  for si in (1 if quick or tuning else seeds.size()):
   for resource in (["full"] if quick else (["depleted"] if tuning else ["full","depleted"])):
    for bi in (1 if quick else core_builds().size()):
     for threat in (["boss"] if tuning else ["normal","boss"]):
      var index=ri*40+si*20+bi*2+(1 if resource=="depleted" else 0)
      result.append({"cohort":"core","region":REGIONS[ri],"seed":seeds[si],"resource":resource,"build":core_builds()[bi],"threat":threat,"captain":"default","profile":"balanced","affix":Skills.AFFIXES.keys()[index%Skills.AFFIXES.size()],"affix_slot":0 if index%2==0 else 3})
 for ri in (1 if quick else REGIONS.size()):
  for captain in (["shen"] if quick or tuning else Mix.Characters.CAPTAINS):
   for profile in (["balanced"] if quick or tuning else FOCUS_PROFILES):
    for resource in (["full"] if quick else (["depleted"] if tuning else ["full","depleted"])):
     for bi in (1 if quick else FOCUS_BUILDS.size()):
      var index=ri*24+Mix.Characters.CAPTAINS.find(captain)*8+FOCUS_PROFILES.find(profile)*4+bi
      result.append({"cohort":"focus","region":REGIONS[ri],"seed":211 if holdout else 73,"resource":resource,"build":FOCUS_BUILDS[bi],"threat":"boss","captain":captain,"profile":profile,"affix":Skills.AFFIXES.keys()[index%Skills.AFFIXES.size()],"affix_slot":0 if (index+int(resource=="depleted"))%2==0 else 3})
 return result
static func prepare_setup(case: Dictionary) -> Dictionary:
 if case.cohort=="core":return Shared.prepare_setup(case.build,case.resource)
 var sim=Mix.new();var units=sim.party(case.captain,case.profile)
 if case.resource=="depleted":
  for unit in units:unit.hp=int(unit.max_hp*0.7);unit.mp=int(unit.max_mp*0.5)
 var ids=Shared.MIXED_BUILDS[case.build] if Shared.MIXED_BUILDS.has(case.build) else Player.BUILDS[case.build]
 return {"party":units,"relics":sim.bound_entries(ids,units),"equipment":"same eleven low-tier items: one weapon and leather per actor, captain shield", "xp_budget_per_actor":Mix.XP_BUDGET,"gear_silver":330}
static func force_affix(b,case: Dictionary):
 var enemies=b.actors.filter(func(u):return u.side==1)
 for unit in enemies:
  var old=unit.get("affix","")
  if old=="vigor":unit.max_hp=int(floor(unit.max_hp/1.15));unit.hp=unit.max_hp
  if old=="brutal":unit.power=unit.base_enemy_power
  if old=="iron":unit.armor-=2
  if old=="swift":unit.speed-=2
  if old=="reach":unit.range-=1
  unit.erase("affix")
  Region.setup(b,unit,case.region,unit.boss)
 var target=enemies[case.affix_slot];target.affix=case.affix
 match case.affix:
  "vigor":target.max_hp+=maxi(1,int(ceil(target.max_hp*0.15)));target.hp=target.max_hp
  "brutal":target.power=mini(20,target.power+2)
  "iron":target.armor+=2
  "swift":target.speed+=2
  "reach":target.range+=1
  "warded":
   var current=10+int(target.get("statuses",{}).get("shield",{}).get("bonus",-10))
   b.put_status(target,"shield",target.id,current+4-10)
static func prepare_battle(case: Dictionary,setup: Dictionary={}):
 if setup.is_empty():setup=prepare_setup(case)
 var b=StudyRules.new();b.start_battle(setup.party,2,setup.relics,{"biome":case.region,"seed":case.seed,"threat":case.threat})
 force_affix(b,case);b.preparing=false;b.rebuild_order()
 return b
static func completed(outcome: String) -> bool:
 return outcome in ["victory","gameover","defeat"]
static func battle(case: Dictionary) -> Dictionary:
 var setup=prepare_setup(case);var b=prepare_battle(case,setup);var sim=Mix.new()
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
 var hashes=Shared.source_hashes()
 for source in ["tools/relic_mix_simulation.gd","tools/simulate_region_retune.gd"]:hashes[source]=FileAccess.get_sha256("res://"+source)
 return hashes
static func changed_sources(before: Dictionary) -> Array:
 var current=source_hashes();var changed=[]
 for source in before:
  if current.get(source,"")!=before[source]:changed.append(source)
 for source in current:
  if not before.has(source):changed.append(source)
 return changed
static func summarize(rows: Array) -> Dictionary:
 var result={}
 for row in rows:
  var key=row.cohort+"/"+row.region+"/"+row.resource+"/"+row.build
  if not result.has(key):result[key]={"cases":0,"wins":0,"deaths":0,"rounds":0,"hp":0,"mp":0,"cleanses":0,"healing_observed":0}
  var group=result[key];group.cases+=1;group.wins+=int(row.win)
  for field in ["deaths","rounds","hp","mp","cleanses","healing_observed"]:group[field]+=row[field]
 return result
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
  rows.append(battle(case))
  if rows.size()%12==0:
   print("REGION_RETUNE ",rows.size(),"/",matrix.size());await process_frame
   if not changed_sources(hashes).is_empty():break
 var changed=changed_sources(hashes);var invalid=0;var stalls=0;var unfinished=0
 for row in rows:
  invalid+=row.invalid_actions;stalls+=row.stalls
  if not completed(row.outcome):unfinished+=1
 var report={"label":label,"quick":quick,"holdout":holdout,"tuning":tuning,"expected_cases":matrix.size(),"completed_cases":rows.size(),"source_hashes":hashes,"changed_sources":changed,"valid":rows.size()==matrix.size() and changed.is_empty() and invalid==0 and stalls==0 and unfinished==0,"stale":not changed.is_empty(),"invalid_actions":invalid,"stalls":stalls,"unfinished":unfinished,"elapsed_seconds":Time.get_unix_time_from_system()-started,"measurement":"healing_observed is positive net HP change across actions including turn transitions, not healing-only attribution; captain/other damage is net loss during enemy actions; skill counts instrument successful real cast() calls in both cohorts, isolated snapshot casts do not enter the authoritative array","core_policy":Player.POLICY,"focus_policy":"Mix.step: real identity talents, support/cleanse/guard/one mark per action/trap/real damage and retreat rules, equal 360XP budget and 330 silver gear","matrix":"480 core:6 regions x2 seeds x2 resources x10 builds x2 threats;288 focus:6 regions x3 captains x2 profiles x2 resources x4 builds x1 independent seed; affixes/slots stratified across cases","results":rows,"summary":summarize(rows)}
 var suffix=("-holdout" if holdout else "")+("-tuning" if tuning else "")+("-quick" if quick else "")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
 var file=FileAccess.open("res://artifacts/region-retune-"+label+suffix+".json",FileAccess.WRITE)
 if file==null:push_error("Cannot write report");quit(2);return
 file.store_string(JSON.stringify(report,"  "));file.close()
 print("REGION_RETUNE_DONE cases=",rows.size()," valid=",report.valid," stale=",report.stale," invalid=",invalid," stalls=",stalls," unfinished=",unfinished," seconds=",report.elapsed_seconds)
 quit(0 if report.valid else 1)
