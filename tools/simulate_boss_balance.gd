extends SceneTree
# Headless paired experiment. Loading this script as a resource does not run a study.
const Rules=preload("res://game/rules.gd")
const Jobs=preload("res://game/professions.gd")
const Relic=preload("res://game/relics.gd")
const REGIONS=["border","wood","waste","frost","marsh","ruins"]
const SEEDS=[21,42,73,104,137,211]
const BUILDS={"control":[],"blood":["blood_1","blood_3","blood_5","blood_7"],"hunt":["hunt_1","hunt_3","hunt_4","hunt_7"],"ward":["ward_1","ward_2","ward_3","ward_7"],"arcane":["arcane_1","arcane_2","arcane_4","arcane_6"]}
const OWNERS={"blood":"blade","hunt":"ranger","ward":"hero","arcane":"hero"}
const GEAR=[{"id":"sword","owner":"hero"},{"id":"dagger","owner":"blade"},{"id":"bow","owner":"ranger"},{"id":"staff","owner":"medic"},{"id":"crossbow","owner":"engineer"},{"id":"shield","owner":"hero"},{"id":"leather","owner":"blade"}]
const XP_BUDGET=300
const STEP_LIMIT=600
const POLICY="fixed identities; same legal 300XP-per-actor training budget and seven low-tier items (210 silver); dodge warnings without moving back; control pending ruins overload; support/cleanse/heal/mana, mark/trap, exact-damage safe hits, deterministic approach, paid rest; all AP/MP costs and relic drawbacks use real rules"
func _initialize():call_deferred("run")

static func prepare_case(build: String,resource: String) -> Dictionary:
 assert(BUILDS.has(build) and resource in ["full","depleted"])
 var units=Rules.new().default_party().slice(0,5)
 var training=[]
 for unit in units:
  unit.xp=XP_BUDGET
  var skills=Jobs.JOBS[unit.profession].skills
  for i in skills.size():
   var id=skills[i]
   var desired=2 if i<3 else 1
   while Jobs.skill_rank(unit,id)<desired:
    var reason=Jobs.training_reason(unit,id)
    assert(reason=="","Invalid funded training: "+id+" "+reason)
    var cost=Jobs.skill_cost(unit,id)
    unit.xp-=cost;unit.skill_ranks[id]=Jobs.skill_rank(unit,id)+1
    training.append({"actor":unit.id,"skill":id,"rank":unit.skill_ranks[id],"xp":cost})
  unit.merge(Jobs.stats(unit,GEAR),true)
  unit.hp=unit.max_hp if resource=="full" else maxi(1,int(floor(unit.max_hp*0.60)))
  unit.mp=unit.max_mp if resource=="full" else int(floor(unit.max_mp*0.35))
 var relics=[]
 for id in BUILDS[build]:
  var owner=OWNERS[build] if Relic.definition(id).scope=="personal" else ""
  relics.append(Relic.instance(id,relics.size()+1,owner))
 return {"party":units,"relics":relics,"equipment":GEAR.duplicate(true),"training":training,"xp_budget_per_actor":XP_BUDGET,"gear_silver":210}

static func case_matrix(quick: bool=false) -> Array:
 var result=[]
 for region in REGIONS:
  for seed_value in (SEEDS.slice(0,3) if quick else SEEDS):
   for resource in (["full"] if quick else ["full","depleted"]):
    for build in BUILDS:result.append({"region":region,"seed":seed_value,"resource":resource,"build":build})
 return result

static func cell_less(x: Vector2i,y: Vector2i) -> bool:
 return x.x<y.x if x.x!=y.x else x.y<y.y

