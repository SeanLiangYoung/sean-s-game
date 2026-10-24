extends RefCounted
const Campaign=preload("res://game/campaign.gd")
const Combat=preload("res://tools/relic_mix_simulation.gd")
const Jobs=preload("res://game/professions.gd")
const Relic=preload("res://game/relics.gd")
const PROFILES={"balanced":["hero","blade","ranger","medic","engineer"],"guard":["hero","blade","ranger","medic","warden"],"support":["hero","ranger","medic","engineer","warden"],"assault":["hero","blade","ranger","engineer","warden"]}
const REGIONS=["border","wood","waste","frost","marsh"]
const WEIGHTS={"damage":1.4,"attack_power":0.9,"skill_power":1.0,"armor":2.5,"taken":-2.8,"speed":1.2,"range":3.0,"max_ap":12.0,"first_damage":0.8,"marked_damage":0.9,"shield_power":0.4,"turn_shield":0.8,"shield_damage":0.6,"shield_taken":-0.7,"low_hp_damage":0.5,"low_hp_taken":-2.0,"execute_damage":0.6,"high_mp_damage":0.65,"low_mp_damage":0.65,"trap_power":0.3,"heal":0.5,"heal_mp":-1.2,"healing_pct":0.08,"turn_heal":1.2,"turn_mp":1.6,"rest_hp":80.0,"rest_mp":100.0,"lifesteal":35.0,"kill_mp":0.8,"kill_ap":5.0,"kill_heal":0.5,"isolated_damage":0.6,"ranged_damage":0.8,"mark_power":0.7,"mana_power":0.7}
class MemoryCampaign:
 extends Campaign
 func save_game() -> bool:return true
 func sync_achievements():pass
var combat=Combat.new()
var errors: Array=[]
func create(captain: String,seed_value: int):
 var c=MemoryCampaign.new("user://fresh-study-only.json")
 c.rng.seed=seed_value
 assert(c.select_captain(captain))
 return c
func deployed(c,profile: String) -> Array:
 var chosen=[]
 for id in PROFILES[profile]:
  if c.roster.any(func(unit):return unit.id==id and unit.hp>0):chosen.append(id)
 # Recruits and reserves fill casualties; no actor is injected for a missing role.
 var reserves=c.roster.filter(func(unit):return unit.hp>0 and unit.id not in chosen)
 reserves.sort_custom(func(a,b):return float(a.hp)/a.max_hp>float(b.hp)/b.max_hp if a.hp*b.max_hp!=b.hp*a.max_hp else a.id<b.id)
 for unit in reserves:
  if chosen.size()>=5:break
  chosen.append(unit.id)
 return chosen
func gear_score(item: Dictionary,unit: Dictionary) -> float:
 if item.slot=="mainhand":
  var native={"hero":"sword","blade":"dagger","ranger":"bow","medic":"staff","engineer":"crossbow","warden":"sword"}[unit.profession]
  return float(item.power)+float(item.range)+(2.0 if item.kind==native else 0.0)
 return float(item.armor)*2.5
func equip(c,profile: String):
 var priority=deployed(c,profile)
 for unit in c.roster:
  if unit.id not in priority:priority.append(unit.id)
 for unit in c.roster:
  for slot in Jobs.SLOTS:c.unequip_item(unit.id,slot)
 for id in priority:
  var matches=c.roster.filter(func(unit):return unit.id==id and unit.hp>0)
  if matches.is_empty():continue
  var unit=matches[0]
  for slot in Jobs.SLOTS:
   var best=-1;var score=-1.0
   for i in c.equipment.size():
    var entry=c.equipment[i];var item=Jobs.ITEMS[entry.id]
    if entry.owner!="" or item.slot!=slot:continue
    var value=gear_score(item,unit)
    if value>score:score=value;best=i
   if best>=0 and not c.equip_item(best,id):errors.append("equip rejected")
