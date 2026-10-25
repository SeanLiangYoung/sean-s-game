extends SceneTree
const Campaign=preload("res://game/campaign.gd")
var checks=0
var failures=0
func check(ok: bool,label: String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label)
func _initialize():
 var c=Campaign.new("user://village-story-test.json")
 check(c.has_method("read_home"),"home exploration available")
 if not c.has_method("read_home"):finish();return
 for home in c.VillageStory.HOMES.values():
  if home.resident!="":check(c.roster.any(func(u):return u.id==home.resident),"home belongs to an actual starting resident: "+home.resident)
 var cash=c.silver;var food=c.supplies;var random_state=c.rng.state
 check(c.read_home("lodger")!="","arrival can be discovered")
 check(c.read_home("lodger")=="","same fragment cannot repeat")
 check(not c.repair_home("memory"),"no repair time before first expedition")
 check(not c.repair_home("missing"),"invalid house rejected")
 c.roster[1].hp=0
 check(c.read_home("blade")=="absence_blade","dead companion never speaks new living dialogue")
 check("home_blade" not in c.story_state.seen,"unmet living scene not recorded after death")
 var saved=c.to_data()
 check(saved.has("story_state"),"story saved")
 var d=Campaign.new("user://village-story-load.json")
 check(d.load_data(saved,false) and d.story_state==c.story_state,"story restores")
 var bad=saved.duplicate(true);bad.story_state.seen.append("invented")
 var before=d.to_data()
 check(not d.load_data(bad,false) and before==d.to_data(),"corrupt narrative rejected atomically")
 bad=saved.duplicate(true);bad.story_state.repaired=["missing"]
 check(not d.load_data(bad,false),"unknown home repair rejected")
 var old=saved.duplicate(true);old.erase("story_state")
 check(d.load_data(old,false) and d.story_state.seen.is_empty(),"legacy save migrates")
 c.expedition=1
 check(c.repair_home("memory"),"return allows one repair")
 check(not c.repair_home("medic"),"one repair per expedition")
 check(c.silver==cash and c.supplies==food and c.rng.state==random_state,"narrative leaves balance and reward RNG unchanged")
 check(c.read_home("memory")!="","dead resident has a remembered home")
 check(c.start_region("border"),"depart")
 check(not c.repair_home("medic") and c.read_home("medic")=="","camp interactions forbidden on expedition")
 c.record_route_story(false)
 check("border_approach" in c.story_state.seen,"region arrival discovered")
 var count=c.story_state.seen.size();c.record_route_story(false)
 check(c.story_state.seen.size()==count,"repeat discovery idempotent")
 c.route.current=c.route.nodes.filter(func(n):return n.depth==3)[0].id
 c.record_route_story(false)
 check("border_trace" in c.story_state.seen,"deep region trace")
 check("border_after" not in c.story_state.seen,"boss fragment gated")
 c.record_route_story(true)
 check("border_after" in c.story_state.seen,"boss aftermath recorded")
 var rollback=c.snapshot.duplicate(true)
 check(c.load_data(rollback,false) and "border_after" not in c.story_state.seen and "memory" in c.story_state.repaired,"checkpoint restores narrative alongside campaign")
 for suffix in ["",".relics",".achievements"]:
  DirAccess.remove_absolute("user://village-story-test.json"+suffix)
  DirAccess.remove_absolute("user://village-story-load.json"+suffix)
 finish()
func finish():
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
