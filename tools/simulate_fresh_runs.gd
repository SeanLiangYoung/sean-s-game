extends SceneTree
const Simulation=preload("res://tools/fresh_run_simulation.gd")
func _initialize():call_deferred("run")
func run():
 var label="baseline";var captain_filter="";var mode="main";var seed_start=2026102600;var count=2;var denied=[]
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--label="):label=arg.trim_prefix("--label=")
  if arg.begins_with("--captain="):captain_filter=arg.trim_prefix("--captain=")
  if arg.begins_with("--mode="):mode=arg.trim_prefix("--mode=")
  if arg.begins_with("--seed-start="):seed_start=int(arg.trim_prefix("--seed-start="))
  if arg.begins_with("--count="):count=int(arg.trim_prefix("--count="))
  if arg.begins_with("--deny="):denied=Array(arg.trim_prefix("--deny=").split(",",false))
 var hashes={}
 for file in DirAccess.get_files_at("res://game"):
  if file.ends_with(".gd"):hashes[file]=FileAccess.get_sha256("res://game/"+file)
 var policy_hashes={}
 for file in ["simulate_fresh_runs.gd","fresh_run_simulation.gd","relic_mix_simulation.gd"]:policy_hashes[file]=FileAccess.get_sha256("res://tools/"+file)
 var sim=Simulation.new();var results=[]
 for captain in Simulation.Campaign.Characters.CAPTAINS:
  if captain_filter!="" and captain!=captain_filter:continue
  for profile in Simulation.PROFILES:
   for strategy in ["adaptive","relic_focus"]:
    var regions=["border"] if mode in ["pilot","campaign","deny"] else Simulation.REGIONS
    for region in regions:
     for sample in count:
      var seed_value=seed_start+Simulation.PROFILES.keys().find(profile)*100+maxi(0,Simulation.REGIONS.find(region))*10+sample
      var result=sim.run(captain,profile,strategy,region,seed_value,denied,mode=="campaign")
      results.append(result)
      print("FRESH ",label," ",captain,"/",profile,"/",strategy,"/",region," seed=",seed_value," clear=",result.cleared," fights=",result.battles.size()," failure=",result.failure)
    await process_frame
 var changed=[]
 for file in hashes:
  if FileAccess.get_sha256("res://game/"+file)!=hashes[file]:changed.append(file)
 for file in policy_hashes:
  if FileAccess.get_sha256("res://tools/"+file)!=policy_hashes[file]:changed.append("tools/"+file)
 var report={"label":label,"mode":mode,"source_hashes":hashes,"policy_hashes":policy_hashes,"changed_sources":changed,"results":results,"denied":denied,"seed_start":seed_start,"count":count,"policy":"fresh Campaign starting six actors; captain via API, five selected from real roster; only eight starting gear pieces; XP0/basic skills only; no relics/collection/meta bonuses; actual reward/stock/training/supply/recruit APIs; adaptive vs relic-focus fixed visible-information choices; no retries or post-defeat reloads; paired strategies/captains in 40 independent profile/region seed blocks; current-party books, bounded AP valuation, real emergency medicine and value-based extraction"}
 var out="res://artifacts/fresh-runs-"+label+("-"+captain_filter if captain_filter!="" else "")+".json"
 var file=FileAccess.open(out,FileAccess.WRITE);file.store_string(JSON.stringify(report));file.close()
 var errors=results.filter(func(row):return not row.errors.is_empty() or row.failure not in ["","gameover","defeat"])
 print("FRESH_DONE ",label," samples=",results.size()," clears=",results.filter(func(row):return row.cleared).size()," errors=",errors.size()," changed=",changed)
 quit(0 if errors.is_empty() and changed.is_empty() else 1)