static func safe_hit(b) -> Dictionary:
 var actor=b.active()
 var warned=b.boss_warnings()
 var best={};var score=-1;var ap_cost=999;var mp_cost=999
 for choice in b.auto_hits():
  if choice.action=="skill" and Jobs.ALL_SKILLS[choice.skill].get("base",choice.skill)=="dash":
   var landing=b.dash_landing(actor,b.find_actor(choice.target))
   if landing in warned:continue
  var copy=b.auto_snapshot()
  if choice.action=="attack":copy.attack(choice.target)
  else:copy.cast(choice.target,choice.skill)
  var damage=0
  for i in b.actors.size():
   if b.actors[i].side==1:damage+=maxi(0,b.actors[i].hp-copy.actors[i].hp)
  var ap=2 if choice.action=="attack" else Jobs.ALL_SKILLS[choice.skill].ap
  var mp=0 if choice.action=="attack" else b.skill_mana_cost(actor,choice.skill,choice.target)
  if damage>score or (damage==score and (ap<ap_cost or (ap==ap_cost and mp<mp_cost))):
   best=choice;score=damage;ap_cost=ap;mp_cost=mp
 return best

static func decide(b) -> Dictionary:
 if not b.can_act():return {"action":"outcome"}
 var actor=b.active()
 if actor.side==1:return {"action":"enemy"}
 var enemies=b.actors.filter(func(u):return u.side==1 and u.hp>0)
 if enemies.is_empty():return {"action":"end"}
 enemies.sort_custom(func(x,y):
  var dx=b.hex_distance(actor.cell,x.cell);var dy=b.hex_distance(actor.cell,y.cell)
  return x.hp<y.hp if dx==dy and x.hp!=y.hp else (str(x.id)<str(y.id) if dx==dy else dx<dy))
 var warned=b.boss_warnings()
 if actor.cell in warned:
  var escapes=[]
  for cell in b.cells():
   if cell in warned:continue
   var path=b.path_to(actor.cell,cell)
   if not path.is_empty() and b.movement_cost(actor,path)<=actor.ap:escapes.append({"cell":cell,"cost":b.movement_cost(actor,path)})
  escapes.sort_custom(func(x,y):return x.cost<y.cost if x.cost!=y.cost else cell_less(x.cell,y.cell))
  if not escapes.is_empty():return {"action":"move","target":escapes[0].cell,"reason":"dodge"}
 # A real stagger skill interrupts overload at its due boss turn.
 for intent in b.boss_intents:
  if intent.kind!="overload":continue
  var boss=b.find_actor(intent.source)
  if boss.is_empty() or boss.hp<=0 or boss.statuses.has("stagger"):continue
  for id in ["ranger_pin","bash","warden_rebuke"]:
   if b.can_cast(id,boss.id):return {"action":"skill","target":boss.id,"skill":id,"reason":"interrupt"}
 var allies=b.actors.filter(func(u):return u.side==0 and u.hp>0)
 allies.sort_custom(func(x,y):
  var rx=float(x.hp)/x.max_hp;var ry=float(y.hp)/y.max_hp
  return rx<ry if not is_equal_approx(rx,ry) else str(x.id)<str(y.id))
 if Jobs.job_id(actor)=="medic":
  for ally in allies:
   if ally.statuses.has("poison") or ally.statuses.has("chill") or ally.statuses.has("snare"):
    if b.can_cast("cleanse",ally.id):return {"action":"skill","target":ally.id,"skill":"cleanse","reason":"cleanse"}
  for ally in allies:
   if ally.max_hp-ally.hp>=20:
    for id in ["heal","medic_mend","medic_barrier"]:
     if b.can_cast(id,ally.id):return {"action":"skill","target":ally.id,"skill":id,"reason":"heal"}
  for ally in allies:
   if ally.mp<8 and b.can_cast("medic_channel",ally.id):return {"action":"skill","target":ally.id,"skill":"medic_channel","reason":"mana_support"}
  if not allies.is_empty() and not allies[0].statuses.has("shield") and enemies.any(func(e):return b.hex_distance(e.cell,allies[0].cell)<=3):
   if b.can_cast("cleanse",allies[0].id):return {"action":"skill","target":allies[0].id,"skill":"cleanse","reason":"shield"}
 if Jobs.job_id(actor)=="ranger" and actor.ap>=3:
  for target in enemies:
   if target.hp>=30 and not target.statuses.has("mark") and b.can_cast("mark",target.id):return {"action":"skill","target":target.id,"skill":"mark","reason":"mark"}
 if Jobs.job_id(actor)=="engineer" and not b.traps.any(func(t):return t.source==actor.id):
  for target in enemies:
   for direction in Rules.DIRS:
    var cell=target.cell+direction
    if cell not in warned and b.hex_distance(cell,actor.cell)<b.hex_distance(target.cell,actor.cell) and b.can_cast("trap",cell):return {"action":"skill","target":cell,"skill":"trap","reason":"trap"}
 var hit=safe_hit(b)
 if not hit.is_empty():return hit
 var approaches=[]
 for cell in b.cells():
  if cell in warned or not b.is_free(cell):continue
  if b.hex_distance(cell,enemies[0].cell)>=b.hex_distance(actor.cell,enemies[0].cell):continue
  var path=b.path_to(actor.cell,cell)
  if path.is_empty() or b.movement_cost(actor,path)>maxi(0,actor.ap-2):continue
  if path.any(func(step):return step in warned):continue
  approaches.append({"cell":cell,"distance":b.hex_distance(cell,enemies[0].cell),"cost":b.movement_cost(actor,path)})
 approaches.sort_custom(func(x,y):
  if x.distance!=y.distance:return x.distance<y.distance
  return x.cost<y.cost if x.cost!=y.cost else cell_less(x.cell,y.cell))
 if not approaches.is_empty():return {"action":"move","target":approaches[0].cell,"reason":"approach"}
 return {"action":"rest","target":"hp" if actor.hp*2<actor.max_hp else "mp"}

