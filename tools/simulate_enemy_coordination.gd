extends SceneTree
# Three policies, identical real-rule starts. Frozen planners are tooling only.
const Player=preload("res://tools/simulate_boss_balance.gd")
const Earlier=preload("res://tools/simulate_enemy_ai.gd")
const Previous=preload("res://tools/enemy_ai_previous.gd")
const Rules=preload("res://game/rules.gd")
const Skills=preload("res://game/enemy_skills.gd")
const Region=preload("res://game/region_combat.gd")
const Relic=preload("res://game/relics.gd")
const Jobs=preload("res://game/professions.gd")
const REGIONS=Player.REGIONS
const POLICIES=["classic","previous","current"]
const PROFILES=["balanced","root_focus","branch_focus"]
const MIXED_BUILDS={
 "cross_blood_ward":["blood_1","blood_3","ward_1","ward_6"],
 "cross_hunt_engine":["hunt_1","hunt_3","engine_1","engine_6"],
 "cross_arcane_pilgrim":["arcane_1","arcane_4","pilgrim_1","pilgrim_6"],
 "base_risk":["banner","mist","fang","cog"],
 "base_guard":["bastion","wardbell","candle","shell"],
 "base_mana":["rune","reservoir","echo","tide"]}
const OWNERS={"blood":"blade","hunt":"ranger","ward":"hero","arcane":"hero","engine":"engineer","pilgrim":"medic","dusk":"blade","command":"hero"}
# start_battle normally begins initiative immediately. Defer it until forced affix
# setup is complete, so the first actor's regen/barriers/CD trigger exactly once.
class StudyRules extends Rules:
 var preparing=true
 func rebuild_order():
  if not preparing:super.rebuild_order()
func _initialize():call_deferred("run")
static func stress_builds() -> Array:
 return Relic.Expansion.SETS.keys()+MIXED_BUILDS.keys()
static func case_matrix(quick: bool=false,holdout: bool=false,tuning: bool=false) -> Array:
 var result=[]
 var seeds=[104,137,211] if holdout else [21,42,73]
 for region in (REGIONS.slice(0,1) if quick else REGIONS):
  for seed_value in (seeds.slice(0,1) if quick else seeds):
   for resource in (["full"] if quick else ["full","depleted"]):
    for build in (["control"] if quick else Player.BUILDS.keys()):
     for threat in ["normal","boss"]:
      for policy in POLICIES:result.append({"cohort":"core","region":region,"seed":seed_value,"resource":resource,"build":build,"threat":threat,"policy":policy,"affix":"generated","mix":"native","profile":"balanced","affix_slot":-1})
 if tuning:return result.filter(func(case):return case.seed==seeds[0])
 var builds=stress_builds()
 for region_index in (1 if quick else REGIONS.size()):
  var region=REGIONS[region_index]
  for affix_index in (1 if quick else Skills.AFFIXES.size()):
   for resource_index in (1 if quick else 2):
    for mix_index in 2:
     var index=region_index*28+affix_index*4+resource_index*2+mix_index
     var build=builds[index%builds.size()]
     var seed_value=seeds[(affix_index+mix_index)%seeds.size()]
     for slot in [0,3]:
      for policy in POLICIES:
       result.append({"cohort":"stress","region":region,"seed":seed_value,"resource":"full" if resource_index==0 else "depleted","build":build,"threat":"boss","policy":policy,"affix":Skills.AFFIXES.keys()[affix_index],"mix":"ranged" if mix_index==0 else "assault","profile":PROFILES[index%PROFILES.size()],"affix_slot":slot})
 return result

