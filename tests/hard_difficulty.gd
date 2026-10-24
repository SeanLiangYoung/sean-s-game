extends SceneTree
const Rules=preload("res://game/rules.gd")
const Campaign=preload("res://game/campaign.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:
  failures+=1
  if failures<12:print("FAIL: ",message)
func _initialize():
 for biome in ["border","wood","waste","frost","marsh","ruins"]:
  for threat in ["normal","elite","boss"]:
   for tier in range(3):
    for rank in [1,6]:
     for seed_value in [123,71023]:
      var config={"seed":seed_value,"biome":biome,"threat":threat,"campaign_difficulty":rank}
      var normal=Rules.new()
      normal.start_battle(normal.default_party().slice(0,5),tier,[],config)
      for level in [0,1,2,3]:
       config.overall_difficulty=level
       var battle=Rules.new()
       battle.start_battle(battle.default_party().slice(0,5),tier,[],config)
       if level==0:
        check(battle.actors==normal.actors,"normal difficulty retains baseline actors")
        continue
       for actor in battle.actors:
        var original=normal.find_actor(actor.id)
        if actor.side==0:
         check(actor==original,"configured difficulties do not modify player stats")
        else:
         var hard_hp=roundi(original.max_hp*1.25)
         var hard_power=roundi(original.power*1.15)
         var expected_hp=hard_hp if level==1 else roundi(hard_hp*1.25)
         var expected_power=hard_power if level==1 else roundi(hard_power*1.15)
         var nightmare_hp=roundi(hard_hp*1.25)
         var nightmare_power=roundi(hard_power*1.15)
         if level==3:
          expected_hp=roundi(nightmare_hp*1.50)
          expected_power=roundi(nightmare_power*1.25)
          check(actor.max_hp>nightmare_hp and actor.power>nightmare_power,"final difficulty strictly exceeds corresponding nightmare enemy stats")
         check(actor.max_hp==expected_hp and actor.hp==actor.max_hp,"difficulty scales final enemy HP including affixes")
         check(actor.power==expected_power,"difficulty scales final enemy power including affixes")
         if level==2:
          check(actor.max_hp>hard_hp and actor.power>hard_power,"nightmare strictly exceeds corresponding hard enemy stats")
         check(actor.get("armor",0)==original.get("armor",0) and actor.speed==original.speed and actor.range==original.range,"configured difficulties retain armor speed and range")
       check(battle.obstacles==normal.obstacles,"difficulty retains seeded battlefield")
 # Both legacy encounters and generated routes must forward the saved difficulty.
 for generated in [false,true]:
  for level in [0,1,2,3]:
   var path="user://hard-difficulty-tests.json"
   var c=Campaign.new(path)
   c.overall_difficulty=level
   if generated:
    c.cleared_regions=["border","wood","waste","frost","marsh"]
    c.start_region("border")
    var first=c.route.visible_nodes()[0]
    c.enter_route(first.id)
    var battle_node=c.route.visible_nodes().filter(func(n):return n.kind=="battle")[0]
    c.enter_route(battle_node.id)
   else:c.depart()
   var index=int(c.route.node(c.route.current).encounter) if generated else 0
   var preview=c.preview_enemies(index)
   var battle=c.make_battle(["hero"],index)
   check(battle!=null,"campaign starts selected difficulty")
   if battle==null:continue
   var enemies=battle.actors.filter(func(u):return u.side==1)
   check(preview.size()==enemies.size(),"preview retains enemy count")
   for i in enemies.size():
    for stat in ["name","max_hp","hp","power","armor","speed","range","boss","trait","affix"]:
     check(preview[i].get(stat)==enemies[i].get(stat),"preview matches actual enemy "+stat)
   if not generated:
    var baseline=Rules.new()
    baseline.start_battle([],0)
    var expected_hp=baseline.find_actor("enemy0").max_hp
    if level in [1,2,3]:expected_hp=roundi(expected_hp*1.25)
    if level in [2,3]:expected_hp=roundi(expected_hp*1.25)
    if level==3:expected_hp=roundi(expected_hp*1.50)
    check(enemies[0].max_hp==expected_hp,"legacy encounter receives difficulty without changing encounter generation")
   var loaded=Campaign.new(path)
   check(loaded.load_game() and loaded.overall_difficulty==level,"prebattle save retains difficulty")
   DirAccess.remove_absolute(path)
 print("CHECKS: %d FAILURES: %d"%[checks,failures])
 quit(1 if failures else 0)
