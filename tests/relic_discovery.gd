extends SceneTree
const Campaign=preload("res://game/campaign.gd")
var checks=0
var failures=0
func check(ok: bool,label: String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label)
func _initialize():
 var path="user://relic-discovery-tests.json"
 for suffix in ["",".relics",".achievements"]:DirAccess.remove_absolute(path+suffix)
 var c=Campaign.new(path)
 check(c.has_method("discover_relic"),"campaign tracks encountered relics")
 if not c.has_method("discover_relic"):
  print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1);return
 check(c.discovered_relics.is_empty(),"fresh catalog locked")
 c.discover_relic("ember");c.discover_relic("ember");c.discover_relic("invalid")
 check(c.discovered_relics==["ember"],"unique valid IDs only")
 check(c.relic_achievement_count()==1,"first discovery milestone")
 var fresh=Campaign.new(path)
 check(fresh.discovered_relics==["ember"],"discovery survives new campaign without checkpoint")
 var ids=Campaign.Relic.CATALOG.keys()
 for id in ids.slice(0,10):c.discover_relic(id)
 check(c.relic_achievement_count()==2,"ten milestone")
 for id in ids.slice(0,100):c.discover_relic(id)
 check(c.relic_achievement_count()==3,"hundred milestone")
 for id in ids:c.discover_relic(id)
 check(c.relic_achievement_count()==4,"full catalog milestone")
 check(c.save_game(),"save discovery checkpoint")
 DirAccess.remove_absolute(path+".relics")
 var loaded=Campaign.new(path)
 check(loaded.load_game() and loaded.discovered_relics.size()==ids.size(),"save recovers missing profile")
 var legacy=Campaign.new(path+"-legacy")
 var data=legacy.to_data()
 data.erase("discovered_relics")
 data.relics=[Campaign.Relic.instance("ember",1,"")]
 check(legacy.load_data(data) and "ember" in legacy.discovered_relics,"legacy owned relic migrates")
 var bad=legacy.to_data();bad.discovered_relics=["invalid"]
 check(not legacy.load_data(bad),"invalid discovery save rejected")
 for suffix in ["",".relics",".achievements"]:
  DirAccess.remove_absolute(path+suffix);DirAccess.remove_absolute(path+"-legacy"+suffix)
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