func plan(unit: Dictionary) -> Array:
 var job=unit.profession
 if job=="hero":
  if unit.character_id=="wen":return [["strike",2],["hero_heal",1],["hero_heal",2],["hero_rally",1],["hero_burst",1],["hero_burst",2],["hero_sunder",1],["strike",3]]
  if unit.character_id=="lu":return [["strike",2],["mark",1],["hero_heal",1],["hero_burst",1],["hero_burst",2],["hero_sunder",1],["hero_heal",2],["hero_rally",1],["strike",3]]
  return [["strike",2],["hero_burst",1],["hero_heal",1],["hero_burst",2],["hero_sunder",1],["hero_heal",2],["hero_rally",1],["hero_judgment",1],["strike",3]]
 var orders={"blade":[["dash",2],["execute",1],["blade_sweep",1],["execute",2],["blade_hunt",1],["blade_sweep",2],["blade_drain",1],["dash",3]],"ranger":[["mark",2],["sniper",1],["ranger_volley",1],["sniper",2],["ranger_pin",1],["ranger_volley",2],["ranger_expose",1],["mark",3]],"medic":[["heal",2],["cleanse",1],["medic_mend",1],["medic_mend",2],["medic_channel",1],["cleanse",2],["medic_barrier",1],["heal",3]],"engineer":[["trap",2],["bomb",1],["engineer_shot",1],["engineer_shot",2],["engineer_breaker",1],["engineer_pulse",1],["bomb",2],["engineer_snare",1]],"warden":[["guard",2],["bash",1],["warden_ward",1],["warden_ward",2],["warden_rescue",1],["warden_rebuke",1],["bash",2],["warden_fortify",1]]}
 return orders[job]
func train(c,ledger: Array):
 for unit in c.roster:
  if unit.hp<=0:continue
  var completed=true
  for goal in plan(unit):
   while Jobs.skill_rank(unit,goal[0])<goal[1]:
    if Jobs.training_reason(unit,goal[0])!="":break
    var before=unit.xp;var cost=Jobs.skill_cost(unit,goal[0])
    if not c.train_skill(unit.id,goal[0]):errors.append("funded training rejected");return
    ledger.append({"actor":unit.character_id,"skill":goal[0],"rank":Jobs.skill_rank(unit,goal[0]),"cost":cost,"xp_before":before,"xp_after":unit.xp,"region":c.route.region,"node":c.route.current})
   if Jobs.skill_rank(unit,goal[0])<goal[1]:completed=false;break
  if not completed:continue
  for id in Jobs.JOBS[unit.profession].skills:
   while Jobs.skill_rank(unit,id)<3:
    if Jobs.training_reason(unit,id)!="":break
    var before=unit.xp;var cost=Jobs.skill_cost(unit,id)
    if not c.train_skill(unit.id,id):errors.append("funded late training rejected");return
    ledger.append({"actor":unit.character_id,"skill":id,"rank":Jobs.skill_rank(unit,id),"cost":cost,"xp_before":before,"xp_after":unit.xp,"region":c.route.region,"node":c.route.current})
func weight(key: String,unit: Dictionary,mods: Dictionary) -> float:
 var value=float(WEIGHTS.get(key,0.0))
 if key in ["heal","heal_mp"] and unit.profession not in ["medic","hero","engineer","warden"]:value*=0.2
 if key=="trap_power" and unit.profession!="engineer" and Jobs.skill_rank(unit,"trap")==0:value=0.0
 if key in ["ranged_damage","range"] and unit.range<3:value*=0.5
 if key in ["shield_damage","shield_power","shield_taken"] and not mods.has("turn_shield") and unit.profession not in ["medic","warden","hero"]:value*=0.4
 return value
func effective_mods(unit: Dictionary,entries: Array) -> Dictionary:
 var mods={};var unique=[];var seen=[]
 for entry in entries:
  if entry.id in seen or entry.remaining==0:continue
  seen.append(entry.id);unique.append(entry)
  for key in Relic.definition(entry).mods:mods[key]=float(mods.get(key,0.0))+float(Relic.definition(entry).mods[key])
 var counts=Relic.resonance_counts(unique)
 for family in counts:
  for tier in ["two","four"]:
   if counts[family]<(2 if tier=="two" else 4):continue
   for key in Relic.Expansion.SETS[family][tier]:mods[key]=float(mods.get(key,0.0))+float(Relic.Expansion.SETS[family][tier][key])
 if mods.has("max_ap"):mods.max_ap=minf(2.0,mods.max_ap)
 if mods.has("kill_ap"):mods.kill_ap=minf(1.0,mods.kill_ap)
 if mods.has("healing_pct"):mods.healing_pct=maxf(-100.0,mods.healing_pct)
 return mods
