extends SceneTree
const Campaign=preload("res://game/campaign.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func _initialize():
 var path="user://achievement-tests.json"
 for suffix in ["",".achievements"]:DirAccess.remove_absolute(path+suffix)
 var c=Campaign.new(path)
 check(c.has_method("achievement_bonus"),"campaign exposes achievement bonuses")
 if not c.has_method("achievement_bonus"):
  print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1);return
 var base=c.character_stats("hero").power
 check(c.achievement_bonus()=={"power":0,"armor":0},"new profile has no bonuses")
 c.cleared_regions=["border","wood","waste","frost","marsh"]
 c.save_game()
 check(c.completed_difficulties.is_empty(),"five regions do not unlock achievement")
 c.cleared_regions.append("ruins")
 check(c.save_game() and c.completed_difficulties==[0],"full normal clear unlocks achievement")
 check(c.character_stats("hero").power==base+1,"achievement increases actual power")
 for i in range(3):c.refresh_stats();c.save_game()
 check(c.character_stats("hero").power==base+1,"repeated save and refresh cannot stack bonuses")
 var battle=c.Rules.new()
 battle.start_battle([c.roster[0].duplicate(true)],0)
 check(battle.find_actor("hero").power==base+1,"battle receives bonus")
 var fresh=Campaign.new(path)
 check(fresh.completed_difficulties==[0] and fresh.character_stats("hero").power==base+1,"new campaign inherits permanent achievement")
 fresh.depart()
 fresh.overall_difficulty=1;fresh.cleared_regions=c.cleared_regions.duplicate();fresh.phase="camp"
 check(fresh.save_game() and fresh.completed_difficulties==[0,1],"hard clear adds distinct achievement")
 check(fresh.achievement_bonus()=={"power":1,"armor":1},"small bonuses sum across difficulties")
 check(fresh.restore_snapshot() and fresh.completed_difficulties==[0,1],"snapshot rollback preserves permanent achievements")
 var legacy=c.to_data();legacy.erase("completed_difficulties")
 var other=Campaign.new("user://achievement-legacy-tests.json")
 check(other.load_data(legacy) and 0 in other.completed_difficulties,"old completed save receives matching achievement")
 var bad=c.to_data();bad.completed_difficulties=[0,0]
 check(not other.load_data(bad),"duplicate achievement rejected")
 bad=c.to_data();bad.completed_difficulties=[4]
 check(not other.load_data(bad),"unknown difficulty rejected")
 for rank in [2,3]:
  c.overall_difficulty=rank;c.save_game()
 check(c.achievement_bonus()=={"power":2,"armor":2},"all four achievements have bounded total bonuses")
 var hard_path="user://achievement-high-only-tests.json"
 for suffix in ["",".achievements"]:DirAccess.remove_absolute(hard_path+suffix)
 var high=Campaign.new(hard_path)
 high.overall_difficulty=3;high.cleared_regions=c.cleared_regions.duplicate()
 high.save_game()
 check(high.completed_difficulties==[3],"high difficulty does not grant uncompleted lower difficulty achievements")
 check(high.achievement_bonus()=={"power":0,"armor":1},"only earned difficulty reward applies")
 var preview=high.preview_equipment(0,"hero")
 check(preview.power==high.character_stats("hero").power+high.Professions.ITEMS.sword.power and preview.armor==1,"equipment preview retains achievement bonus")
 var reloaded=Campaign.new(hard_path)
 check(reloaded.load_game() and reloaded.completed_difficulties==[3],"disk reload preserves distinct achievement")
 var corrupt=FileAccess.open(hard_path+".achievements",FileAccess.WRITE)
 corrupt.store_string("[99]");corrupt.close()
 var rescued=Campaign.new(hard_path)
 check(rescued.completed_difficulties.is_empty() and rescued.load_game() and rescued.completed_difficulties==[3],"invalid profile safely falls back to valid save achievements")
 for suffix in ["",".achievements"]:DirAccess.remove_absolute(hard_path+suffix)
 for suffix in ["",".achievements"]:DirAccess.remove_absolute(path+suffix)
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
