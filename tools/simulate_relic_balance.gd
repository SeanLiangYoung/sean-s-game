extends SceneTree
# Paired battle experiments: same actors, map seeds, difficulty and policy for every loadout.
const Rules=preload("res://game/rules.gd")
const Jobs=preload("res://game/professions.gd")
const Relic=preload("res://game/relics.gd")
const Campaign=preload("res://game/campaign.gd")
const REGIONS=["border","wood","waste","frost","marsh","ruins"]
const OWNERS={"blood":"blade","hunt":"ranger","ward":"hero","arcane":"hero","engine":"engineer","pilgrim":"medic","dusk":"ranger","command":"blade"}
const BUILDS={
 "blood":[["blood_1","blood_3","blood_5","blood_7"],["blood_2","blood_4","blood_5","blood_10"]],
 "hunt":[["hunt_1","hunt_3","hunt_4","hunt_7"],["hunt_2","hunt_3","hunt_5","hunt_10"]],
 "ward":[["ward_1","ward_2","ward_3","ward_7"],["ward_1","ward_4","ward_5","ward_6"]],
 "arcane":[["arcane_1","arcane_2","arcane_4","arcane_6"],["arcane_1","arcane_3","arcane_5","arcane_8"]],
 "engine":[["engine_1","engine_2","engine_4","engine_6"],["engine_2","engine_3","engine_5","engine_7"]],
 "pilgrim":[["pilgrim_1","pilgrim_2","pilgrim_4","pilgrim_6"],["pilgrim_1","pilgrim_3","pilgrim_5","pilgrim_7"]],
 "dusk":[["dusk_1","dusk_2","dusk_4","dusk_6"],["dusk_2","dusk_3","dusk_5","dusk_8"]],
 "command":[["command_1","command_2","command_4","command_7"],["command_1","command_3","command_5","command_9"]]}
class MemoryCampaign:
 extends Campaign
 func save_game() -> bool:return true
var invalid_actions=0
func _initialize():call_deferred("run")
func party() -> Array:
 var units=Rules.new().default_party().slice(0,5)
 var gear=[]
 for pair in [["sword","hero"],["dagger","blade"],["bow","ranger"],["staff","medic"],["crossbow","engineer"],["shield","hero"],["leather","blade"]]:gear.append({"id":pair[0],"owner":pair[1]})
 for unit in units:
  # Equal training budget across all loadouts; no build gets free ranks.
  for id in Jobs.JOBS[unit.profession].skills:unit.skill_ranks[id]=1
  unit.merge(Jobs.stats(unit,gear),true)
 return units
func entries(ids: Array) -> Array:
 var result=[]
 for id in ids:
  var d=Relic.definition(id)
  var family=d.get("family","")
  var owner=""
  if d.scope=="personal":
   owner=OWNERS.get(family,"hero")
   if id in ["prism","spark","wardstone","well"]:owner="medic"
   if id=="cog":owner="engineer"
   if id=="focusstone":owner="ranger"
   if id in ["fang","leech","harvest","chalice","thorn"]:owner="blade"
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
 if a.cell in b.boss_warnings():
  var safe=[]
  for cell in b.cells():
   if cell in b.boss_warnings():continue
   var path=b.path_to(a.cell,cell)
   if not path.is_empty() and b.movement_cost(a,path)<=a.ap:safe.append({"cell":cell,"cost":b.movement_cost(a,path)})
  safe.sort_custom(func(x,y):return x.cost<y.cost if x.cost!=y.cost else (x.cell.x<y.cell.x if x.cell.x!=y.cell.x else x.cell.y<y.cell.y))
  if not safe.is_empty():return b.move_to(safe[0].cell)
 # Support skills are real actions and pay their actual AP/MP.
 if Jobs.job_id(a)=="medic":
  var allies=b.actors.filter(func(u):return u.side==0 and u.hp>0)
  allies.sort_custom(func(x,y):return float(x.hp)/x.max_hp<float(y.hp)/y.max_hp)
  for ally in allies:
   if (ally.statuses.has("poison") or ally.statuses.has("chill")) and b.can_cast("cleanse",ally.id):return b.cast(ally.id,"cleanse")
   if ally.max_hp-ally.hp>=20:
    for skill in ["heal","medic_mend","medic_barrier"]:
     if b.can_cast(skill,ally.id):return b.cast(ally.id,skill)
  for ally in allies:
   if ally.mp<8 and ally.id!=a.id and b.can_cast("medic_channel",ally.id):return b.cast(ally.id,"medic_channel")
  if enemies.any(func(e):return b.hex_distance(e.cell,allies[0].cell)<=3) and not allies[0].statuses.has("shield") and b.can_cast("cleanse",allies[0].id):return b.cast(allies[0].id,"cleanse")
 if Jobs.job_id(a)=="ranger" and a.ap>=3:
  for target in enemies:
   if not target.statuses.has("mark") and target.hp>=30 and b.can_cast("mark",target.id):return b.cast(target.id,"mark")
 if Jobs.job_id(a)=="engineer" and not b.traps.any(func(t):return t.source==a.id) and a.ap>=2:
  for target in enemies:
   for dir in Rules.DIRS:
    var cell=target.cell+dir
    if b.hex_distance(cell,a.cell)<b.hex_distance(target.cell,a.cell) and b.can_cast("trap",cell):return b.cast(cell,"trap")
 var hit=b.auto_best_hit()
 if not hit.is_empty():return b.attack(hit.target) if hit.action=="attack" else b.cast(hit.target,hit.skill)
 var candidates=b.cells().filter(func(cell):return b.is_free(cell) and cell not in b.boss_warnings())
 candidates.sort_custom(func(x,y):
  var dx=b.hex_distance(x,enemies[0].cell);var dy=b.hex_distance(y,enemies[0].cell)
  return dx<dy if dx!=dy else (x.x<y.x if x.x!=y.x else x.y<y.y))
 for cell in candidates:
  if b.hex_distance(cell,enemies[0].cell)>=b.hex_distance(a.cell,enemies[0].cell):continue
  var path=b.path_to(a.cell,cell)
  if not path.is_empty() and b.movement_cost(a,path)<=maxi(1,a.ap-2):return b.move_to(cell)
 return b.rest("hp" if a.hp*2<a.max_hp else "mp")
