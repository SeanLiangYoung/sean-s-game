extends SceneTree
const Jobs=preload("res://game/professions.gd")
const Relic=preload("res://game/relics.gd")
const Rules=preload("res://game/rules.gd")
const Campaign=preload("res://game/campaign.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func _initialize():
 check(Jobs.ALL_SKILLS.size()==36,"36 playable skills")
 check(Jobs.ITEMS.values().filter(func(item):return not item.get("legacy",false)).size()==24,"24 equipment choices")
 check(Relic.CATALOG.size()==110,"110 relics with tradeoffs")
 if Jobs.ALL_SKILLS.size()!=36:
  finish();return
 for job in Jobs.JOBS:
  check(Jobs.JOBS[job].skills.size()==6,"six skills per job "+job)
  for id in Jobs.JOBS[job].skills:
   check(Jobs.ALL_SKILLS.has(id) and Jobs.ALL_SKILLS[id].job==job,"profession owns "+id)
 var hero=Rules.new().default_party()[0]
 hero.xp=1000
 check(Jobs.prerequisite("hero_rally")=="hero_heal","advanced support requires intermediate support")
 hero.skill_ranks.strike=2
 check(Jobs.training_reason(hero,"hero_rally")!="","cannot skip intermediate tier")
 check("直接伤害+12" in Jobs.rank_description(hero,"hero_sunder",3),"rank preview includes exposure scaling")
 hero.skill_ranks.hero_heal=2
 check(Jobs.training_reason(hero,"hero_rally")=="","tier unlock becomes available")
 var stats=Jobs.stats(hero,[{"id":"runic_sword","owner":"hero"},{"id":"focus_guard","owner":"hero"}])
 check(stats.skill_power==0 and stats.power==hero.power+4,"medium gear only raises basic attack")
 hero.merge(stats,true);hero.speed=100
 hero.skill_ranks.hero_sunder=1
 var b=Rules.new();b.start_battle([hero],0,[Relic.instance("rune",1)])
 var a=b.find_actor("hero");var foe=b.find_actor("enemy0")
 b.obstacles=[];foe.cell=a.cell+Vector2i(1,0);foe.hp=200;foe.max_hp=200
 check(b.cast(foe.id,"hero_sunder"),"armor break skill executes")
 check(foe.statuses.has("exposed"),"armor break applies exposure")
 check(foe.hp==200-a.power-10,"rune amplifies damage without equipment special effects")
 var exposed=foe.hp;b.deal_damage(a,foe,10)
 check(exposed-foe.hp>=14,"exposure benefits following attacks")
 hero=Rules.new().default_party()[0];hero.speed=100;hero.skill_ranks.ranger_pin=1
 b=Rules.new();b.start_battle([hero],0);a=b.find_actor("hero");foe=b.find_actor("enemy0");foe.cell=a.cell+Vector2i(1,0)
 check(b.cast(foe.id,"ranger_pin") and foe.statuses.has("stagger"),"pin shot controls next action")
 b.begin_turn(foe);check(foe.ap==3,"control costs exactly one action point")
 hero=Rules.new().default_party()[0];hero.speed=100;hero.skill_ranks.hero_rally=1
 b=Rules.new();b.start_battle([hero],0,[Relic.instance("well",1,"hero")]);a=b.find_actor("hero");a.mp=10
 check(b.cast(a.id,"hero_rally") and a.mp>10-6,"mana support restores mana after paying cost")
 hero=Rules.new().default_party()[0];hero.speed=100;hero.skill_ranks.medic_barrier=1
 hero.merge(Jobs.stats(hero,[{"id":"ward_staff","owner":"hero"}]),true)
 b=Rules.new();b.start_battle([hero],0,[Relic.instance("wardstone",1,"hero")]);a=b.find_actor("hero");a.hp=20
 check(b.cast(a.id,"medic_barrier") and a.hp>20 and a.statuses.has("shield"),"healing barrier combines both effects")
 check(a.statuses.shield.bonus==4,"only relic boosts shield")
 hero=Rules.new().default_party()[0];hero.speed=100;hero.skill_ranks.engineer_snare=1
 hero.merge(Jobs.stats(hero,[{"id":"snare_crossbow","owner":"hero"}]),true);hero.speed=100
 b=Rules.new();b.start_battle([hero],0,[Relic.instance("cog",1,"hero")]);a=b.find_actor("hero");b.obstacles=[]
 check(b.cast(a.cell+Vector2i(0,1),"engineer_snare") and b.traps[0].damage==36,"trap skill and relic combine; gear has no special effect")
 var c=Campaign.new("user://content-expansion.json")
 check(c.equipment.size()==8,"starting gear stays bounded")
 c.phase="world";c.acquire_relic("harvest","hero");c.roster[0].hp=20
 var before=c.roster[0].hp;c.use_supply()
 check(c.roster[0].hp-before<24,"new healing penalties apply to field supplies")
 var copy=Campaign.new();check(copy.load_data(JSON.parse_string(JSON.stringify(c.to_data()))),"new content survives JSON save")
 finish()
func finish():
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
