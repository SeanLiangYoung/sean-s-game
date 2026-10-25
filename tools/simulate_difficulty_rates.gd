extends "res://tools/simulate_auto_runs.gd"
# Same fixed starter policy as the historical 50% border calibration, at all four difficulties.
class StudyCampaign:
 extends "res://game/campaign.gd"
 func save_game() -> bool:return true
 func sync_achievements():pass
func run():
 var level=0
 var count=1000
 var seed_start=2026102500
 var label="main"
 var disk_saves=false
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--difficulty="):level=int(arg.trim_prefix("--difficulty="))
  if arg.begins_with("--count="):count=int(arg.trim_prefix("--count="))
  if arg.begins_with("--seed-start="):seed_start=int(arg.trim_prefix("--seed-start="))
  if arg.begins_with("--label="):label=arg.trim_prefix("--label=")
  if arg=="--disk-saves":disk_saves=true
 if level not in [0,1,2,3] or count<1 or count>100000 or not label.is_valid_identifier():
  push_error("invalid study parameters");quit(1);return
 var hashes={}
 for source in DirAccess.get_files_at("res://game"):
  if source.ends_with(".gd"):hashes[source]=FileAccess.get_sha256("res://game/"+source)
 var policy_hashes={}
 for source in ["simulate_auto_runs.gd","simulate_difficulty_rates.gd"]:policy_hashes[source]=FileAccess.get_sha256("res://tools/"+source)
 var temporary_save="user://difficulty-study-%d-%d.json"%[level,Time.get_ticks_usec()]
 var results=[]
 var started=Time.get_ticks_msec()
 for index in range(count):
  var c=Campaign.new(temporary_save) if disk_saves else StudyCampaign.new(temporary_save)
  c.rng.seed=seed_start+index
  c.overall_difficulty=level
  var row={"seed":seed_start+index,"difficulty":level,"cleared":false,"failure":"","battles":[]}
  if not c.completed_difficulties.is_empty():row.failure="unexpected achievement bonuses"
  for pair in [[0,"hero"],[1,"blade"],[2,"ranger"],[3,"medic"],[4,"engineer"],[5,"hero"],[6,"blade"]]:
   if not c.equip_item(pair[0],pair[1]):row.failure="equipment rejected"
  if not c.start_region("border"):row.failure="region rejected"
  row["route_seed"]=c.route.seed_value
  for depth in range(c.route.nodes[-1].depth+1):
   if row.failure!="":break
   var available=c.route.available()
   if available.is_empty():row.failure="unfinished route";break
   var selected=c.route.node(available[0])
   for id in available:
    var node=c.route.node(id)
    if node.kind=="battle":selected=node;break
    if node.kind=="supply":selected=node
   if not c.enter_route(selected.id):row.failure="route rejected";break
   if selected.kind=="battle":
    var ids=PARTY.filter(func(id):return c.roster.any(func(unit):return unit.id==id and unit.hp>0))
    var b=c.make_battle(ids,selected.encounter)
    if b==null:row.failure="deployment rejected";break
    var outcome=play(b)
    outcome["survivors"]=b.actors.filter(func(actor):return actor.side==0 and actor.hp>0).size()
    outcome["party_hp"]=0
    for actor in b.actors:
     if actor.side==0:outcome.party_hp+=maxi(0,actor.hp)
    outcome["supplies_remaining"]=c.supplies
    outcome["depth"]=depth
    outcome["threat"]=selected.threat
    row.battles.append(outcome)
    if outcome.error!="":row.failure=outcome.error;break
    if not c.resolve_battle(b):row.failure="settlement rejected";break
    if b.outcome!="victory":row.failure=b.outcome;break
    var reward=-1
    for i in c.choices.size():
     if c.choices[i].type=="resource":reward=i;break
    if reward<0 or not c.choose_reward(reward):row.failure="reward rejected";break
   if c.phase=="world":
    while c.supplies>0 and c.roster.any(func(unit):return unit.hp>0 and (unit.hp<unit.max_hp*0.7 or unit.mp<unit.max_mp*0.5)):c.use_supply()
   if selected.kind=="extract":
    row.cleared="border" in c.cleared_regions and c.extract([])
    if not row.cleared:row.failure="extraction rejected"
  if not row.cleared and row.failure=="":row.failure="unfinished expedition"
  results.append(row)
  if (index+1)%10==0 or index+1==count:
   print("PROGRESS level=%d completed=%d/%d clears=%d elapsed_ms=%d"%[level,index+1,count,results.filter(func(r):return r.cleared).size(),Time.get_ticks_msec()-started])
   await process_frame
 var changed=[]
 for source in hashes:
  if hashes[source]!=FileAccess.get_sha256("res://game/"+source):changed.append(source)
 for source in policy_hashes:
  if policy_hashes[source]!=FileAccess.get_sha256("res://tools/"+source):changed.append("tools/"+source)
 var report={"label":label,"difficulty":level,"difficulty_name":Campaign.OVERALL_DIFFICULTIES[level],"target_rate":[0.50,0.25,0.10,0.01][level],"source_hashes":hashes,"policy_hashes":policy_hashes,"changed_sources":changed,"policy":"historical border calibration: fresh default Shen starter party; seven fixed starting gear assignments; prefer battles then supplies; resource rewards only; heal below 70% HP or 50% MP; real Rules.auto_action; no training/shopping/relics/retries or achievement bonuses; defeat boss AND extract to clear","region":"border","seed_start":seed_start,"runs":count,"disk_saves":disk_saves,"elapsed_ms":Time.get_ticks_msec()-started,"clears":results.filter(func(row):return row.cleared).size(),"results":results}
 var out="res://artifacts/difficulty-rates-%s-%d.json"%[label,level]
 var file=FileAccess.open(out,FileAccess.WRITE)
 if file==null:push_error("could not write study report");quit(1);return
 file.store_string(JSON.stringify(report));file.close()
 for path in [temporary_save,temporary_save+".tmp",temporary_save+".achievements"]:DirAccess.remove_absolute(path)
 var errors=results.filter(func(row):return row.failure not in ["","gameover","defeat"])
 print("STUDY_DONE difficulty=%d clears=%d/%d errors=%d changed=%s elapsed_ms=%d"%[level,report.clears,count,errors.size(),changed,report.elapsed_ms])
 quit(0 if errors.is_empty() and changed.is_empty() else 1)
