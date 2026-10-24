extends SceneTree
const Simulation=preload("res://tools/relic_mix_simulation.gd")
const Campaign=preload("res://game/campaign.gd")
class MemoryCampaign:
 extends Campaign
 func save_game() -> bool:return true
func _initialize():call_deferred("run")
func run():
 var label="final"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--label="):label=arg.trim_prefix("--label=")
 var hashes={}
 for source in DirAccess.get_files_at("res://game"):
  if source.ends_with(".gd"):hashes[source]=FileAccess.get_sha256("res://game/"+source)
 var sim=Simulation.new();var loadouts=sim.loadouts();var results=[]
 for captain in Simulation.Characters.CAPTAINS:
  for profile in Simulation.PROFILES:
   for combo in ["mix_hunt_arcane","mix_blood_pilgrim"]:
    var c=MemoryCampaign.new();c.rng.seed=2026102500+Simulation.Characters.CAPTAINS.find(captain)*100+Simulation.PROFILES.keys().find(profile)*10
    c.roster=sim.party(captain,profile);c.equipment=[]
    for unit in c.roster:
     var weapon={"hero":"sword","blade":"dagger","ranger":"bow","medic":"staff","engineer":"crossbow","warden":"sword"}[unit.profession]
     c.equipment.append({"id":weapon,"owner":unit.id});c.equipment.append({"id":"leather","owner":unit.id})
     if unit.id=="hero":c.equipment.append({"id":"shield","owner":unit.id})
    c.refresh_stats()
    var region=Simulation.REGIONS[(Simulation.Characters.CAPTAINS.find(captain)*2+Simulation.PROFILES.keys().find(profile))%6]
    c.start_region(region)
    for entry in sim.bound_entries(loadouts[combo],c.roster):
     assert(c.acquire_relic(entry.id,entry.owner),"prepared mixed relics bind legally")
    var result={"captain":captain,"profile":profile,"combo":combo,"region":region,"route_seed":c.route.seed_value,"cleared":false,"battles":[],"failure":""}
    for depth in range(c.route.nodes[-1].depth+1):
     var available=c.route.available()
     if available.is_empty():break
     var selected=c.route.node(available[0])
     for id in available:
      var node=c.route.node(id)
      if node.kind=="battle":selected=node;break
      if node.kind=="supply":selected=node
     if not c.enter_route(selected.id):result.failure="route rejected";break
     if selected.kind=="battle":
      var ids=c.roster.filter(func(unit):return unit.hp>0).map(func(unit):return unit.id)
      var b=c.make_battle(ids,selected.encounter)
      if b==null:result.failure="deployment rejected";break
      var steps=0
      while b.outcome=="" and steps<450:
       if not sim.step(b):sim.invalid_actions+=1;break
       steps+=1
      result.battles.append({"outcome":b.outcome,"rounds":b.round_no,"depth":depth,"threat":selected.threat,"steps":steps})
      if b.outcome=="":result.failure="step limit";break
      c.resolve_battle(b)
      if b.outcome!="victory":result.failure=b.outcome;break
      var reward=c.choices.map(func(choice):return choice.type).find("resource")
      if reward<0 or not c.choose_reward(reward):result.failure="resource reward rejected";break
     if c.phase=="world":
      while c.supplies>0 and c.roster.any(func(unit):return unit.hp>0 and (unit.hp<unit.max_hp*0.7 or unit.mp<unit.max_mp*0.5)):c.use_supply()
     if selected.kind=="extract":result.cleared=c.extract([])
    results.append(result)
   print("MIXED_ROUTE ",captain,"/",profile," done");await process_frame
 var changed=[]
 for source in hashes:
  if FileAccess.get_sha256("res://game/"+source)!=hashes[source]:changed.append(source)
 var report={"label":label,"source_hashes":hashes,"changed_sources":changed,"invalid_actions":sim.invalid_actions,"policy":"36 prepared mixed-build expeditions; 18 actual identity teams, two fixed 2+2 builds paired on same generated route per team; legal 360XP actors, 11 low-tier items, four legally bound starting relics; no extra relics or purchases; only resource rewards, actual attrition/supplies/death, no further training", "results":results}
 var file=FileAccess.open("res://artifacts/mixed-routes-"+label+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report));file.close()
 var incomplete=results.any(func(row):return row.failure in ["step limit","deployment rejected","route rejected","resource reward rejected"])
 print("MIXED_ROUTES_DONE clears=",results.filter(func(row):return row.cleared).size(),"/",results.size()," invalid=",sim.invalid_actions," changed=",changed)
 quit(0 if sim.invalid_actions==0 and changed.is_empty() and not incomplete else 1)
