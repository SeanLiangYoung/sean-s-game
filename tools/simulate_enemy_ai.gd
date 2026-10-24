extends SceneTree
# Paired policy study: all combat numbers and player decisions use production rules.
const Player=preload("res://tools/simulate_boss_balance.gd")
const Rules=preload("res://game/rules.gd")
const Skills=preload("res://game/enemy_skills.gd")
const Region=preload("res://game/region_combat.gd")
const REGIONS=Player.REGIONS
const POLICIES=["classic","tactical"]
func _initialize():call_deferred("run")
static func case_matrix(quick: bool=false) -> Array:
 var result=[]
 for region in (REGIONS.slice(0,1) if quick else REGIONS):
  for seed_value in ([21] if quick else [21,42,73]):
   for resource in (["full"] if quick else ["full","depleted"]):
    for build in (["control"] if quick else ["control","blood","ward","arcane"]):
     for threat in ["normal","boss"]:
      for policy in POLICIES:result.append({"region":region,"seed":seed_value,"resource":resource,"build":build,"threat":threat,"policy":policy,"affix":"generated","mix":"native"})
 for region in (REGIONS.slice(0,1) if quick else REGIONS):
  for affix in (Skills.AFFIXES.keys().slice(0,1) if quick else Skills.AFFIXES.keys()):
   for mix in ["ranged","assault"]:
    for policy in POLICIES:result.append({"region":region,"seed":42,"resource":"full","build":"ward","threat":"boss","policy":policy,"affix":affix,"mix":mix})
 return result

static func prepare_battle(case: Dictionary):
 var setup=Player.prepare_case(case.build,case.resource)
 var b=Rules.new();b.start_battle(setup.party,2,setup.relics,{"biome":case.region,"seed":case.seed,"threat":case.threat})
 if case.get("mix","native")=="native":return b
 # Replay generation's two draws per enemy to restore the exact unempowered HP.
 # Undo only the generated affix, then rebuild native barriers through Regional.setup.
 var rng=RandomNumberGenerator.new();rng.seed=case.seed
 var enemies=b.actors.filter(func(u):return u.side==1)
 for i in enemies.size():
  var unit=enemies[i];var old=unit.get("affix","")
  var ranged_limit=2 if case.region in ["wood","marsh"] else 1
  var bruiser=i==enemies.size()-1 and i>=ranged_limit
  var original_hp=58+rng.randi_range(0,8)+(8 if bruiser else 0)+(48 if unit.boss else 0)
  rng.randi_range(0,3)
  unit.max_hp=original_hp;unit.hp=original_hp
  if old=="brutal":unit.power=unit.base_enemy_power
  if old=="iron":unit.armor-=2
  if old=="swift":unit.speed-=2
  if old=="reach":unit.range-=1
  unit.erase("affix")
  var home=case.region
  if not unit.boss:
   # Two ranged + one assault, or one ranged + two assault; use real regional skills.
   unit.range=3 if i<(2 if case.mix=="ranged" else 1) else 1
   home=REGIONS[(REGIONS.find(case.region)+i)%REGIONS.size()]
  Region.setup(b,unit,home,unit.boss)
 var target=enemies[0];target.affix=case.affix
 match case.affix:
  "vigor":target.max_hp+=maxi(1,int(ceil(target.max_hp*0.15)));target.hp=target.max_hp
  "brutal":target.power=mini(20,target.power+2)
  "iron":target.armor=target.get("armor",0)+2
  "swift":target.speed+=2
  "reach":target.range+=1
  "warded":
   var current=10+int(target.get("statuses",{}).get("shield",{}).get("bonus",-10))
   b.put_status(target,"shield",target.id,current+4-10)
 # Affix speed changes the real initiative order, equally in both arms.
 b.order.sort_custom(func(x,y):return b.actors[x].speed>b.actors[y].speed if b.actors[x].speed!=b.actors[y].speed else x<y)
 return b

# Frozen pre-tactical enemy_step, including its original stable nearest-cell ordering.
static func classic_step(b) -> String:
 if not b.can_act() or b.active().side!=1:return "inactive"
 var a=b.active()
 if Skills.choose(b,a):b.after_action();return "classic_skill_first"
 var targets=b.actors.filter(func(u):return u.side==0 and u.hp>0)
 if targets.is_empty():b.check_outcome();return "outcome"
 targets.sort_custom(func(x,y):return b.hex_distance(a.cell,x.cell)<b.hex_distance(a.cell,y.cell))
 for target in targets:
  if b.hex_distance(a.cell,target.cell)<=a.range and a.ap>=2:
   b.attack(target.id);return "classic_nearest_attack"
 if a.ap>0:
  var target=targets[0]
  var candidates=b.cells().filter(func(c):return b.is_free(c))
  candidates.sort_custom(func(x,y):return b.hex_distance(x,target.cell)<b.hex_distance(y,target.cell))
  for cell in candidates:
   if b.hex_distance(cell,target.cell)>=b.hex_distance(a.cell,target.cell):continue
   var path=b.path_to(a.cell,cell)
   if path.is_empty():continue
   var steps=mini(path.size(),maxi(1,a.ap-2))
   b.move_to(path[steps-1]);return "classic_nearest_approach"
 b.rest("hp");return "classic_rest"

