extends SceneTree
const Simulation=preload("res://tools/relic_mix_simulation.gd")
const Relic=preload("res://game/relics.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func _initialize():
 var sim=Simulation.new()
 var setups=sim.loadouts()
 check(setups.size()==51,"control, 16 pure builds, 28 pairs, six stress builds")
 var identities={}
 var pair_count=0
 for id in setups:
  if id.begins_with("mix_"):pair_count+=1
  check(setups[id].size()==(0 if id=="none" else 4),"equal relic budget "+id)
 check(pair_count==28,"all eight themes paired without omissions")
 for captain in Simulation.Characters.CAPTAINS:
  for profile in Simulation.PROFILES:
   var party=sim.party(captain,profile)
   check(party.size()==5 and party[0].character_id==captain,"real five-actor identity team")
   check(party.map(func(u):return u.armor).reduce(func(total,value):return total+value,0)==7,"same team armor budget across role compositions")
   for unit in party:
    identities[unit.character_id]=true
    check(unit.xp>=0 and unit.xp<=Simulation.XP_BUDGET,"training stays funded")
    for skill in unit.skill_ranks:
     var prerequisite=Simulation.Jobs.prerequisite(skill)
     check(prerequisite=="" or Simulation.Jobs.skill_rank(unit,prerequisite)>=2,"legal training prerequisite "+skill)
   for combo in setups:
    var entries=sim.bound_entries(setups[combo],party)
    var owners=[];var ids=[]
    for entry in entries:
     check(Relic.CATALOG.has(entry.id) and entry.id not in ids,"known distinct relic IDs")
     ids.append(entry.id)
     if Relic.definition(entry).scope=="personal":
      check(entry.owner in party.map(func(u):return u.id) and entry.owner not in owners,"personal relic uses real actor ID without stacking slots")
      owners.append(entry.owner)
     else:check(entry.owner=="","team relic remains unbound")
 check(identities.size()==Simulation.Characters.CATALOG.size(),"all character identities appear in study")
 # Suo's snare used to leave a 1-AP enemy retrying an unaffordable move forever.
 var b=Simulation.Rules.new();b.start_battle(b.default_party().slice(0,2),0)
 b.obstacles=[]
 var enemy=b.find_actor("enemy0");enemy.cell=Vector2i(2,0);enemy.ap=1;enemy.enemy_used=true
 b.put_status(enemy,"snare","hero")
 b.order_index=b.order.find(b.actors.find(enemy))
 check(b.actors.all(func(actor):return actor.has("statuses")),"all actors initialize status dictionaries for tactical evaluation")
 var before=enemy.ap;b.enemy_step()
 check(b.active().id!=enemy.id or enemy.ap<before,"snared one-AP enemy progresses instead of stalling control teams")
 # Mark once, then preserve AP for the primary attack rather than repeatedly tagging targets.
 var units=sim.party("shen","balanced")
 b=Simulation.Rules.new();b.start_battle(units,0);b.obstacles=[]
 var ranger=b.find_actor("ya");ranger.cell=Vector2i.ZERO
 for i in range(3):
  var foe=b.find_actor("enemy%d"%i);foe.hp=500;foe.max_hp=500;foe.cell=Vector2i(3,-i)
 b.order_index=b.order.find(b.actors.find(ranger));b.begin_turn(ranger)
 sim.step(b);sim.step(b)
 var marks=ranger.used_skills.filter(func(id):return Simulation.Jobs.ALL_SKILLS[id].effect=="mark")
 check(marks.size()==1,"study policy spends at most one mark action per actor turn")
 var party=sim.party("shen","balanced")
 b=Simulation.Rules.new();b.start_battle(party,0);b.obstacles=[]
 ranger=b.find_actor("ya");ranger.cell=Vector2i.ZERO
 for i in range(3):
  var foe=b.find_actor("enemy%d"%i);foe.hp=500 if i==0 else 0;foe.max_hp=500;foe.cell=Vector2i(3,-i)
 b.order_index=b.order.find(b.actors.find(ranger));b.begin_turn(ranger)
 sim.step(b);sim.step(b)
 check(ranger.talent_state.snipe_used and not ranger.talent_state.moved,"unmoved archer talent gets a legal primary-attack opportunity")
 # Full command resonance must not give every actor a second permanent AP on top of its team item.
 b=Simulation.Rules.new()
 b.start_battle(b.default_party().slice(0,2),0,[Relic.instance("command_1",1),Relic.instance("command_2",2),Relic.instance("command_3",3),Relic.instance("command_4",4)])
 var hero=b.find_actor("hero")
 check(hero.max_ap==5,"four command pieces avoid doubling permanent team AP")
 check(b.relic_modifier(hero,"first_damage")==6 and b.relic_modifier(hero,"kill_mp")==2,"command four-piece supports opening and kill mana instead")
 b=Simulation.Rules.new()
 b.start_battle(b.default_party().slice(0,2),0,[Relic.instance("blood_1",1),Relic.instance("blood_2",2),Relic.instance("blood_3",3),Relic.instance("blood_4",4)])
 hero=b.find_actor("hero");enemy=b.find_actor("enemy0")
 hero.hp=int(hero.max_hp/2)+1
 check(b.relic_modifier(hero,"taken")==0,"blood guard cannot protect healthy actors")
 hero.hp=int(hero.max_hp/2)
 check(b.relic_modifier(hero,"taken")==-2,"blood guard activates only at half health or below")
 var hp=hero.hp;b.deal_damage(enemy,hero,10,false)
 check(hp-hero.hp==9,"blood four-piece reduces real damage after its armor drawback")
 hp=hero.hp;b.lose_hp(hero,2)
 check(hp-hero.hp==2,"blood guard never refunds explicit relic self-costs")
 var Campaign=load("res://game/campaign.gd")
 var c=Campaign.new()
 var legacy=c.to_data();legacy.version=8;legacy.phase="reward"
 legacy.choices=[Campaign.REWARDS.filter(func(reward):return reward.id=="command_1")[0].duplicate(true),Campaign.REWARDS[-1].duplicate(true),Campaign.REWARDS[-2].duplicate(true)]
 legacy.choices[0].desc="旧版四件共鸣：全队行动点+1"
 check(Campaign.new().load_data(legacy),"version8 pending thematic rewards migrate after resonance rebalance")
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
