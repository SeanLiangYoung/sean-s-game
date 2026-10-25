extends SceneTree
const Campaign=preload("res://game/campaign.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func _initialize():
 var validator=Campaign.new()
 check(validator.load_data({})==false,"missing version safely rejected")
 var c=Campaign.new("user://boss-loss.json");c.rng.seed=12;c.start_region("frost")
 var boss=c.route.nodes.filter(func(n):return n.get("threat","")=="boss")[0]
 c.route.visited=[]
 for depth in range(boss.depth):c.route.visited.append(str(depth)+"a")
 c.route.current=c.route.visited[-1];c.route.completed=true
 c.relics=[Campaign.Relic.instance("ember",1)]
 check(c.enter_route(boss.id),"boss reachable after prior stages")
 var b=c.make_battle(["blade"],boss.encounter)
 b.find_actor("blade").hp=0;b.check_outcome()
 check(b.outcome=="defeat" and c.resolve_battle(b),"nonhero boss defeat settles")
 check(c.phase=="camp" and c.relics.is_empty(),"boss defeat retreats to camp and forfeits expedition relics")
 check(not c.extract([0]) and c.roster[1].hp==0,"no boss bypass; casualties preserved")
 var loaded=Campaign.new();check(loaded.load_data(JSON.parse_string(JSON.stringify(c.to_data()))),"retreat state saves")
 c=Campaign.new();var legacy=c.to_data();legacy.version=2
 for u in legacy.roster:u.erase("skill_ranks");u.erase("xp")
 check(c.load_data(legacy) and not c.roster[1].skill_ranks.has("blade_hunt"),"legacy migration grants no new advanced skills for free")
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
