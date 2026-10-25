extends SceneTree
const Simulation=preload("res://tools/longline_simulation.gd")
func _initialize():call_deferred("run")
func hashes() -> Dictionary:
 var result={}
 for dir in ["game","tools"]:
  for name in DirAccess.get_files_at("res://"+dir):
   if not name.ends_with(".gd"):continue
   if dir=="tools" and name not in ["fresh_run_simulation.gd","relic_mix_simulation.gd","longline_simulation.gd","simulate_longline.gd"]:continue
   result[dir+"/"+name]=FileAccess.get_sha256("res://"+dir+"/"+name)
 return result
func run():
 var label="diagnostic";var file="";var captain=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--label="):label=arg.trim_prefix("--label=")
  if arg.begins_with("--cases="):file=arg.trim_prefix("--cases=")
  if arg.begins_with("--captain="):captain=arg.trim_prefix("--captain=")
 var cases=JSON.parse_string(FileAccess.get_file_as_string(file));assert(cases is Array)
 var before=hashes();var results=[];var sim=Simulation.new()
 for case in cases:
  if captain!="" and case.captain!=captain:continue
  sim.support_ai=case.get("support_ai",false)
  sim.careful_supply=case.get("careful_supply",false)
  sim.sustain_training=case.get("sustain_training",false)
  var r=sim.run(case.captain,case.profile,case.strategy,"border",int(case.seed),case.get("denied",[]),true)
  results.append(r)
  print("LONGLINE ",label," ",r.captain,"/",r.profile,"/",r.strategy," seed=",r.seed," clear=",r.cleared," fights=",r.battles.size())
  await process_frame
 var after=hashes();var errors=results.filter(func(r):return not r.errors.is_empty() or r.failure not in ["","defeat","gameover"])
 var report={"label":label,"cases_sha256":FileAccess.get_sha256(file),"source_hashes":before,"changed_sources":before!=after,"results":results}
 var out=FileAccess.open("res://artifacts/longline-"+label+("-"+captain if captain!="" else "")+".json",FileAccess.WRITE)
 out.store_string(JSON.stringify(report));out.close()
 print("LONGLINE_DONE ",label," cases=",results.size()," clears=",results.filter(func(r):return r.cleared).size()," errors=",errors.size()," changed=",before!=after)
 quit(0 if errors.is_empty() and before==after else 1)