static func battle(case: Dictionary) -> Dictionary:
 var b=prepare_battle(case)
 var row=case.duplicate(true)
 row.merge({"win":false,"outcome":"","rounds":0,"deaths":0,"remaining_hp":0,"remaining_mp":0,"phase2_reached":false,"invalid_actions":0,"stalls":0,"steps":0,"policy_actions":{},"ai_reasons":{},"boss_cues":{},"skills":{},"initial_party":b.actors.filter(func(u):return u.side==0).duplicate(true),"initial_enemies":b.actors.filter(func(u):return u.side==1).duplicate(true),"map":b.obstacles.duplicate()},true)
 var cue_index=0
 while b.outcome=="" and row.steps<Player.STEP_LIMIT:
  var before=JSON.stringify([b.actors,b.order_index,b.round_no,b.radius,b.boss_intents,b.outcome])
  var decision=Player.decide(b)
  var key=str(decision.get("reason",decision.get("action","invalid")))
  row.policy_actions[key]=int(row.policy_actions.get(key,0))+1
  if decision.action=="enemy":
   var reason="tactical"
   if case.policy=="classic":reason=classic_step(b)
   else:
    b.enemy_step()
    for property in b.get_property_list():
     if property.name=="last_enemy_decision":reason=str(b.get("last_enemy_decision").get("reason","tactical"))
   row.ai_reasons[reason]=int(row.ai_reasons.get(reason,0))+1
  elif not Player.execute(b,decision):row.invalid_actions+=1;row.invalid_decision=decision;break
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
 var hashes=Player.source_hashes()
 hashes["tools/simulate_enemy_ai.gd"]=FileAccess.get_sha256("res://tools/simulate_enemy_ai.gd")
 return hashes
static func changed_sources(before: Dictionary) -> Array:
 var after=source_hashes();var changed=[]
 for path in before:
  if after.get(path,"")!=before[path]:changed.append(path)
 for path in after:
  if not before.has(path):changed.append(path)
 return changed
static func summarize(rows: Array) -> Dictionary:
 var result={}
 for row in rows:
  var key=row.policy+"/"+row.region+"/"+row.threat+"/"+row.resource+"/"+row.build+"/"+row.mix
  if not result.has(key):result[key]={"cases":0,"wins":0,"deaths":0,"rounds":0,"remaining_hp":0,"remaining_mp":0,"invalid_actions":0,"stalls":0,"phase2_reached":0}
  var group=result[key];group.cases+=1
  if row.win:group.wins+=1
  if row.phase2_reached:group.phase2_reached+=1
  for field in ["deaths","rounds","remaining_hp","remaining_mp","invalid_actions","stalls"]:group[field]+=row[field]
 for group in result.values():group.win_rate=float(group.wins)/group.cases
 return result
func run():
 var quick=false;var label="current"
 for arg in OS.get_cmdline_user_args():
  if arg=="--quick":quick=true
  elif arg.begins_with("--label="):label=arg.trim_prefix("--label=")
 if label not in ["baseline","current","final"]:push_error("Invalid study label");quit(2);return
 var hashes=source_hashes();var rows=[];var matrix=case_matrix(quick);var started=Time.get_unix_time_from_system()
 for case in matrix:
  rows.append(battle(case))
  if rows.size()%8==0:
   print("ENEMY_AI_BALANCE ",rows.size(),"/",matrix.size());await process_frame
   if not changed_sources(hashes).is_empty():break
 var changed=changed_sources(hashes);var invalid=0;var stalls=0;var unfinished=0
 for row in rows:
  invalid+=row.invalid_actions;stalls+=row.stalls
  if row.outcome not in ["victory","gameover"]:unfinished+=1
 var report={"label":label,"quick":quick,"expected_cases":matrix.size(),"completed_cases":rows.size(),"source_hashes":hashes,"changed_sources":changed,"stale":not changed.is_empty(),"valid":rows.size()==matrix.size() and changed.is_empty() and invalid==0 and unfinished==0,"invalid_actions":invalid,"stalls":stalls,"unfinished":unfinished,"elapsed_seconds":Time.get_unix_time_from_system()-started,"player_policy":Player.POLICY,"resources":{"full":{"hp":1.0,"mp":1.0},"depleted":{"hp":0.60,"mp":0.35}},"builds":["control","blood","ward","arcane"],"equipment":Player.GEAR,"training_xp_budget_per_actor":300,"training_spent_per_actor":285,"gear_silver":210,"difficulty":2,"matrix":"576 core games: 6 regions x 3 seeds x 2 resources x 4 builds x 2 threats x 2 policies; 168 stress: 6 regions x 7 affixes x 2 mixed lineups x 2 policies","results":rows,"summary":summarize(rows)}
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
 var file=FileAccess.open("res://artifacts/enemy-ai-balance-"+label+".json",FileAccess.WRITE)
 if file==null:push_error("Cannot write study");quit(2);return
 file.store_string(JSON.stringify(report,"  "));file.close()
 print("ENEMY_AI_BALANCE_DONE cases=",rows.size()," valid=",report.valid," stale=",report.stale," invalid=",invalid," stalls=",stalls," seconds=",report.elapsed_seconds)
 quit(0 if report.valid else 1)