func build_value(c,entries: Array,party: Array) -> float:
 var value=0.0
 for id in party:
  var unit=c.roster.filter(func(actor):return actor.id==id)[0]
  var applicable=entries.filter(func(entry):return Relic.definition(entry).scope=="team" or entry.owner==id)
  var mods=effective_mods(unit,applicable)
  for entry in applicable:
   var d=Relic.definition(entry)
   var trigger_values={"echo":4.0,"candle":12.0 if id=="hero" else 5.0,"chalice":4.0,"fang":6.0,"shell":12.0}
   var wear=1.0 if d.uses==0 else clampf(float(entry.remaining)/float(d.uses),0.0,1.0)
   value+=float(trigger_values.get(entry.id,0.0))*wear/maxi(1,party.size())
  for key in mods:value+=float(mods[key])*weight(key,unit,mods)/maxi(1,party.size())
 return value
func relic_offer(c,id: String,profile: String) -> Dictionary:
 var party=deployed(c,profile);var held=c.relics+c.collection
 var base=build_value(c,held,party)
 var best={"score":-999.0,"owner":""}
 var owners=[""] if Relic.definition(id).scope=="team" else party
 for owner in owners:
  var next=held.filter(func(entry):return owner=="" or entry.owner!=owner)
  next.append(Relic.instance(id,999999,owner))
  var value=build_value(c,next,party)-base+(3.0 if id=="lens" else 0.0)
  if value>best.score:best={"score":value,"owner":owner}
 return best
func equipment_gain(c,item_id: String,profile: String) -> float:
 var value=0.0;var party=deployed(c,profile)
 for unit in c.roster:
  if unit.id not in party:continue
  var old=c.equipped_index(unit.id,Jobs.ITEMS[item_id].slot)
  var delta=gear_score(Jobs.ITEMS[item_id],unit)-(gear_score(Jobs.ITEMS[c.equipment[old].id],unit) if old>=0 else 0.0)
  value=maxf(value,delta/float(maxi(1,party.size())))
 return value
func reward(c,profile: String,strategy: String,denied: Array,trace: Array) -> bool:
 var best=-1;var best_value=-999.0;var owner="";var offered=[]
 for i in c.choices.size():
  var choice=c.choices[i];offered.append(choice.id)
  var value=-999.0;var bearer=""
  if choice.type=="relic":
   if choice.id in denied:continue
   var option=relic_offer(c,choice.id,profile);value=option.score+2.0;bearer=option.owner
   if strategy=="relic_focus":value+=12.0
  elif choice.id=="medicine":value=3.0+maxi(0,3-c.supplies)*4.0
  elif choice.id=="silver":value=4.0 if c.silver<70 else 2.0
  elif choice.type=="equipment":value=equipment_gain(c,choice.id,profile)
  if value>best_value:best=i;best_value=value;owner=bearer
 if best<0:return false
 var chosen=c.choices[best].duplicate(true)
 if not c.choose_reward(best,owner):return false
 trace.append({"offered":offered,"chosen":chosen.id,"type":chosen.type,"owner":owner,"score":best_value,"region":c.route.region,"node":c.route.current})
 return true
func learn_books_for(c,profile: String,ledger: Array):
 var party=deployed(c,profile)
 var attempts=c.books.size()
 for attempt in attempts:
  if c.books.is_empty():break
  var candidates=c.roster.filter(func(unit):return unit.id in party and c.books[0] not in unit.learned and Jobs.can_learn(unit,c.books[0]) and (c.books[0]!="fury" or unit.skill_ranks.keys().any(func(id):return Jobs.ALL_SKILLS[id].effect in ["damage","heal"])))
  if candidates.is_empty():break
  candidates.sort_custom(func(a,b):return a.skill_ranks.size()>b.skill_ranks.size() if a.skill_ranks.size()!=b.skill_ranks.size() else a.id<b.id)
  var book=c.books[0]
  if c.learn_book(0,candidates[0].id):ledger.append({"actor":candidates[0].character_id,"book":book})
func shopping(c,profile: String,strategy: String,denied: Array,trace: Array):
 for attempt in 4:
  var best="";var best_score=0.0;var owner=""
  for id in c.shop_inventory():
   if c.route.current+":"+id in c.purchases or c.GOODS[id].price>c.silver:continue
   var value=0.0;var bearer=""
   if Relic.CATALOG.has(id):
    if id in denied or id in c.active_relics():continue
    var offer=relic_offer(c,id,profile);value=offer.score+(3.0 if strategy=="relic_focus" else 0.0);bearer=offer.owner
   elif id in ["fury","focus"]:
    if not c.roster.any(func(unit):return unit.id in deployed(c,profile) and id not in unit.learned and (id!="fury" or unit.skill_ranks.keys().any(func(skill):return Jobs.ALL_SKILLS[skill].effect in ["damage","heal"]))):continue
    value=3.0 if id=="fury" else 2.0
   elif Jobs.ITEMS.has(id):value=equipment_gain(c,id,profile)
   var score=value/float(c.GOODS[id].price)
   if score>best_score:best_score=score;best=id;owner=bearer
  if best=="" or best_score<0.035:break
  var before=c.silver
  if not c.buy(best,owner):errors.append("affordable purchase rejected");break
  trace.append({"id":best,"owner":owner,"price":before-c.silver,"silver_after":c.silver,"region":c.route.region,"node":c.route.current})
  equip(c,profile)