static func execute(b,decision: Dictionary) -> bool:
 match decision.get("action",""):
  "enemy":b.enemy_step();return true
  "attack":return b.attack(decision.target)
  "skill":return b.cast(decision.target,decision.skill)
  "move":return b.move_to(decision.target)
  "rest":return b.rest(decision.target)
  "end":return b.end_action()
 return false

static func battle(case: Dictionary) -> Dictionary:
 var setup=prepare_case(case.build,case.resource)
 var b=Rules.new();b.start_battle(setup.party,2,setup.relics,{"biome":case.region,"seed":case.seed,"threat":"boss"})
 var row=case.duplicate(true)
 row.merge({"win":false,"outcome":"","rounds":0,"deaths":0,"remaining_hp":0,"remaining_mp":0,"phase2_reached":false,"invalid_actions":0,"steps":0,"relics":setup.relics.duplicate(true),"policy_actions":{},"boss_cues":{},"initial_party":setup.party.duplicate(true),"initial_enemies":b.actors.filter(func(u):return u.side==1).duplicate(true)},true)
 var cue_index=0
 while b.outcome=="" and row.steps<STEP_LIMIT:
  var decision=decide(b)
  var key=str(decision.get("reason",decision.get("action","invalid")))
  row.policy_actions[key]=int(row.policy_actions.get(key,0))+1
  if not execute(b,decision):row.invalid_actions+=1;row.invalid_decision=decision;break
  row.steps+=1
  for unit in b.actors:
   if unit.get("boss",false) and int(unit.get("boss_phase",1))==2:row.phase2_reached=true
  while cue_index<b.boss_cues.size():
   var cue=b.boss_cues[cue_index];cue_index+=1
   row.boss_cues[cue.type]=int(row.boss_cues.get(cue.type,0))+1
 row.outcome=b.outcome if b.outcome!="" else ("invalid_action" if row.invalid_actions else "step_limit")
 row.win=row.outcome=="victory";row.rounds=b.round_no
 row.survivors=[]
 for unit in b.actors:
  if unit.side!=0:continue
  row.remaining_hp+=maxi(0,unit.hp);row.remaining_mp+=maxi(0,unit.mp)
  if unit.hp<=0:row.deaths+=1
  row.survivors.append({"id":unit.id,"hp":unit.hp,"mp":unit.mp})
 return row