func battle(ids: Array,region: String,seed_value: int,threat: String="boss",tier: int=2,units: Array=[]) -> Dictionary:
 var prepared=party() if units.is_empty() else units.duplicate(true)
 var hp_ratio={21:1.0,42:0.75,73:0.55}.get(seed_value,1.0)
 var mp_ratio={21:1.0,42:0.5,73:0.3}.get(seed_value,1.0)
 for unit in prepared:
  unit.hp=maxi(1,int(unit.max_hp*hp_ratio));unit.mp=int(unit.max_mp*mp_ratio)
 var b=Rules.new();b.start_battle(prepared,tier,entries(ids),{"biome":region,"seed":seed_value,"threat":threat})
 var steps=0
 while b.outcome=="" and steps<450:
  if not step(b):invalid_actions+=1;break
  steps+=1
 var hp=0;var mp=0;var dead=0
 for a in b.actors:
  if a.side==0:
   hp+=a.hp;mp+=a.mp
   if a.hp<=0:dead+=1
 return {"region":region,"seed":seed_value,"initial_hp_ratio":hp_ratio,"initial_mp_ratio":mp_ratio,"outcome":b.outcome,"rounds":b.round_no,"hp":hp,"mp":mp,"dead":dead,"steps":steps,"relics":ids}
func run():
 var label="baseline"
 var mode="all"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--label="):label=arg.trim_prefix("--label=")
  if arg.begins_with("--mode="):mode=arg.trim_prefix("--mode=")
 if mode=="expeditions":
  await expeditions(label)
  return
 var hashes={}
 for source in DirAccess.get_files_at("res://game"):
  if source.ends_with(".gd"):hashes[source]=FileAccess.get_sha256("res://game/"+source)
 var report={"label":label,"policy":"equal low-tier gear, rank1 all profession skills; support/mark/trap then exact damage preview; deterministic movement; paired full/75%HP50%MP/55%HP30%MP resource scenarios", "source_hashes":hashes,"controls":[],"builds":{},"singles":{}}
 for region in REGIONS:
  for seed_value in [21,42,73]:report.controls.append(battle([],region,seed_value))
 if mode!="singles":
  for family in BUILDS:
   report.builds[family]=[]
   for variant in BUILDS[family]:
    for region in REGIONS:
     for seed_value in [21,42,73]:report.builds[family].append(battle(variant,region,seed_value))
   print("BUILD ",label," ",family," done")
   await process_frame
 if mode!="builds":
  for id in Relic.CATALOG:
   report.singles[id]=[]
   for region in REGIONS:report.singles[id].append(battle([id],region,42))
   print("SINGLE ",label," ",id," done")
   await process_frame
 report.invalid_actions=invalid_actions
 var changed=[]
 for source in hashes:
  if FileAccess.get_sha256("res://game/"+source)!=hashes[source]:changed.append(source)
 report.changed_sources=changed
 var file=FileAccess.open("res://artifacts/relic-balance-"+label+".json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "));file.close()
 print("BALANCE_DONE ",label," invalid_actions=",invalid_actions," changed_sources=",changed)
 quit(0 if invalid_actions==0 and changed.is_empty() else 1)

func max_resonance(c) -> Dictionary:
 var best={"family":"","count":0}
 for unit in c.roster:
  if unit.hp<=0:continue
  var applicable=(c.relics+c.collection).filter(func(entry):return Relic.definition(entry).scope=="team" or entry.owner==unit.id)
  var counts=Relic.resonance_counts(applicable)
  for family in counts:
   if counts[family]>best.count:best={"family":family,"count":counts[family]}
 return best