static func prepare_setup(build: String,resource: String,profile: String="balanced") -> Dictionary:
 assert(profile in PROFILES and resource in ["full","depleted"])
 if Player.BUILDS.has(build) and profile=="balanced":return Player.prepare_case(build,resource)
 var units=Rules.new().default_party().slice(0,5);var training=[]
 for unit in units:
  unit.xp=Player.XP_BUDGET
  var skills=Jobs.JOBS[unit.profession].skills
  var focus=skills[2 if unit.profession in ["engineer","warden"] else 1]
  var ranks=[2,2,2,1,1,1]
  if profile!="balanced":
   ranks=[3 if profile=="root_focus" else 2,1,1,0,0,0]
   ranks[skills.find(focus)]=2 if profile=="root_focus" else 3
   for index in range(3,skills.size()):
    if Jobs.prerequisite(skills[index])==focus:ranks[index]=1
  for i in skills.size():
   var id=skills[i];var desired=ranks[i]
   while Jobs.skill_rank(unit,id)<desired:
    assert(Jobs.training_reason(unit,id)=="","Illegal training "+id)
    var cost=Jobs.skill_cost(unit,id);unit.xp-=cost
    unit.skill_ranks[id]=Jobs.skill_rank(unit,id)+1
    training.append({"actor":unit.id,"skill":id,"rank":unit.skill_ranks[id],"xp":cost})
  unit.merge(Jobs.stats(unit,Player.GEAR),true)
  unit.hp=unit.max_hp if resource=="full" else maxi(1,int(floor(unit.max_hp*0.60)))
  unit.mp=unit.max_mp if resource=="full" else int(floor(unit.max_mp*0.35))
 var ids=[]
 if Player.BUILDS.has(build):ids=Player.BUILDS[build]
 elif MIXED_BUILDS.has(build):ids=MIXED_BUILDS[build]
 else:
  assert(Relic.Expansion.SETS.has(build),"Unknown study build "+build)
  ids=[build+"_1",build+"_2",build+"_3",build+"_6"]
 var relics=[];var owners=[]
 for id in ids:
  var owner=""
  if Relic.definition(id).scope=="personal":
   owner=OWNERS.get(build,"hero")
   if owner in owners:
    owner=units.filter(func(u):return u.id not in owners)[0].id
   owners.append(owner)
  relics.append(Relic.instance(id,relics.size()+1,owner))
 return {"party":units,"relics":relics,"equipment":Player.GEAR.duplicate(true),"training":training,"xp_budget_per_actor":Player.XP_BUDGET,"gear_silver":210}

static func prepare_battle(case: Dictionary):
 var setup=prepare_setup(case.build,case.resource,case.get("profile","balanced"))
 var b=StudyRules.new();b.start_battle(setup.party,2,setup.relics,{"biome":case.region,"seed":case.seed,"threat":case.threat})
 if case.get("mix","native")!="native" or case.affix!="generated":
  var enemies=b.actors.filter(func(u):return u.side==1)
  for i in enemies.size():
   var unit=enemies[i];var old=unit.get("affix","")
   # Undo only the generated affix; no hardcoded enemy HP/stat baseline.
   if old=="vigor":unit.max_hp=int(floor(unit.max_hp/1.15));unit.hp=unit.max_hp
   if old=="brutal":unit.power=unit.base_enemy_power
   if old=="iron":unit.armor-=2
   if old=="swift":unit.speed-=2
   if old=="reach":unit.range-=1
   unit.erase("affix")
   var home=case.region
   if not unit.boss and case.get("mix","native")!="native":
    unit.range=3 if i<(2 if case.mix=="ranged" else 1) else 1
    home=REGIONS[(REGIONS.find(case.region)+i)%REGIONS.size()]
   Region.setup(b,unit,home,unit.boss)
  if case.affix!="":
   var target=enemies[clampi(case.get("affix_slot",0),0,enemies.size()-1)];target.affix=case.affix
   match case.affix:
    "vigor":target.max_hp+=maxi(1,int(ceil(target.max_hp*0.15)));target.hp=target.max_hp
    "brutal":target.power=mini(20,target.power+2)
    "iron":target.armor+=2
    "swift":target.speed+=2
    "reach":target.range+=1
    "warded":
     var current=10+int(target.get("statuses",{}).get("shield",{}).get("bonus",-10))
     b.put_status(target,"shield",target.id,current+4-10)
 b.preparing=false;b.rebuild_order()
 return b

static func execute_previous(b) -> Dictionary:
 var decision=Previous.decide(b);var accepted=false
 match decision.get("action",""):
  "attack":accepted=b.attack(decision.target)
  "skill":accepted=b.cast_enemy_skill(decision.skill,decision.get("target"))
  "move":accepted=b.move_to(decision.target)
  "rest":accepted=b.rest(decision.target)
  "end":accepted=b.end_action()
 decision.accepted=accepted
 return decision
