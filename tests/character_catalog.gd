extends SceneTree
const Campaign=preload("res://game/campaign.gd")
const Characters=preload("res://game/characters.gd")
const Jobs=preload("res://game/professions.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func _initialize():
 check(Characters.CATALOG.size()==18,"eighteen canonical characters")
 for job in Jobs.JOBS:
  check(Characters.CATALOG.values().filter(func(d):return d.job==job).size()==3,"three identities for "+job)
 for id in Characters.CATALOG:
  var d=Characters.CATALOG[id]
  check(d.story.length()>90 and d.effect.length()>30 and not d.talent.is_empty(),"full biography and talent: "+id)
  var unit=Characters.create(id)
  check(unit.profession==d.job and unit.character_id==id,"catalog creates identity "+id)
 for captain in Characters.CAPTAINS:
  var c=Campaign.new("user://character-catalog-test.json")
  check(c.select_captain(captain) and c.roster[0].id=="hero" and c.roster[0].character_id==captain,"captain selected "+captain)
  c.depart()
  check(not c.select_captain("shen"),"cannot change captain after departure")
  var loaded=Campaign.new(c.save_path)
  check(loaded.load_data(c.to_data()) and loaded.roster[0].character_id==captain,"captain and snapshot round trip")
 var c=Campaign.new("user://character-catalog-test.json")
 c.Rules.new().skill_range(c.roster[2],"sniper")
 check(not c.roster[2].has("talent_state"),"skill preview does not write transient battle state into roster")
 check(not c.select_captain("bai"),"mercenaries cannot become captain")
 check(c.start_region("border"),"start recruit route")
 c.route.setup("border");c.encounters=["open","open","open"]
 c.enter_route("0b");c.enter_route("1b");c.silver=2000
 var baseline=c.to_data()
 for index in c.recruit_candidates().size():
  c.load_data(baseline)
  var id=c.recruit_candidates()[index]
  var owned=c.roster.any(func(u):return u.character_id==id)
  check(c.can_hire(index)!=owned,"owned identity recruitment restriction "+id)
  if not owned:
   check(c.hire(index) and c.roster[-1].character_id==id,"recruit "+id)
   check(not c.hire(index),"unique recruit "+id)
 var invalid=c.to_data();invalid.roster[0].character_id="absent"
 var before=c.to_data()
 check(not c.load_data(invalid) and c.to_data()==before,"invalid identity rejected atomically")
 invalid=c.to_data();invalid.roster[0].character_id="bai"
 check(not c.load_data(invalid),"captain identity must belong to captain pool")
 invalid=c.to_data();invalid.roster[-1].character_id=invalid.roster[1].character_id
 check(not c.load_data(invalid),"duplicate identities rejected")
 var old=baseline.duplicate(true);old.version=6
 for unit in old.roster:unit.erase("character_id")
 old.roster[1].name="岚";old.roster[4].name="铁九";old.roster[5].name="奥伦"
 var migrated=Campaign.new(c.save_path)
 check(migrated.load_data(old),"legacy save migrates")
 check(migrated.roster[1].name=="岚" and migrated.roster[4].name=="铁九" and migrated.roster[5].name=="奥伦","legacy names preserved")
 check(migrated.roster[0].character_id=="shen" and migrated.roster[4].character_id=="li","legacy identities assigned")
 check(migrated.load_data(migrated.to_data()),"migrated identity reloads")
 DirAccess.remove_absolute(c.save_path)
 print("CHECKS: %d FAILURES: %d"%[checks,failures])
 quit(1 if failures else 0)
