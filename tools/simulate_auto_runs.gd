extends SceneTree
# Reproducible fresh-save runs using the same planner as the Auto button.
const Campaign=preload("res://game/campaign.gd")
const PARTY=["hero","blade","ranger","medic","engineer"]
func _initialize():call_deferred("run")
func play(b) -> Dictionary:
 var steps=0
 while b.outcome=="" and steps<2000:
  var accepted=true
  if b.active().side==1:b.enemy_step()
  else:
   var action=b.auto_action()
   match action.get("action",""):
    "attack":accepted=b.attack(action.target)
    "skill":accepted=b.cast(action.target,action.skill)
    "move":accepted=b.move_to(action.target)
    "rest_mp":accepted=b.rest("mp")
    "rest_hp":accepted=b.rest("hp")
    "end":accepted=b.end_action()
    _:accepted=false
  if not accepted:return {"error":"invalid auto action","steps":steps}
  steps+=1
 return {"outcome":b.outcome,"steps":steps,"rounds":b.round_no,"error":"step limit" if b.outcome=="" else ""}
func run():
 var region="border"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--region="):region=arg.trim_prefix("--region=")
 var simulation_save="user://simulation-auto-%s-%d.json"%[region,Time.get_ticks_usec()]
 var source_hashes={}
 for source in DirAccess.get_files_at("res://game"):
  if source.ends_with(".gd"):source_hashes[source]=FileAccess.get_sha256("res://game/"+source)
 var results=[]
 for index in range(100):
  var c=Campaign.new(simulation_save)
  c.rng.seed=2026102500+index
  for pair in [[0,"hero"],[1,"blade"],[2,"ranger"],[3,"medic"],[4,"engineer"],[5,"hero"],[6,"blade"]]:c.equip_item(pair[0],pair[1])
  c.start_region(region)
  var result={"run":index+1,"seed":2026102500+index,"region":region,"cleared":false,"battles":[],"failure":""}
  for depth in range(c.route.nodes[-1].depth+1):
   var available=c.route.available()
   if available.is_empty():break
   # Fixed policy: fight when offered, otherwise prefer free recovery.
   var selected=c.route.node(available[0])
   for id in available:
    var n=c.route.node(id)
    if n.kind=="battle":selected=n;break
    if n.kind=="supply":selected=n
   if not c.enter_route(selected.id):result.failure="route rejected";break
   if selected.kind=="battle":
    var ids=PARTY.filter(func(id):return c.roster.any(func(u):return u.id==id and u.hp>0))
    var b=c.make_battle(ids,selected.encounter)
    if b==null:result.failure="deployment rejected";break
    var outcome=play(b)
    outcome["survivors"]=b.actors.filter(func(a):return a.side==0 and a.hp>0).size()
    outcome["party_hp"]=0
    for actor in b.actors:
     if actor.side==0:outcome.party_hp+=maxi(0,actor.hp)
    outcome["supplies_remaining"]=c.supplies
    outcome["depth"]=depth
    outcome["threat"]=selected.threat
    result.battles.append(outcome)
    if outcome.error!="":result.failure=outcome.error;break
    c.resolve_battle(b)
    if b.outcome!="victory":result.failure=b.outcome;break
    var resource_index=-1
    for reward_index in range(c.choices.size()):
     if c.choices[reward_index].type=="resource":resource_index=reward_index;break
    if resource_index<0 or not c.choose_reward(resource_index):result.failure="reward rejected";break
   if c.phase=="world":
    while c.supplies>0 and c.roster.any(func(u):return u.hp>0 and (u.hp<u.max_hp*0.7 or u.mp<u.max_mp*0.5)):c.use_supply()
   if selected.kind=="extract":result.cleared=c.extract([])
  results.append(result)
  print("RUN %d cleared=%s battles=%d failure=%s"%[index+1,result.cleared,result.battles.size(),result.failure])
  if index%5==0:await process_frame
 var clears=results.filter(func(r):return r.cleared).size()
 var report={"source_hashes":source_hashes,"policy":"fresh starter party; battles then supplies; resource rewards; heal below 70% HP or 50% MP", "seed_start":2026102500,"region":region,"runs":100,"clears":clears,"failures":100-clears,"results":results}
 var file=FileAccess.open("res://artifacts/auto-simulation-"+region+".json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "));file.close()
 DirAccess.remove_absolute(ProjectSettings.globalize_path(simulation_save))
 print("SIMULATION: clears=%d/100 failures=%d/100"%[clears,100-clears])
 for source in source_hashes:
  if FileAccess.get_sha256("res://game/"+source)!=source_hashes[source]:push_error("Source changed during simulation: "+source);quit(1);return
 var errors=results.filter(func(r):return r.failure not in ["","gameover","defeat"])
 quit(1 if not errors.is_empty() else 0)