static func completed(outcome: String) -> bool:
 return outcome in ["victory","gameover","defeat"]
static func battle(case: Dictionary) -> Dictionary:
 var b=prepare_battle(case);var setup=prepare_setup(case.build,case.resource,case.get("profile","balanced"))
 var row=case.duplicate(true)
 row.merge({"win":false,"outcome":"","rounds":0,"deaths":0,"remaining_hp":0,"remaining_mp":0,"phase2_reached":false,"invalid_actions":0,"stalls":0,"steps":0,"policy_actions":{},"ai_reasons":{},"boss_cues":{},"skills":{},"captain_damage":0,"other_damage":0,"captain_hits":0,"other_hits":0,"target_hits":{},"initial_party":b.actors.filter(func(u):return u.side==0).duplicate(true),"initial_enemies":b.actors.filter(func(u):return u.side==1).duplicate(true),"map":b.obstacles.duplicate(),"relics":setup.relics,"training":setup.training},true)
 var cue_index=0
 while b.outcome=="" and row.steps<Player.STEP_LIMIT:
  var before=JSON.stringify([b.actors,b.order_index,b.round_no,b.radius,b.boss_intents,b.outcome])
  var old_party=b.actors.filter(func(u):return u.side==0).duplicate(true)
  var decision=Player.decide(b)
  var key=str(decision.get("reason",decision.get("action","invalid")))
  row.policy_actions[key]=int(row.policy_actions.get(key,0))+1
  if decision.action=="enemy":
   var reason=""
   if case.policy=="classic":reason=Earlier.classic_step(b)
   elif case.policy=="previous":
    var prior=execute_previous(b);reason=str(prior.get("reason","previous"))
    if not prior.accepted:row.invalid_actions+=1;row.invalid_decision=prior;break
   else:
    b.enemy_step();reason=str(b.last_enemy_decision.get("reason","current"))
   row.ai_reasons[reason]=int(row.ai_reasons.get(reason,0))+1
  elif not Player.execute(b,decision):row.invalid_actions+=1;row.invalid_decision=decision;break
  # HP loss during enemy actions includes their direct damage, due warnings and
  # turn-transition effects. Track it as observed pressure, not direct-only hits.
  if decision.action=="enemy":
   for old in old_party:
    var unit=b.find_actor(old.id);var loss=maxi(0,old.hp-unit.hp)
    if loss<=0:continue
    var prefix="captain" if unit.id=="hero" else "other"
    row[prefix+"_damage"]+=loss;row[prefix+"_hits"]+=1
    row.target_hits[unit.id]=int(row.target_hits.get(unit.id,0))+1
  row.steps+=1
  if before==JSON.stringify([b.actors,b.order_index,b.round_no,b.radius,b.boss_intents,b.outcome]):row.stalls+=1;break
  for unit in b.actors:
   if unit.get("boss",false) and int(unit.get("boss_phase",1))==2:row.phase2_reached=true
  while cue_index<b.boss_cues.size():
   var cue=b.boss_cues[cue_index];cue_index+=1
   row.boss_cues[cue.type]=int(row.boss_cues.get(cue.type,0))+1
   if cue.type=="enemy_skill":row.skills[cue.name]=int(row.skills.get(cue.name,0))+1
 row.outcome=b.outcome if b.outcome!="" else ("invalid_action" if row.invalid_actions else ("stall" if row.stalls else "step_limit"))
 row.win=row.outcome=="victory";row.rounds=b.round_no
 for unit in b.actors:
  if unit.side!=0:continue
  row.remaining_hp+=maxi(0,unit.hp);row.remaining_mp+=maxi(0,unit.mp)
  if unit.hp<=0:row.deaths+=1
 return row
static func source_hashes() -> Dictionary:
 var hashes=Earlier.source_hashes()
 for source in ["tools/enemy_ai_previous.gd","tools/simulate_enemy_coordination.gd"]:hashes[source]=FileAccess.get_sha256("res://"+source)
 return hashes
static func changed_sources(before: Dictionary) -> Array:
 var after=source_hashes();var changed=[]
 for source in before:
  if after.get(source,"")!=before[source]:changed.append(source)
 for source in after:
  if not before.has(source):changed.append(source)
 return changed