func supply(c,trace: Array,profile: String="balanced"):
 while c.supplies>0 and c.phase=="world":
  var active=c.roster.filter(func(unit):return unit.id in deployed(c,profile))
  var hero=active.filter(func(unit):return unit.id=="hero")
  var wounded=active.filter(func(unit):return unit.hp*100<unit.max_hp*65 or unit.mp*100<unit.max_mp*35).size()
  var critical=active.any(func(unit):return unit.hp*100<unit.max_hp*30)
  if not critical and wounded<2 and (hero.is_empty() or hero[0].hp*100>=hero[0].max_hp*75):break
  var before=c.supplies
  if not c.use_supply():break
  trace.append({"node":c.route.current,"used":before-c.supplies,"remaining":c.supplies})
func battle_step(c,b,trace: Array) -> bool:
 var actor=b.active()
 if actor.side==0 and c.supplies>0 and actor.ap>=2 and actor.cell not in b.boss_warnings():
  var critical=b.actors.filter(func(unit):return unit.side==0 and unit.hp>0 and unit.hp*100<unit.max_hp*(40 if unit.id=="hero" else 25))
  critical.sort_custom(func(a,d):return a.id=="hero" if (a.id=="hero")!=(d.id=="hero") else a.hp*d.max_hp<d.hp*a.max_hp)
  for target in critical:
   var can_heal=["heal","medic_mend","medic_barrier","hero_heal","engineer_pulse","warden_rescue"].any(func(skill):return b.can_cast(skill,target.id))
   if not can_heal and b.use_medicine(target.id):
    c.supplies-=1
    trace.append({"node":c.route.current,"region":c.route.region,"in_battle":true,"actor":actor.id,"target":target.id,"used":1,"remaining":c.supplies})
    return true
 return combat.step(b)
func retention(c,profile: String) -> Array:
 var party=deployed(c,profile);var choices=[[]]
 for i in c.relics.size():
  choices.append([i])
  for j in range(i+1,c.relics.size()):choices.append([i,j])
 var best=[];var score=-INF
 for indices in choices:
  var held=c.collection.duplicate(true)
  for index in indices:held.append(c.relics[index])
  var value=build_value(c,held,party)+float(c.relics.size()-indices.size())*0.7
  if value>score:score=value;best=indices
 return best
func select_node(c,profile: String,strategy: String) -> Dictionary:
 var available=c.route.available();var best={};var value=-999.0
 for id in available:
  var node=c.route.node(id);var score=0.0
  match node.kind:
   "battle":score=30.0 if node.depth==0 or node.threat=="boss" else (22.0 if strategy=="relic_focus" else (20.0 if resonance(c,profile).count<2 else 16.0))
   "supply":score=24.0 if c.supplies<3 else 10.0
   "event":score=18.0
   "shop":score=23.0 if c.silver>=60 else 5.0
   "hire":score=25.0 if c.roster.filter(func(unit):return unit.hp>0).size()<5 and c.silver>=55 else 4.0
   "extract":score=50.0
  if score>value:value=score;best=node
 return best
func resonance(c,profile: String) -> Dictionary:
 var best={"count":0,"family":""};var paired=0
 for id in deployed(c,profile):
  var applicable=(c.relics+c.collection).filter(func(entry):return Relic.definition(entry).scope=="team" or entry.owner==id)
  var counts=Relic.resonance_counts(applicable)
  if counts.values().filter(func(count):return count>=2).size()>=2:paired=1
  for family in counts:
   if counts[family]>best.count:best={"count":counts[family],"family":family}
 best["mixed_two_two"]=bool(paired)
 return best
