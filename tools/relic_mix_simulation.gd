extends RefCounted
const Rules=preload("res://game/rules.gd")
const Jobs=preload("res://game/professions.gd")
const Characters=preload("res://game/characters.gd")
const Relic=preload("res://game/relics.gd")
const XP_BUDGET=360
const REGIONS=["border","wood","waste","frost","marsh","ruins"]
const PROFILES={
 "balanced":["aling","ya","bai","li"],
 "hunt_guard":["pei","lin","wenlan","qin"],
 "sustain_guard":["chi","qing","ji","yue"],
 "control_support":["suo","tang","bai","luosui"],
 "no_medic":["aling","pei","ya","qin"],
 "double_medic":["qing","wenlan","ji","yue"]}
const CORE={"blood":[1,3],"hunt":[3,4],"ward":[1,3],"arcane":[1,4],"engine":[1,2],"pilgrim":[1,2],"dusk":[1,2],"command":[1,2]}
const OWNER_JOB={"blood":"blade","hunt":"ranger","ward":"hero","arcane":"hero","engine":"engineer","pilgrim":"medic","dusk":"ranger","command":"blade"}
var invalid_actions=0
var support_ai=false
func loadouts() -> Dictionary:
 var result={"none":[]}
 var families=CORE.keys()
 for family in families:
  var ids=CORE[family].map(func(index):return "%s_%d"%[family,index])
  var available=[1,2,3,4,5].filter(func(index):return index not in CORE[family])
  result["pure_team_"+family]=ids+["%s_%d"%[family,available[0]],"%s_%d"%[family,available[1]]]
  result["pure_personal_"+family]=ids+["%s_%d"%[family,available[0]],family+"_6"]
 for i in families.size():
  for j in range(i+1,families.size()):
   var a=families[i];var b=families[j]
   result["mix_"+a+"_"+b]=CORE[a].map(func(index):return "%s_%d"%[a,index])+CORE[b].map(func(index):return "%s_%d"%[b,index])
 result["stress_action_stack"]=["hourglass","command_4","command_10","command_3"]
 result["stress_lifesteal"]=["blood_3","leech","pilgrim_4","spring"]
 result["stress_burst"]=["arcane_2","dusk_1","hunt_4","hunt_7"]
 result["stress_shield"]=["ward_1","ward_3","wardstone","bulwark"]
 result["stress_healer"]=["pilgrim_1","pilgrim_2","pilgrim_6","ward_1"]
 result["stress_mark"]=["hunt_3","command_1","focusstone","rune"]
 return result
func party(captain: String,profile: String) -> Array:
 var units=[Characters.create(captain)]
 for id in PROFILES[profile]:units.append(Characters.create(id))
 var gear=[]
 for unit in units:
  unit.xp=XP_BUDGET
  var skills=Jobs.JOBS[unit.profession].skills
  for i in skills.size():
   var id=skills[i]
   var desired=2 if i<3 else 1
   while Jobs.skill_rank(unit,id)<desired:
    assert(Jobs.training_reason(unit,id)=="","funded skill prerequisites")
    unit.xp-=Jobs.skill_cost(unit,id);unit.skill_ranks[id]=Jobs.skill_rank(unit,id)+1
  # Same budget for every actor; captains legally spend remaining XP on the same two roots.
  if unit.id=="hero":
   for id in ["mark","trap"]:
    assert(Jobs.training_reason(unit,id)=="","captain cross-job root must be legal")
    unit.xp-=Jobs.skill_cost(unit,id);unit.skill_ranks[id]=1
  var weapon={"hero":"sword","blade":"dagger","ranger":"bow","medic":"staff","engineer":"crossbow","warden":"sword"}[unit.profession]
  gear.append({"id":weapon,"owner":unit.id})
  gear.append({"id":"leather","owner":unit.id})
  if unit.profession=="hero":gear.append({"id":"shield","owner":unit.id})
 for unit in units:unit.merge(Jobs.stats(unit,gear),true)
 return units