func preferred_owner(c,id: String) -> String:
 if Relic.definition(id).scope=="team":return ""
 var desired=OWNERS.get(Relic.definition(id).get("family",""),"hero")
 if c.roster.any(func(u):return u.id==desired and u.hp>0):return desired
 var alive=c.roster.filter(func(u):return u.hp>0)
 return alive[0].id if not alive.is_empty() else ""
func reward_score(c,id: String,target_family: String) -> float:
 var d=Relic.definition(id)
 var family=d.get("family","")
 var counts=Relic.resonance_counts(c.relics+c.collection)
 var score=float(counts.get(family,0))*10+(4 if family==target_family else 0)+(2 if d.scope=="team" else 0)
 if d.scope=="personal":
  var old=c.personal_relic(preferred_owner(c,id))
  if not old.is_empty() and Relic.definition(old).get("family","")==family:score-=15
 return score
func expeditions(label: String):
 var results=[]
 var hashes={}
 for source in DirAccess.get_files_at("res://game"):
  if source.ends_with(".gd"):hashes[source]=FileAccess.get_sha256("res://game/"+source)
 for target_family in BUILDS:
  for region in REGIONS:
   for sample in range(2):
    var c=MemoryCampaign.new();c.rng.seed=2026102500+BUILDS.keys().find(target_family)*100+REGIONS.find(region)*10+sample
    # Same prepared party as paired trials, then persist real campaign attrition.
    var prepared=party()
    for unit in prepared:
     var base=c.roster.filter(func(u):return u.id==unit.id)[0]
     base.skill_ranks=unit.skill_ranks.duplicate(true)
    for pair in [[0,"hero"],[1,"blade"],[2,"ranger"],[3,"medic"],[4,"engineer"],[5,"hero"],[6,"blade"]]:c.equip_item(pair[0],pair[1])
    c.start_region(region)
    var result={"target":target_family,"region":region,"seed":2026102500+BUILDS.keys().find(target_family)*100+REGIONS.find(region)*10+sample,"cleared":false,"battles":[],"relics":[],"before_boss":{"family":"","count":0},"final":{"family":"","count":0},"failure":""}
    for depth in range(c.route.nodes[-1].depth+1):
     var available=c.route.available()
     if available.is_empty():break
     var selected=c.route.node(available[0])
     for id in available:
      var node=c.route.node(id)
      if node.kind=="battle":selected=node;break
      if node.kind=="supply":selected=node
     if not c.enter_route(selected.id):result.failure="route rejected";break
     if selected.kind=="shop":
      for id in c.shop_inventory():
       if not Relic.CATALOG.has(id):continue
       if Relic.definition(id).get("family","")!=target_family and reward_score(c,id,target_family)<10:continue
       c.buy(id,preferred_owner(c,id))
     if selected.kind=="battle":
      if selected.threat=="boss":result.before_boss=max_resonance(c)
      var ids=["hero","blade","ranger","medic","engineer"].filter(func(id):return c.roster.any(func(u):return u.id==id and u.hp>0))
      var b=c.make_battle(ids,selected.encounter)
      if b==null:result.failure="deployment rejected";break
      var steps=0
      while b.outcome=="" and steps<450:
       if not step(b):invalid_actions+=1;break
       steps+=1
      result.battles.append({"outcome":b.outcome,"rounds":b.round_no,"steps":steps,"depth":depth,"threat":selected.threat})
      c.resolve_battle(b)
      if b.outcome!="victory":result.failure=b.outcome if b.outcome!="" else "step limit";break
      var best=-1;var score=-999.0
      for i in c.choices.size():
       if c.choices[i].type!="relic":continue
       var value=reward_score(c,c.choices[i].id,target_family)
       if value>score:score=value;best=i
      if best<0 or not c.choose_reward(best,preferred_owner(c,c.choices[best].id)):result.failure="reward rejected";break
     result.relics=c.relics.map(func(entry):return entry.id)
     result.final=max_resonance(c)
     if c.phase=="world":
      while c.supplies>0 and c.roster.any(func(u):return u.hp>0 and (u.hp<u.max_hp*0.7 or u.mp<u.max_mp*0.5)):c.use_supply()
     if selected.kind=="extract":result.cleared=c.extract([])
    results.append(result)
  print("EXPEDITION ",label," ",target_family," done")
  await process_frame
 var changed=[]
 for source in hashes:
  if FileAccess.get_sha256("res://game/"+source)!=hashes[source]:changed.append(source)
 var report={"label":label,"policy":"96 prepared low-tier rank1 skill parties; actual generated six-region routes; fixed battle policy; relic rewards with preferred theme and continuity, buy matching relics when affordable; supplies at 70%HP/50%MP; no free relic grants", "source_hashes":hashes,"invalid_actions":invalid_actions,"changed_sources":changed,"results":results}
 var file=FileAccess.open("res://artifacts/relic-expeditions-"+label+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("EXPEDITIONS_DONE ",label," invalid=",invalid_actions," changed=",changed)
 quit(0 if invalid_actions==0 and changed.is_empty() else 1)