func run(captain: String,profile: String,strategy: String,region: String,seed_value: int,denied: Array=[],whole_campaign: bool=false) -> Dictionary:
 errors=[]
 var c=create(captain,seed_value)
 var result={"captain":captain,"profile":profile,"strategy":strategy,"region":region,"seed":seed_value,"denied":denied,"whole_campaign":whole_campaign,"cleared":false,"campaign_completed":false,"failure":"","battles":[],"rewards":[],"purchases":[],"training":[],"books":[],"supplies":[],"shop_offers":[],"recruits":[],"stages":[],"before_boss":[],"initial":{},"errors":[]}
 result.initial={"silver":c.silver,"supplies":c.supplies,"relics":c.relics.size(),"collection":c.collection.size(),"equipment":c.equipment.map(func(entry):return entry.id),"achievements":c.completed_difficulties.duplicate(),"ranks":c.roster.map(func(unit):return {"id":unit.character_id,"actor_id":unit.id,"xp":unit.xp,"skills":unit.skill_ranks.duplicate(true)})}
 equip(c,profile)
 var regions=["border","wood","waste","frost","marsh","ruins"] if whole_campaign else [region]
 for area in regions:
  if not c.start_region(area):result.failure="region rejected";break
  for depth in range(c.route.nodes[-1].depth+1):
   var node=select_node(c,profile,strategy)
   if node.is_empty() or not c.enter_route(node.id):result.failure="route rejected";break
   if node.kind=="shop":
    var stock=c.shop_inventory()
    result.shop_offers.append({"node":node.id,"region":area,"silver":c.silver,"stock":stock,"affordable":stock.filter(func(id):return c.GOODS[id].price<=c.silver)})
    shopping(c,profile,strategy,denied,result.purchases)
   if node.kind=="hire" and c.roster.filter(func(unit):return unit.hp>0).size()<5:
    for i in c.recruit_candidates().size():
     if c.can_hire(i):
      var before=c.silver
      if c.hire(i):result.recruits.append({"id":c.roster[-1].character_id,"price":before-c.silver})
      break
   learn_books_for(c,profile,result.books);train(c,result.training);equip(c,profile);supply(c,result.supplies,profile)
   if node.kind=="battle":
    var build=resonance(c,profile)
    if node.threat=="boss":result.before_boss.append({"region":area,"build":build.duplicate(true),"relics":c.active_relics(),"supplies":c.supplies,"training_count":result.training.size()})
    var ids=deployed(c,profile);var b=c.make_battle(ids,node.encounter)
    if b==null:result.failure="deployment rejected";break
    var steps=0
    while b.outcome=="" and steps<600:
     if not battle_step(c,b,result.supplies):errors.append("invalid combat action");break
     steps+=1
    if b.outcome=="":result.failure="step limit";break
    var xp_before={}
    for unit in c.roster:xp_before[unit.id]=unit.xp
    if not c.resolve_battle(b):result.failure="settlement rejected";break
    var earned={}
    for unit in c.roster:earned[unit.character_id]=unit.xp-int(xp_before.get(unit.id,unit.xp))
    result.battles.append({"region":area,"depth":depth,"threat":node.threat,"outcome":b.outcome,"rounds":b.round_no,"steps":steps,"build":build,"relics":b.relic_state.map(func(entry):return entry.id),"earned_xp":earned,"alive":c.roster.filter(func(unit):return unit.hp>0).map(func(unit):return unit.character_id),"deployed":ids,"battle_survivors":b.actors.filter(func(unit):return unit.side==0 and unit.hp>0).map(func(unit):return unit.id)})
    if b.outcome!="victory":result.failure=b.outcome;break
    if not reward(c,profile,strategy,denied,result.rewards):result.failure="reward rejected";break
    train(c,result.training);equip(c,profile);supply(c,result.supplies,profile)
   result.stages.append({"region":area,"depth":depth,"kind":node.kind,"build":resonance(c,profile),"relics":c.active_relics(),"silver":c.silver,"supplies":c.supplies})
   if node.kind=="extract":
    var keep=retention(c,profile)
    if not c.extract(keep):result.failure="extraction rejected"
  if result.failure!="":break
  if c.phase!="camp":result.failure="route unfinished";break
 result.cleared=result.failure=="" and c.phase=="camp"
 result.campaign_completed=c.campaign_completed()
 result.final={"silver":c.silver,"supplies":c.supplies,"collection":c.collection.map(func(entry):return entry.id),"alive":c.roster.filter(func(unit):return unit.hp>0).map(func(unit):return unit.character_id)}
 result.errors=errors.duplicate()
 return result