func bound_entries(ids: Array,units: Array) -> Array:
 var result=[]
 var owners=[]
 for id in ids:
  var d=Relic.definition(id);var owner=""
  if d.scope=="personal":
   var job=OWNER_JOB.get(d.get("family",""),"hero")
   if id in ["wardstone","prism","spark","well"]:job="medic"
   if id=="focusstone":job="ranger"
   if id=="cog":job="engineer"
   if id in ["leech","fang","harvest","chalice"]:job="blade"
   var candidates=units.filter(func(u):return u.profession==job and u.id not in owners)
   if candidates.is_empty():candidates=units.filter(func(u):return u.id not in owners)
   assert(not candidates.is_empty(),"one relic per actor")
   owner=candidates[0].id;owners.append(owner)
  result.append(Relic.instance(id,result.size()+1,owner))
 return result
func step(b) -> bool:
 var a=b.active()
 if a.side==1:b.enemy_step();return true
 var enemies=b.actors.filter(func(u):return u.side==1 and u.hp>0)
 if enemies.is_empty():b.check_outcome();return true
 enemies.sort_custom(func(x,y):
  var dx=b.hex_distance(a.cell,x.cell);var dy=b.hex_distance(a.cell,y.cell)
  return x.hp<y.hp if dx==dy else dx<dy)
 var warnings=b.boss_warnings()
 if a.cell in warnings:
  var safe=[]
  for cell in b.cells():
   if cell in warnings:continue
   var path=b.path_to(a.cell,cell)
   if not path.is_empty() and b.movement_cost(a,path)<=a.ap:safe.append({"cell":cell,"cost":b.movement_cost(a,path)})
  safe.sort_custom(func(x,y):return x.cost<y.cost if x.cost!=y.cost else (x.cell.x<y.cell.x if x.cell.x!=y.cell.x else x.cell.y<y.cell.y))
  if not safe.is_empty():return b.move_to(safe[0].cell)
 var allies=b.actors.filter(func(u):return u.side==0 and u.hp>0)
 allies.sort_custom(func(x,y):return float(x.hp)/x.max_hp<float(y.hp)/y.max_hp if x.hp*y.max_hp!=y.hp*x.max_hp else x.id<y.id)
 # Interrupt displayed overload before spending actions on damage/support.
 for enemy in enemies:
  if not b.boss_intents.any(func(intent):return intent.source==enemy.id and intent.kind=="overload"):continue
  for skill in ["bash","warden_rebuke","ranger_pin"]:
   if b.can_cast(skill,enemy.id):return b.cast(enemy.id,skill)
 if support_ai:
  var support=b.auto_support_action()
  if not support.is_empty():return b.move_to(support.target) if support.action=="move" else b.cast(support.target,support.skill)
 for ally in allies:
  if ally.statuses.has("poison") or ally.statuses.has("chill"):
   for skill in ["cleanse","warden_ward"]:
    if b.can_cast(skill,ally.id):return b.cast(ally.id,skill)
  if ally.max_hp-ally.hp>=20:
   var heals=["heal","medic_mend","medic_barrier","hero_heal","engineer_pulse","warden_rescue"]
   for skill in heals:
    if b.can_cast(skill,ally.id):return b.cast(ally.id,skill)
 # Wards and guard are support actions with real cost, not synthetic start buffs.
 if a.profession=="warden":
  for ally in allies:
   if ally.id!=a.id and ally.hp*4<=ally.max_hp*3 and not ally.statuses.has("guard") and enemies.any(func(e):return b.hex_distance(e.cell,ally.cell)<=3):
    if b.can_cast("guard",ally.id):return b.cast(ally.id,"guard")
 if a.profession in ["medic","hero"]:
  for ally in allies:
   if ally.id==a.id or ally.mp+8>ally.max_mp:continue
   for skill in ["medic_channel","hero_rally"]:
    if b.can_cast(skill,ally.id):return b.cast(ally.id,skill)
 # Every role can use learned marks; there is no character-specific scripted advantage.
 if a.ap>=3 and not a.get("used_skills",[]).any(func(id):return Jobs.ALL_SKILLS[id].effect=="mark"):
  for target in enemies:
   if not target.get("statuses",{}).has("mark") and target.hp>=30:
    for skill in ["mark","ranger_expose"]:
     if b.can_cast(skill,target.id):
      if support_ai:
       var preview=b.auto_snapshot();preview.cast(target.id,skill)
       if not preview.can_act() or preview.active().id!=a.id or preview.auto_best_hit().is_empty():continue
      return b.cast(target.id,skill)
 if a.profession=="engineer" and not b.traps.any(func(t):return t.source==a.id) and a.ap>=2:
  for target in enemies:
   if b.hex_distance(target.cell,a.cell)>3:continue
   for dir in Rules.DIRS:
    var cell=target.cell+dir
    if b.hex_distance(cell,a.cell)<b.hex_distance(target.cell,a.cell) and b.can_cast("trap",cell):return b.cast(cell,"trap")
 var hit=b.auto_best_hit()
 if not hit.is_empty():return b.attack(hit.target) if hit.action=="attack" else b.cast(hit.target,hit.skill)
 # Protect wounded allies when no immediate offensive action is available.
 if a.profession in ["medic","warden","hero"]:
  for ally in allies:
   if ally.hp*4>ally.max_hp*3 or ally.statuses.has("shield"):continue
   if not enemies.any(func(e):return b.hex_distance(e.cell,ally.cell)<=3):continue
   for skill in ["cleanse","warden_ward"]:
    if b.can_cast(skill,ally.id):return b.cast(ally.id,skill)
 var candidates=b.cells().filter(func(cell):return b.is_free(cell) and cell not in warnings)
 candidates.sort_custom(func(x,y):
  var dx=b.hex_distance(x,enemies[0].cell);var dy=b.hex_distance(y,enemies[0].cell)
  return dx<dy if dx!=dy else (x.x<y.x if x.x!=y.x else x.y<y.y))
 for cell in candidates:
  if support_ai and not b.auto_support_move_safe(a,cell):continue
  if b.hex_distance(cell,enemies[0].cell)>=b.hex_distance(a.cell,enemies[0].cell):continue
  var path=b.path_to(a.cell,cell)
  if not path.is_empty() and b.movement_cost(a,path)<=maxi(1,a.ap-2):return b.move_to(cell)
 return b.rest("hp" if a.hp*2<a.max_hp else "mp")
