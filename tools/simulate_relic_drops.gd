extends SceneTree
const Campaign=preload("res://game/campaign.gd")
const Relic=preload("res://game/relics.gd")
const Rules=preload("res://game/rules.gd")
# Real Campaign reward/acquisition code without writing synthetic saves to disk.
class MemoryCampaign:
 extends Campaign
 func save_game() -> bool:return true
func _initialize():call_deferred("run")
func best_count(c) -> Dictionary:
 var best={"count":0,"family":""}
 for unit in c.roster:
  var applicable=(c.relics+c.collection).filter(func(entry):return Relic.definition(entry).scope=="team" or entry.owner==unit.id)
  var counts=Relic.resonance_counts(applicable)
  for family in counts:
   if counts[family]>best.count:best={"count":counts[family],"family":family}
 return best
func pick(c) -> Dictionary:
 var best={"index":-1,"score":-999.0,"owner":""}
 for i in c.choices.size():
  var reward=c.choices[i]
  if reward.type!="relic":continue
  var d=Relic.definition(reward.id)
  var family=d.get("family","")
  var counts=Relic.resonance_counts(c.relics+c.collection)
  var score=float(counts.get(family,0))*10.0+(2 if d.scope=="team" else 0)
  var owner=""
  if d.scope=="personal":
   var candidates=c.roster.filter(func(u):return u.hp>0 and c.personal_relic(u.id).is_empty())
   if candidates.is_empty():score-=15;owner=c.roster[0].id
   else:owner=candidates[0].id
  if score>best.score:best={"index":i,"score":score,"owner":owner}
 return best
func run():
 var label="baseline"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--label="):label=arg.trim_prefix("--label=")
 var hashes={}
 for source in DirAccess.get_files_at("res://game"):
  if source.ends_with(".gd"):hashes[source]=FileAccess.get_sha256("res://game/"+source)
 var results=[]
 for seed_index in range(500):
  var c=MemoryCampaign.new();c.rng.seed=2026102500+seed_index
  var b=Rules.new();b.start_battle(c.roster.slice(0,5),0)
  for unit in b.actors:
   if unit.side==1:unit.hp=0
  b.check_outcome()
  var result={"seed":2026102500+seed_index,"stages":[],"relics":[]}
  for stage in range(6):
   c.phase="battle";c.current_encounter=0
   c.resolve_battle(b)
   var chosen=pick(c)
   if chosen.index<0 or not c.choose_reward(chosen.index,chosen.owner):push_error("drop settlement failed");quit(1);return
   var count=best_count(c)
   result.stages.append(count)
   # Real battle adapter retains acquired relics when Campaign syncs the next reward.
   b.relic_state=c.relics.duplicate(true)
  result.relics=c.relics.map(func(entry):return entry.id)
  results.append(result)
  if seed_index%50==0:await process_frame
 var changed=[]
 for source in hashes:
  if FileAccess.get_sha256("res://game/"+source)!=hashes[source]:changed.append(source)
 var report={"source_hashes":hashes,"changed_sources":changed,"label":label,"runs":500,"policy":"six consecutive real reward settlements; choose highest theme continuity, prefer team, bind personal relics to empty slots; no purchases", "results":results}
 var file=FileAccess.open("res://artifacts/relic-drops-"+label+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("DROPS_DONE ",label," runs=",results.size()," changed=",changed);quit(0 if changed.is_empty() else 1)