static func source_hashes() -> Dictionary:
 var hashes={}
 for source in DirAccess.get_files_at("res://game"):
  if source.ends_with(".gd"):hashes["game/"+source]=FileAccess.get_sha256("res://game/"+source)
 hashes["tools/simulate_boss_balance.gd"]=FileAccess.get_sha256("res://tools/simulate_boss_balance.gd")
 return hashes
static func changed_sources(before: Dictionary) -> Array:
 var after=source_hashes();var changed=[]
 for path in before:
  if after.get(path,"")!=before[path]:changed.append(path)
 for path in after:
  if not before.has(path):changed.append(path)
 return changed
static func summarize(rows: Array) -> Dictionary:
 var summary={}
 for row in rows:
  var key=row.region+"/"+row.resource+"/"+row.build
  if not summary.has(key):summary[key]={"cases":0,"wins":0,"rounds":0,"deaths":0,"remaining_hp":0,"remaining_mp":0,"phase2_reached":0,"invalid_actions":0}
  var group=summary[key];group.cases+=1
  if row.win:group.wins+=1
  if row.phase2_reached:group.phase2_reached+=1
  for field in ["rounds","deaths","remaining_hp","remaining_mp","invalid_actions"]:group[field]+=row[field]
 for key in summary:
  var group=summary[key]
  group.win_rate=float(group.wins)/group.cases
  for field in ["rounds","deaths","remaining_hp","remaining_mp"]:group["mean_"+field]=float(group[field])/group.cases
 return summary

func run():
 var quick=false;var label="current"
 for arg in OS.get_cmdline_user_args():
  if arg=="--quick":quick=true
  elif arg.begins_with("--label="):label=arg.trim_prefix("--label=")
 if label not in ["current","baseline","tuned"]:
  push_error("label must be current, baseline or tuned");quit(2);return
 var hashes=source_hashes();var matrix=case_matrix(quick);var rows=[];var changed=[]
 var started=Time.get_unix_time_from_system()
 for case in matrix:
  rows.append(battle(case))
  if rows.size()%15==0:
   print("BOSS_BALANCE ",label," ",rows.size(),"/",matrix.size())
   await process_frame
   changed=changed_sources(hashes)
   if not changed.is_empty():break
 changed=changed_sources(hashes)
 var invalid=0
 for row in rows:invalid+=row.invalid_actions
 var complete=rows.size()==matrix.size()
 var report={"label":label,"quick":quick,"policy":POLICY,"difficulty":2,"resources":{"full":{"hp":1.0,"mp":1.0},"depleted":{"hp":0.60,"mp":0.35}},"training_xp_budget_per_actor":XP_BUDGET,"equipment":GEAR,"gear_silver":210,"builds":BUILDS,"source_hashes":hashes,"changed_sources":changed,"stale":not changed.is_empty(),"complete":complete,"valid":complete and changed.is_empty() and invalid==0,"expected_cases":matrix.size(),"completed_cases":rows.size(),"invalid_actions":invalid,"elapsed_seconds":Time.get_unix_time_from_system()-started,"results":rows,"summary":summarize(rows)}
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
 var destination="res://artifacts/boss-balance-"+label+".json"
 var file=FileAccess.open(destination,FileAccess.WRITE)
 if file==null:push_error("Cannot write "+destination);quit(2);return
 file.store_string(JSON.stringify(report,"  "));file.close()
 print("BOSS_BALANCE_DONE ",label," cases=",rows.size()," invalid=",invalid," stale=",report.stale," valid=",report.valid," seconds=",report.elapsed_seconds)
 quit(0 if report.valid else 1)