static func summarize(rows: Array) -> Dictionary:
 var result={}
 for row in rows:
  var key=row.policy+"/"+row.region+"/"+row.resource+"/"+row.cohort
  if not result.has(key):result[key]={"cases":0,"wins":0,"deaths":0,"rounds":0,"remaining_hp":0,"remaining_mp":0,"captain_damage":0,"other_damage":0,"captain_hits":0,"other_hits":0,"invalid_actions":0,"stalls":0,"phase2_reached":0}
  var group=result[key];group.cases+=1
  if row.win:group.wins+=1
  if row.phase2_reached:group.phase2_reached+=1
  for field in ["deaths","rounds","remaining_hp","remaining_mp","captain_damage","other_damage","captain_hits","other_hits","invalid_actions","stalls"]:group[field]+=row[field]
 for group in result.values():group.win_rate=float(group.wins)/group.cases
 return result
func run():
 var quick=false;var label="probe";var holdout=false;var tuning=false;var policy_filter=""
 for arg in OS.get_cmdline_user_args():
  if arg=="--quick":quick=true
  elif arg=="--holdout":holdout=true
  elif arg=="--tuning":tuning=true
  elif arg.begins_with("--label="):label=arg.trim_prefix("--label=")
  elif arg.begins_with("--policy="):policy_filter=arg.trim_prefix("--policy=")
 if label not in ["baseline","probe","final"] or (policy_filter!="" and policy_filter not in POLICIES):push_error("Invalid study arguments");quit(2);return
 var hashes=source_hashes();var rows=[];var matrix=case_matrix(quick,holdout,tuning);var started=Time.get_unix_time_from_system()
 if policy_filter!="":matrix=matrix.filter(func(case):return case.policy==policy_filter)
 for case in matrix:
  rows.append(battle(case))
  if rows.size()%12==0:
   print("ENEMY_COORDINATION ",rows.size(),"/",matrix.size());await process_frame
   if not changed_sources(hashes).is_empty():break
 var changed=changed_sources(hashes);var invalid=0;var stalls=0;var unfinished=0
 for row in rows:
  invalid+=row.invalid_actions;stalls+=row.stalls
  if not completed(row.outcome):unfinished+=1
 var report={"label":label,"quick":quick,"holdout":holdout,"tuning":tuning,"policy_filter":policy_filter,"expected_cases":matrix.size(),"completed_cases":rows.size(),"source_hashes":hashes,"changed_sources":changed,"stale":not changed.is_empty(),"valid":rows.size()==matrix.size() and changed.is_empty() and invalid==0 and stalls==0 and unfinished==0,"invalid_actions":invalid,"stalls":stalls,"unfinished":unfinished,"elapsed_seconds":Time.get_unix_time_from_system()-started,"player_policy":Player.POLICY,"pressure_measure":"actual HP loss observed during enemy actions including turn-transition effects, not direct-only damage","resources":{"full":{"hp":1.0,"mp":1.0},"depleted":{"hp":0.60,"mp":0.35}},"stress_builds":stress_builds(),"skill_profiles":PROFILES,"equipment":Player.GEAR,"training_xp_budget_per_actor":300,"training_spent_per_actor":285,"gear_silver":210,"difficulty":2,"matrix":"1080 core games: 6 regions x 3 seeds x 2 resources x 5 builds x 2 threats x 3 policies; 1008 stress: 6 regions x 7 affixes x 2 resources x 2 mixed lineups x 2 affix slots x 3 policies, rotating all relic themes, cross-theme/base builds, three funded skill profiles and ordinary/boss affix slots","results":rows,"summary":summarize(rows)}
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
 var suffix=("-holdout" if holdout else "")+("-tuning" if tuning else "")+("-"+policy_filter if policy_filter!="" else "")+("-quick" if quick else "")
 var file=FileAccess.open("res://artifacts/enemy-coordination-"+label+suffix+".json",FileAccess.WRITE)
 if file==null:push_error("Cannot write study");quit(2);return
 file.store_string(JSON.stringify(report,"  "));file.close()
 print("ENEMY_COORDINATION_DONE cases=",rows.size()," valid=",report.valid," stale=",report.stale," invalid=",invalid," stalls=",stalls," unfinished=",unfinished," seconds=",report.elapsed_seconds)
 quit(0 if report.valid else 1)
