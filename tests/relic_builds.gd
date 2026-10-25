extends SceneTree
const Relic=preload("res://game/relics.gd")
const Rules=preload("res://game/rules.gd")
const Campaign=preload("res://game/campaign.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func fight(ids):
 var b=Rules.new();var entries=[]
 for id in ids:entries.append(Relic.instance(id,entries.size()+1,"hero" if Relic.definition(id).scope=="personal" else ""))
 b.start_battle(b.default_party().slice(0,2),0,entries)
 return b
func _initialize():
 check(Relic.CATALOG.size()>=110,"at least 110 relics")
 if not Relic.CATALOG.has("blood_1"):finish();return
 var names=[]
 for id in Relic.CATALOG:
  var d=Relic.definition(id)
  check(d.name not in names,"unique relic name "+id);names.append(d.name)
  check(not d.benefit.is_empty() and not d.risk.is_empty(),"real tradeoff "+id)
 var b=fight(["blood_1"]);var hero=b.find_actor("hero");var foe=b.find_actor("enemy0")
 foe.hp=1000;foe.max_hp=1000;hero.hp=hero.max_hp
 var hp=foe.hp;b.deal_damage(hero,foe,10)
 var full=hp-foe.hp;hero.hp=20;hp=foe.hp;b.deal_damage(hero,foe,10)
 check(hp-foe.hp==full+10,"blood relic activates only at half health")
 b=fight(["blood_1","blood_2"]);hero=b.find_actor("hero")
 check(b.relic_modifier(hero,"lifesteal")>=0.12,"two distinct blood relics activate lifesteal resonance")
 b=fight(["blood_1","blood_1"])
 check(b.relic_modifier(b.find_actor("hero"),"lifesteal")==0,"duplicate IDs cannot complete resonance")
 b=fight(["blood_1","blood_6"])
 check(b.relic_modifier(b.find_actor("hero"),"lifesteal")>=0.12,"personal relic completes own resonance")
 check(b.relic_modifier(b.find_actor("blade"),"lifesteal")==0,"personal resonance excludes other allies")
 b=fight(["hunt_1"]);hero=b.find_actor("hero");foe=b.find_actor("enemy0");foe.hp=1000;foe.max_hp=1000
 hp=foe.hp;b.deal_damage(hero,foe,10);var first=hp-foe.hp
 hp=foe.hp;b.deal_damage(hero,foe,10)
 check(first-(hp-foe.hp)==12,"first hit bonus is once per actor turn")
 b.begin_turn(hero);hp=foe.hp;b.deal_damage(hero,foe,10)
 check(hp-foe.hp==first,"first hit resets on own turn")
 b=fight(["ward_1"]);hero=b.find_actor("hero");b.begin_turn(hero)
 check(hero.statuses.has("shield"),"ward relic grants shield at own turn start")
 b=fight(["arcane_1"]);hero=b.find_actor("hero");hero.mp=0;b.begin_turn(hero)
 check(hero.mp==3,"arcane turn mana actually restores mana")
 b=fight(["hunt_2"]);hero=b.find_actor("hero");b.begin_turn(hero);var ap=hero.ap
 b.deal_damage(hero,b.find_actor("enemy0"),999);check(hero.ap==ap+1,"relic kill restores AP")
 b.deal_damage(hero,b.find_actor("enemy1"),999);check(hero.ap==ap+1,"relic kill AP capped once per actor turn")
 var c=Campaign.new("user://relic-builds.json");c.depart();b=c.make_battle(["hero"],0)
 for a in b.actors:
  if a.side==1:a.hp=0
 b.check_outcome();c.resolve_battle(b)
 check(c.choices.size()==5,"five reward choices")
 var relic_ids=[]
 for r in c.choices:
  if r.type=="relic":relic_ids.append(r.id)
 check(relic_ids.size()==3 and relic_ids[0]!=relic_ids[1] and relic_ids[1]!=relic_ids[2] and relic_ids[0]!=relic_ids[2],"three distinct relic choices")
 check(Campaign.new().load_data(JSON.parse_string(JSON.stringify(c.to_data()))),"five-choice reward checkpoint reloads")
 b=fight(["ward_1"]);hero=b.find_actor("hero")
 b.put_status(hero,"shield","blade",30);b.begin_turn(hero)
 check(hero.statuses.shield.bonus==30 and hero.statuses.shield.source=="blade","automatic shield preserves stronger allied shield")
 b=fight(["blood_1","blood_2","blood_3","blood_4"]);hero=b.find_actor("hero")
 check(b.relic_modifier(hero,"low_hp_damage")==32,"four-piece resonance adds its bonus to both relics")
 var old=c.to_data();old.version=5
 old.choices=[{"id":"healer_guard","name":"护疗圆盾","type":"equipment","desc":"旧装备说明","color":"#b4a1d1"},Campaign.REWARDS[-1].duplicate(true),Campaign.REWARDS[-2].duplicate(true)]
 var migrated=Campaign.new()
 var loaded=migrated.load_data(old)
 check(loaded,"legacy pending healer shield reward loads")
 if loaded:
  check(migrated.choices[0].id=="focus_guard" and migrated.choose_reward(0),"legacy shield reward maps to medium shield and can be claimed")
 finish()
func finish():
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