func battle(captain: String,profile: String,combo: String,ids: Array,region: String,seed_value: int,depleted: bool) -> Dictionary:
 var units=party(captain,profile)
 if depleted:
  for unit in units:unit.hp=int(unit.max_hp*0.7);unit.mp=int(unit.max_mp*0.5)
 var entries=bound_entries(ids,units)
 var initial_hp=0;var initial_mp=0
 for unit in units:initial_hp+=unit.hp;initial_mp+=unit.mp
 var b=Rules.new();b.start_battle(units,2,entries,{"biome":region,"seed":seed_value,"threat":"boss"})
 var steps=0
 while b.outcome=="" and steps<450:
  if not step(b):invalid_actions+=1;break
  steps+=1
 var hp=0;var mp=0;var dead=[];var talents={}
 for unit in b.actors:
  if unit.side==0:
   hp+=unit.hp;mp+=unit.mp
   if unit.hp<=0:dead.append(unit.character_id)
 for event in b.events:
  if event.begins_with("天赋 · "):
   var parts=event.split(" · ")
   if parts.size()>2:talents[parts[1]]=int(talents.get(parts[1],0))+1
 return {"captain":captain,"profile":profile,"combo":combo,"region":region,"seed":seed_value,"depleted":depleted,"outcome":b.outcome,"rounds":b.round_no,"steps":steps,"hp":hp,"mp":mp,"initial_hp":initial_hp,"initial_mp":initial_mp,"dead":dead,"talents":talents,"bindings":entries.map(func(entry):return {"id":entry.id,"owner":entry.owner})}
