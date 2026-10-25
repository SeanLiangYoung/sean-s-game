extends SceneTree
const Simulation=preload("res://tools/relic_mix_simulation.gd")
func _initialize():call_deferred("run")
func run():
 var label="baseline";var mode="all";var captain_filter=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--label="):label=arg.trim_prefix("--label=")
  if arg.begins_with("--mode="):mode=arg.trim_prefix("--mode=")
  if arg.begins_with("--captain="):captain_filter=arg.trim_prefix("--captain=")
 var hashes={}
 for file in DirAccess.get_files_at("res://game"):
  if file.ends_with(".gd"):hashes[file]=FileAccess.get_sha256("res://game/"+file)
 var tools_hashes={"driver":FileAccess.get_sha256("res://tools/simulate_relic_mixes.gd"),"policy":FileAccess.get_sha256("res://tools/relic_mix_simulation.gd")}
 var sim=Simulation.new();var loadouts=sim.loadouts();var results=[]
 if mode=="delta":
  var replay=["none","pure_team_blood","pure_personal_blood","pure_team_command","pure_personal_command","mix_hunt_arcane","mix_ward_pilgrim","stress_lifesteal"]
  for id in loadouts.keys():
   if id not in replay:loadouts.erase(id)
 for captain in Simulation.Characters.CAPTAINS:
  if captain_filter!="" and captain!=captain_filter:continue
  for profile in Simulation.PROFILES:
   var heldout=profile in ["no_medic","double_medic"]
   if mode=="pilot" and (captain!="shen" or heldout):continue
   if mode=="probe" and (captain!="shen" or profile!="balanced"):continue
   if mode=="heldout" and not heldout:continue
   if mode=="core" and heldout:continue
   for combo in loadouts:
    for region in Simulation.REGIONS:
     var states=[false] if heldout else [false,true]
     for depleted in states:results.append(sim.battle(captain,profile,combo,loadouts[combo],region,73 if heldout else 21,depleted))
   var group=results.filter(func(row):return row.profile==profile)
   print("MIX ",label," ",captain,"/",profile," battles=",group.size()," wins=",group.filter(func(row):return row.outcome=="victory").size())
   var partial=FileAccess.open("res://artifacts/relic-mixes-"+label+"-"+captain+"-partial.json",FileAccess.WRITE)
   partial.store_string(JSON.stringify({"results":results}));partial.close()
   await process_frame
 var changed=[]
 for file in hashes:
  if FileAccess.get_sha256("res://game/"+file)!=hashes[file]:changed.append(file)
 for source in ["driver","policy"]:
  var path="res://tools/simulate_relic_mixes.gd" if source=="driver" else "res://tools/relic_mix_simulation.gd"
  if FileAccess.get_sha256(path)!=tools_hashes[source]:changed.append(path)
 var incomplete=results.filter(func(row):return row.outcome=="").size()
 var report={"incomplete_battles":incomplete,"label":label,"mode":mode,"captain_filter":captain_filter,"simulation_hashes":tools_hashes,"source_hashes":hashes,"changed_sources":changed,"invalid_actions":sim.invalid_actions,"loadouts":loadouts,"party_profiles":Simulation.PROFILES,"policy":"three real captains, all 15 companion identities/talents, identical 11-item/330-silver low-tier team budget (captain shield only); legal 360XP per actor with prerequisites, first three profession skills rank2 and advanced rank1; same two paid captain cross-job root skills; role-neutral support/one-mark-per-turn/guard/trap/damage policy; tier2 six-region bosses; core seed21 independently full and 70%HP50%MP, heldout no-medic/double-medic seed73 full resources", "results":results}
 var output="res://artifacts/relic-mixes-"+label+("-"+captain_filter if captain_filter!="" else "")+".json"
 var file=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report));file.close()
 print("MIXES_DONE ",label," battles=",results.size()," invalid=",sim.invalid_actions," changed=",changed)
 quit(0 if sim.invalid_actions==0 and changed.is_empty() and incomplete==0 else 1)
