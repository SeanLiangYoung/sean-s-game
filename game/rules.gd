extends RefCounted
# Deterministic tactical state; no scene or rendering dependency.
const Talents=preload("res://game/talents.gd")
const Battlefield=preload("res://game/battlefield.gd")
const EnemyAI=preload("res://game/enemy_ai.gd")
const EnemySkills=preload("res://game/enemy_skills.gd")
const Regions=preload("res://game/regions.gd")
const Regional=preload("res://game/region_combat.gd")
const Relic=preload("res://game/relics.gd")
const Professions=preload("res://game/professions.gd")
const DIRS = [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,1),Vector2i(-1,0),Vector2i(0,-1),Vector2i(1,-1)]
var actors: Array = []
var order: Array = []
var order_index = 0
var round_no = 1
var round_limit = 10
var radius = 4
var outcome = ""
var events: Array = []
var obstacles: Array = []
var bonuses: Array = []
var relic_state: Array = []
var traps: Array = []
var aura = ""
var biome=""
var boss_intents: Array=[]
var boss_cues: Array=[]
var last_enemy_decision: Dictionary={}

func default_party() -> Array:
 var rows = [
  ["hero","沈烬","团长",80,24,12,19,1],
  ["blade","岚","游剑客",58,20,15,22,1],
  ["ranger","鸦","荒原猎手",52,24,14,17,3],
  ["medic","白芷","行医者",54,40,11,12,2],
  ["engineer","铁九","遗械师",68,28,10,18,2],
  ["warden","奥伦","盾卫",96,16,8,17,1]]
 var result = []
 for row in rows:
  result.append({"id":row[0],"name":row[1],"role":row[2],"max_hp":row[3],"hp":row[3],"max_mp":row[4],"mp":row[4],"speed":row[5],"power":row[6],"range":row[7],"side":0,"ap":4,"cell":Vector2i.ZERO})
 for unit in result:Professions.normalize(unit)
 return result

func hex_distance(a: Vector2i,b: Vector2i) -> int:
 var d = a-b
 return maxi(absi(d.x),maxi(absi(d.y),absi(d.x+d.y)))

func cells() -> Array:
 var result = []
 for q in range(-radius,radius+1):
  for r in range(-radius,radius+1):
   var c = Vector2i(q,r)
   if hex_distance(c,Vector2i.ZERO) <= radius:result.append(c)
 return result

func start_battle(party: Array, difficulty: int, relic_bonuses: Array = [],encounter_config: Dictionary={}):
 actors = []
 var generated_encounter=encounter_config.size()>(1 if encounter_config.has("overall_difficulty") else 0)
 biome=encounter_config.get("biome","")
 boss_intents=[]
 boss_cues=[]
 last_enemy_decision={}
 traps=[]
 aura=""
 bonuses = []
 relic_state=[]
 var relic_uid=1
 for entry in relic_bonuses:
  if not Relic.CATALOG.has(Relic.id_of(entry)):continue
  relic_state.append(Relic.instance(entry,relic_uid) if entry is String else entry.duplicate(true))
  relic_uid+=1
  bonuses.append(Relic.id_of(entry))
 events = []
 outcome = ""
 radius = 4
 round_no = 1
 order_index = 0
 obstacles = [Vector2i(0,-1),Vector2i(1,1),Vector2i(-1,2)]
 var starts = [Vector2i(-3,0),Vector2i(-3,1),Vector2i(-2,-1),Vector2i(-2,0),Vector2i(-2,1)]
 for i in range(mini(party.size(),5)):
  var u = party[i].duplicate(true)
  if u.hp <= 0:continue
  u.cell = starts[i]
  u.side = 0
  u.max_ap=u.get("max_ap",4)
  u.armor=u.get("armor",0)
  u.statuses={}
  Talents.reset(u)
  u.used_skills=[]
  u.kill_refunded=false
  u.kills=0
  u.ap=u.max_ap
  actors.append(u)
 var battle_rng=RandomNumberGenerator.new()
 battle_rng.seed=int(encounter_config.get("seed",0))
 difficulty=clampi(difficulty,0,2)
 var enemy_starts = [Vector2i(2,0),Vector2i(2,-1),Vector2i(1,2),Vector2i(3,-2),Vector2i(0,3)]
 var enemy_count=3+difficulty
 if generated_encounter:enemy_count=4 if encounter_config.get("threat")=="boss" else mini(5,3+difficulty)
 for i in range(enemy_count):
  var ranged = i%3 == 2
  var hp = 36+difficulty*24
  actors.append({"id":"enemy%d"%i,"name":"灰巢弩手" if ranged else "灰巢掠夺者","role":"敌人","max_hp":hp,"hp":hp,"max_mp":0,"mp":0,"speed":9+i,"power":10+difficulty*3,"range":3 if ranged else 1,"side":1,"ap":4,"cell":enemy_starts[i]})
 if generated_encounter:
  var biome=encounter_config.get("biome","border")
  var names={"border":["灰巢刀客","灰巢弩手","灰潮督军"],"wood":["林影伏兵","林间游猎者","古林守望"],"waste":["赤砂劫掠者","砂丘弩卫","赤砂军阀"],"frost":["霜脊卫士","雪隘射手","霜脊统领"],"marsh":["沼泽潜猎者","雾行弓手","暮雾猎王"],"ruins":["遗城卫士","遗械射手","星陨监守"]}.get(biome,["掠夺者","弩手","督军"])
  var ranged_limit=2 if biome in ["wood","marsh"] else 1
  var enemy_index=0
  for u in actors:
   if u.side!=1:continue
   var ranged=enemy_index<ranged_limit
   var bruiser=enemy_index==enemy_count-1 and not ranged
   u.name=names[1] if ranged else names[0]
   u.max_hp=34+difficulty*12+battle_rng.randi_range(0,8)+(8 if bruiser else 0)
   u.power=9+difficulty*2+(2 if bruiser else 0)
   u.armor=2 if biome in ["frost","ruins"] or bruiser else 0
   u.range=3 if ranged else 1
   u.speed=8+battle_rng.randi_range(0,3)
   if encounter_config.get("threat")=="boss" and enemy_index==enemy_count-1:
    u.name=names[2];u.max_hp+=48;u.power+=2;u.armor+=1;u.speed=9
   elif encounter_config.get("threat")=="elite" and enemy_index==enemy_count-1:
    u.name="精英 · "+u.name;u.max_hp+=20;u.power+=1
   u.hp=u.max_hp
   Regional.setup(self,u,biome,encounter_config.get("threat")=="boss" and enemy_index==enemy_count-1)
   if encounter_config.get("threat")=="elite" and enemy_index==enemy_count-1:u.name="精英 · "+u.name
   enemy_index+=1
  Battlefield.generate(self,encounter_config)
  events.append("战场："+biome+" · "+encounter_config.get("threat","normal"))
 # Campaign progression stacks with the route's existing encounter tier.
 var campaign_rank=clampi(int(encounter_config.get("campaign_difficulty",1)),1,6)-1
 for u in actors:
  if u.side==1:
   u.max_hp=roundi(u.max_hp*(1.0+0.18*campaign_rank))
   u.hp=u.max_hp
   u.power=roundi(u.power*(1.0+0.10*campaign_rank))
   u.base_enemy_power=u.power
 for actor in actors:
  if not actor.has("statuses"):actor.statuses={}
 EnemySkills.empower(self,encounter_config,difficulty)
 # Each step scales the previous difficulty after regional growth and affixes.
 # Hard, nightmare and the final difficulty apply one, two and three steps respectively.
 var overall_difficulty=int(encounter_config.get("overall_difficulty",0))
 if overall_difficulty in [1,2,3]:
  for step in range(overall_difficulty):
   var hp_multiplier=1.50 if step==2 else 1.25
   var power_multiplier=1.25 if step==2 else 1.15
   for u in actors:
    if u.side!=1:continue
    u.max_hp=roundi(u.max_hp*hp_multiplier)
    u.hp=u.max_hp
    u.power=roundi(u.power*power_multiplier)
    u.base_enemy_power=roundi(u.base_enemy_power*power_multiplier)
 for u in actors:
  if u.id=="hero" and u.side==0 and u.hp>0:aura=""
 for u in actors:
  if u.side!=0:continue
  if aura=="dagger":u.speed+=2
  if aura=="bow":u.range+=1
  if aura=="crossbow":u.armor+=2
 refresh_relic_stats()
 rebuild_order()
 events.append("遗物构筑 · 团队效果与个人触发已生效")
 events.append("遭遇开始。第 3 回合结束时首次收缩。")

func rebuild_order():
 order = []
 for i in range(actors.size()):
  if actors[i].hp > 0:order.append(i)
 order.sort_custom(func(a,b):return actors[a].speed > actors[b].speed if actors[a].speed != actors[b].speed else a < b)
 order_index = 0
 if not order.is_empty():begin_turn(actors[order[0]])

func active() -> Dictionary:
 if order.is_empty():return {}
 return actors[order[mini(order_index,order.size()-1)]]

func unit_at(cell: Vector2i) -> Dictionary:
 for a in actors:
  if a.hp > 0 and a.cell == cell:return a
 return {}

func is_free(cell: Vector2i) -> bool:
 return hex_distance(cell,Vector2i.ZERO)<=radius and cell not in obstacles and unit_at(cell).is_empty()

func path_to(start: Vector2i, target: Vector2i) -> Array:
 if not is_free(target):return []
 var queue = [start]
 var previous = {start:start}
 var cursor = 0
 while cursor < queue.size():
  var c = queue[cursor]
  cursor += 1
  if c == target:break
  for dir in DIRS:
   var n = c+dir
   if not previous.has(n) and is_free(n):
    previous[n] = c
    queue.append(n)
 if not previous.has(target):return []
 var path = []
 var at = target
 while at != start:
  path.push_front(at)
  at = previous[at]
 return path

func can_act() -> bool:
 return outcome == "" and not active().is_empty() and active().hp > 0

func move_to(cell: Vector2i) -> bool:
 if not can_act():return false
 var a = active()
 var path = path_to(a.cell,cell)
 if path.is_empty() or movement_cost(a,path)>a.ap:return false
 var traversed=0
 if a.get("statuses",{}).has("snare"):
  a.ap-=1
  a.statuses.erase("snare")
 for step in path:
  if Talents.state(a).free_step:Talents.state(a).free_step=false
  else:a.ap-=1
  Talents.state(a).moved=true
  a.cell=step
  traversed+=1
  if trigger_trap(a):break
 events.append("%s 移动 %d 格"%[a.name,traversed])
 after_action()
 return true

func find_actor(id: String) -> Dictionary:
 for a in actors:
  if a.id == id:return a
 return {}

func attack(id: String) -> bool:
 if not can_act():return false
 var a = active()
 var target = find_actor(id)
 if target.is_empty() or target.hp <= 0 or target.side == a.side or a.ap < 2:return false
 if hex_distance(a.cell,target.cell)>a.range:return false
 a.ap -= 2
 var amount=a.power+int(relic_modifier(a,"attack_power"))
 if Professions.job_id(a)=="ranger" and hex_distance(a.cell,target.cell)>=3:amount+=3
 var before=target.hp
 amount+=Regional.attack_bonus(a,target)
 deal_damage(a,target,amount)
 Regional.after_attack(self,a,target,maxi(0,before-target.hp))
 after_action()
 return true

func available_skills(unit: Dictionary) -> Array:
 return Professions.skills_for(unit)

func default_skill(unit: Dictionary) -> String:
 var skills=available_skills(unit)
 return skills[0] if not skills.is_empty() else ""

func skill_range(unit: Dictionary,skill_id: String) -> int:
 return Talents.skill_range(unit,skill_id,Professions.ALL_SKILLS[skill_id].range)

func skill_mana_cost(unit: Dictionary,skill_id: String,target=null) -> int:
 var discount=0
 if target is String:
  discount=Talents.discount(unit,skill_id,find_actor(target))
 elif target==null and Talents.is_character(unit,"tang"):
  for enemy in actors:
   if enemy.hp>0 and enemy.side!=unit.side and hex_distance(unit.cell,enemy.cell)<=skill_range(unit,skill_id):discount=maxi(discount,Talents.discount(unit,skill_id,enemy))
 return maxi(1,Professions.ALL_SKILLS[skill_id].mp-discount)+skill_relic_cost(unit,skill_id)

func skill_ready(skill_id: String,target=null) -> bool:
 if not can_act() or active().side!=0 or skill_id not in available_skills(active()):return false
 var a=active()
 var skill=Professions.ALL_SKILLS[skill_id]
 return a.ap>=skill.ap and a.mp>=skill_mana_cost(a,skill_id,target) and skill_id not in a.get("used_skills",[])

func dash_landing(a: Dictionary,t: Dictionary):
 if hex_distance(a.cell,t.cell)==1:return a.cell
 var options=[]
 for dir in DIRS:
  var cell=t.cell+dir
  if not is_free(cell):continue
  var route=path_to(a.cell,cell)
  if not route.is_empty() and route.size()<=2:options.append(cell)
 options.sort_custom(func(x,y):
  var dx=hex_distance(a.cell,x);var dy=hex_distance(a.cell,y)
  if dx!=dy:return dx<dy
  if x.x!=y.x:return x.x<y.x
  return x.y<y.y)
 return options[0] if not options.is_empty() else null

func can_cast(skill_id: String,target) -> bool:
 if not skill_ready(skill_id,target):return false
 var a=active()
 var skill=Professions.ALL_SKILLS[skill_id]
 if skill.target=="cell":return target is Vector2i and is_free(target) and hex_distance(a.cell,target)<=skill_range(a,skill_id)
 if not target is String:return false
 var t=find_actor(target)
 if t.is_empty() or t.hp<=0 or hex_distance(a.cell,t.cell)>skill_range(a,skill_id):return false
 if skill.target=="enemy" and t.side==a.side:return false
 if skill.target in ["ally","other_ally"] and t.side!=a.side:return false
 if skill.target=="other_ally" and t.id==a.id:return false
 if skill.get("base",skill_id)=="dash" and dash_landing(a,t)==null:return false
 return true

func cast(target,skill_id: String="") -> bool:
 if skill_id=="" and can_act():skill_id=default_skill(active())
 if not can_cast(skill_id,target):return false
 var a=active()
 var skill=Professions.ALL_SKILLS[skill_id]
 var effect_id=skill.get("base",skill_id)
 var rank_bonus=Professions.skill_bonus(a,skill_id)
 var talent_target=find_actor(target) if target is String else {}
 var talent_before=Talents.context(a,talent_target)
 a.ap-=skill.ap
 a.mp-=skill_mana_cost(a,skill_id,target)
 a.used_skills.append(skill_id)
 events.append("%s 施放 %s"%[a.name,skill.name])
 if effect_id=="trap":
  traps=traps.filter(func(trap):return trap.source!=a.id)
  traps.append({"source":a.id,"side":a.side,"cell":target,"damage":(26 if Professions.job_id(a)=="engineer" else 20)+rank_bonus+skill.get("trap_bonus",0)+int(combat_modifier(a,"trap_power"))+(6 if Talents.is_character(a,"li") else 0)})
 else:
  var t=find_actor(target)
  match effect_id:
   "heal","barrier":
    var amount=(18 if effect_id=="barrier" else 26)+rank_bonus+a.get("heal_bonus",0)+(6 if Professions.job_id(a)=="medic" else 0)+(8 if "fury" in a.get("learned",[]) else 0)
    amount+=int(relic_modifier(a,"heal"))+Talents.heal_bonus(a,skill_id,talent_before)
    var gain=heal_unit(t,amount)
    if gain>0:consume_relic(a,"prism")
    if effect_id=="barrier":Talents.shield(self,t,a,10+rank_bonus+Talents.shield_bonus(a,skill_id,talent_before))
    events.append("%s 恢复 %d 生命"%[t.name,gain])
   "mana":
    var gain=mini(t.max_mp-t.mp,maxi(0,10+rank_bonus+int(combat_modifier(a,"mana_power"))))
    t.mp+=gain
    events.append("%s 恢复 %d 法力"%[t.name,gain])
   "mark":put_status(t,"mark",a.id,rank_bonus+skill.get("mark_bonus",0)+int(combat_modifier(a,"mark_power")))
   "cleanse":
    for harmful in ["mark","exposed","poison","chill","snare","stagger"]:t.statuses.erase(harmful)
    Talents.shield(self,t,a,10+rank_bonus+Talents.shield_bonus(a,skill_id,talent_before))
   "guard":put_status(t,"guard",a.id,rank_bonus+skill.get("guard_bonus",0))
   _:
    if effect_id=="dash":
     var destination=dash_landing(a,t)
     if destination!=a.cell:
      Talents.state(a).moved=true
      a.cell=destination
      trigger_trap(a)
    if a.hp>0:
     var extra={"strike":14,"dash":4,"execute":6,"sniper":10,"bomb":2,"bash":0,"sunder":6,"drain":4,"pin":2}.get(effect_id,0)
     extra+=int(combat_modifier(a,"skill_power"))
     if skill.get("armor_damage",false):extra+=maxi(0,a.get("armor",0))
     if t.get("statuses",{}).has("mark"):extra+=skill.get("marked_bonus",0)
     if effect_id=="execute" and t.hp*2<=t.max_hp:extra+=10
     var victims=[t]
     if effect_id=="bomb":victims=actors.filter(func(u):return u.hp>0 and u.side!=a.side and hex_distance(t.cell,u.cell)<=1)
     for victim in victims:
      if a.hp>0:
       var before=victim.hp
       deal_damage(a,victim,a.power+extra+rank_bonus+(8 if "fury" in a.get("learned",[]) else 0)+Talents.damage_bonus(a,skill_id,victim,talent_before))
       if effect_id=="drain" and a.hp>0:heal_unit(a,int(maxi(0,before-victim.hp)*(0.45 if Talents.is_character(a,"chi") else 0.3)))
       if victim.hp>0 and (effect_id=="sunder" or skill.get("expose",false)):put_status(victim,"exposed",a.id,rank_bonus)
     if a.hp>0 and t.hp>0 and has_relic(a,"echo") and a.mp>=3:
      a.mp-=3
      consume_relic(a,"echo")
      events.append("回响棱镜 · 追加伤害，消耗3法力")
      deal_damage(a,t,8,false)
     if effect_id in ["bash","pin"] and t.hp>0:put_status(t,"stagger",a.id)
 Talents.after_cast(self,a,skill_id,talent_target,talent_before)
 after_action()
 return true

func put_status(unit: Dictionary,kind: String,source_id: String,bonus: int=0):
 if not unit.has("statuses"):unit.statuses={}
 unit.statuses[kind]={"source":source_id,"bonus":bonus}

func clear_source_statuses(source_id: String):
 for unit in actors:
  for kind in unit.get("statuses",{}).keys():
   if kind not in ["stagger","poison","chill","snare"] and unit.statuses[kind].source==source_id:unit.statuses.erase(kind)

func clean_dead_statuses():
 boss_intents=boss_intents.filter(func(intent):return not find_actor(intent.source).is_empty() and find_actor(intent.source).hp>0)
 var hero=find_actor("hero")
 if aura!="" and (hero.is_empty() or hero.hp<=0):
  for ally in actors:
   if ally.side!=0:continue
   if aura=="dagger":ally.speed-=2
   if aura=="bow":ally.range-=1
   if aura=="crossbow":ally.armor-=2
  aura=""
 for unit in actors:
  if unit.hp<=0:
   clear_source_statuses(unit.id)
   unit.statuses={}

func begin_turn(unit: Dictionary):
 clean_dead_statuses()
 clear_source_statuses(unit.id)
 Talents.reset(unit)
 unit.used_skills=[]
 unit.kill_refunded=false
 unit.relic_hit_used=false
 unit.relic_kill_refunded=false
 var stagger=unit.get("statuses",{}).has("stagger")
 var chilled=unit.get("statuses",{}).has("chill")
 unit.ap=maxi(1,unit.get("max_ap",4)-(1 if stagger or chilled else 0))
 if stagger:unit.statuses.erase("stagger")
 if chilled:unit.statuses.erase("chill")
 Regional.turn_start(self,unit,stagger)
 if outcome!="":return
 if unit.side==0 and unit.hp>0:
  var recovered=heal_unit(unit,int(relic_modifier(unit,"turn_heal")))
  var mana=mini(unit.max_mp-unit.mp,maxi(0,int(relic_modifier(unit,"turn_mp"))))
  unit.mp+=mana
  var shield=relic_modifier(unit,"turn_shield")
  if shield>0:
   var bonus=int(shield)-10+int(combat_modifier(unit,"shield_power"))
   if not unit.statuses.has("shield") or int(unit.statuses.shield.get("bonus",0))<bonus:put_status(unit,"shield",unit.id,bonus)
  if recovered>0 or mana>0 or shield>0:events.append("遗物触发 · %s 回血%d / 回蓝%d%s"%[unit.name,recovered,mana," / 获得护盾" if shield>0 else ""])
 if aura=="staff" and unit.side==0 and unit.hp>0:
  var gain=heal_unit(unit,3)
  if gain>0:events.append("主角光环 · %s 恢复 %d 生命"%[unit.name,gain])

 if unit.get("statuses",{}).has("poison"):
  var poison=unit.statuses.poison
  var source=find_actor(poison.source)
  if not source.is_empty():deal_damage(source,unit,int(poison.get("bonus",3)),false)
  poison.ticks-=1
  if poison.ticks<=0:unit.statuses.erase("poison")
  check_outcome()
  if outcome!="":return
  if unit.hp<=0:
   if not active().is_empty() and active().id==unit.id:finish_turn()
   return

func lose_hp(unit: Dictionary,amount: int):
 amount=maxi(0,amount)
 if amount>0 and has_relic(unit,"shell"):
  amount=maxi(0,amount-10)
  consume_relic(unit,"shell")
 if amount>=unit.hp and unit.hp>0 and has_relic(unit,"candle"):
  amount=unit.hp-1
  unit.mp=0
  consume_relic(unit,"candle")
  events.append("续命烛芯 · 保留1生命，法力耗尽")
 unit.hp=maxi(0,unit.hp-amount)
 events.append("%s −%d 生命"%[unit.name,amount])
 Regional.update_phase(self,unit)

func deal_damage(source: Dictionary,target: Dictionary,amount: int,direct: bool=true):
 if target.hp<=0:return
 var life_before=target.hp
 var lifesteal=relic_modifier(source,"lifesteal") if direct and source.side==0 else 0.0
 var ice_shield=target.get("boss_passive","")=="coldheart" and target.get("statuses",{}).has("shield")
 var talent_hit=Talents.direct_hit(self,source,target) if direct else {"damage":0,"mana":0,"kill_mana":0}
 amount+=talent_hit.damage
 if direct:
  if target.get("statuses",{}).has("exposed"):amount+=4+int(target.statuses.exposed.bonus)
  if source.side==0:
   amount+=int(relic_modifier(source,"damage"))
   var triggered=0
   if source.hp*2<=source.max_hp:triggered+=int(relic_modifier(source,"low_hp_damage"))
   if target.hp*2<=target.max_hp:triggered+=int(relic_modifier(source,"execute_damage"))
   if source.max_mp>0:
    triggered+=int(relic_modifier(source,"high_mp_damage" if source.mp*2>=source.max_mp else "low_mp_damage"))
   if source.statuses.has("shield"):triggered+=int(relic_modifier(source,"shield_damage"))
   if hex_distance(source.cell,target.cell)>=3:triggered+=int(relic_modifier(source,"ranged_damage"))
   if not actors.any(func(a):return a.side==source.side and a.id!=source.id and a.hp>0 and hex_distance(a.cell,source.cell)<=1):triggered+=int(relic_modifier(source,"isolated_damage"))
   if not source.get("relic_hit_used",false):triggered+=int(relic_modifier(source,"first_damage"))
   source.relic_hit_used=true
   amount+=triggered
   if triggered!=0:events.append("遗物触发 · %s 条件伤害 %+d"%[source.name,triggered])
   if has_relic(source,"fang"):
    amount+=10
    consume_relic(source,"fang")
    lose_hp(source,2)
   if aura=="sword":amount+=2
  var marked=target.get("statuses",{}).get("mark",{})
  if not marked.is_empty():
   var marker=find_actor(marked.source)
   if not marker.is_empty() and marker.hp>0 and marker.side==source.side:amount+=5+int(marked.get("bonus",0))+int(relic_modifier(source,"marked_damage"))
 amount=maxi(1,amount-target.get("armor",0)-Regional.reduction(self,source,target,direct)+int(relic_modifier(target,"taken")))
 if target.get("statuses",{}).has("shield"):
  amount=maxi(0,amount-10-int(target.statuses.shield.get("bonus",0))+int(relic_modifier(target,"shield_taken")))
  target.statuses.erase("shield")
 var guard_data=target.get("statuses",{}).get("guard",{})
 if direct and not guard_data.is_empty():
  var protector=find_actor(guard_data.source)
  if not protector.is_empty() and protector.hp>0 and protector.id!=target.id and hex_distance(protector.cell,target.cell)<=2:
   var share=int(ceil(amount/2.0))
   amount-=share
   var reduced=share-int(guard_data.get("bonus",0))-protector.get("armor",0)+int(relic_modifier(protector,"taken"))-(3 if Professions.job_id(protector)=="warden" else 0)
   if share>0:reduced-=Talents.guard_reduction(self,protector)
   if protector.get("statuses",{}).has("shield"):
    reduced-=10+int(protector.statuses.shield.get("bonus",0));protector.statuses.erase("shield")
   lose_hp(protector,maxi(0,reduced))
 var was_alive=target.hp>0
 lose_hp(target,amount)
 if source.hp>0:source.mp=mini(source.max_mp,source.mp+talent_hit.mana+(talent_hit.kill_mana if target.hp<=0 else 0))
 if direct and source.hp>0 and source.side==0:
  heal_unit(source,int(maxi(0,life_before-target.hp)*lifesteal))
 if was_alive and target.hp<=0 and source.get("side",-1)==0 and target.side==1:
  if source.hp>0:source.mp=mini(source.max_mp,source.mp+int(combat_modifier(source,"kill_mp")))
  if source.hp>0 and source.hp<source.max_hp and has_relic(source,"chalice"):
   heal_unit(source,12)
   consume_relic(source,"chalice")
  if source.hp>0:
   var recovered=heal_unit(source,int(relic_modifier(source,"kill_heal")))
   if recovered>0:events.append("遗物触发 · 击杀回血%d"%recovered)
   if not source.get("relic_kill_refunded",false):
    var refund=int(relic_modifier(source,"kill_ap"))
    if refund>0:
     source.ap+=refund;source.relic_kill_refunded=true
     events.append("遗物触发 · 击杀恢复%d行动点"%refund)
  source.kills=int(source.get("kills",0))+1
  events.append("%s 击杀奖励 +15经验（胜利后结算）"%source.name)
 if target.hp<=0 and source.hp>0 and Professions.job_id(source)=="blade" and not source.get("kill_refunded",false):
  source.ap+=1;source.kill_refunded=true
  events.append("游剑客专精 · 击杀恢复1行动点")
 if ice_shield and direct and source.hp>0 and hex_distance(source.cell,target.cell)<=2:put_status(source,"snare",target.id)
 clean_dead_statuses()

func trigger_trap(unit: Dictionary) -> bool:
 for i in range(traps.size()):
  var trap=traps[i]
  if trap.cell!=unit.cell or trap.side==unit.side:continue
  traps.remove_at(i)
  var source=find_actor(trap.source)
  if not source.is_empty():
   deal_damage(source,unit,trap.damage,false)
   Talents.trap_trigger(self,source)
  events.append("机关触发 · %s 停止移动"%unit.name)
  return true
 return false

func aura_description() -> String:
 return "团队效果由遗物提供"

func status_text(unit: Dictionary) -> String:
 var names={"advance":"进军号令：下一名友军直接攻击+4，击杀回蓝3","mark":"被标记：受击+5","shield":"净护：下次减伤10","guard":"援护中","stagger":"下次行动点-1","poison":"中毒","chill":"寒冷：下次行动点-1","snare":"束缚：下次移动首格+1点","command":"号令：下次普攻+3"}
 var result=[]
 for kind in unit.get("statuses",{}):
  var bonus=int(unit.statuses[kind].get("bonus",0))
  if kind=="mark":result.append("被标记：受击+%d"%[5+bonus])
  elif kind=="shield":result.append("净护：下次减伤%d"%[10+bonus])
  elif kind=="exposed":result.append("破甲：直接受伤+%d"%[4+bonus])
  elif kind=="poison":result.append("中毒：%d次×%d基础伤害"%[unit.statuses.poison.get("ticks",2),bonus])
  elif kind=="guard":result.append("援护中 · 额外减伤%d"%bonus)
  else:result.append(names.get(kind,kind))
 return " · ".join(result)

func rest_amount(kind: String) -> int:
 var a = active()
 if a.is_empty() or a.ap <= 0:return 0
 var maximum = a.max_hp if kind == "hp" else a.max_mp
 var current = a.hp if kind == "hp" else a.mp
 var ratio = maxf(0.0,0.05+combat_modifier(a,"rest_"+kind))
 if "focus" in a.get("learned",[]):ratio+=0.02
 var amount=maxi(1,int(floor(maximum*a.ap*ratio)))
 if kind=="hp":amount=int(floor(amount*maxf(0.0,1.0+relic_modifier(a,"healing_pct")/100.0)))
 return mini(maximum-current,amount)

func rest(kind: String) -> bool:
 if not can_act() or kind not in ["hp","mp"]:return false
 var a = active()
 var gain = rest_amount(kind)
 a[kind] += gain
 if kind=="mp" and gain>0:consume_relic(a,"tide")
 a.ap = 0
 events.append("%s 休息：恢复 %d %s"%[a.name,gain,"生命" if kind=="hp" else "法力"])
 finish_turn()
 return true

func after_action():
 check_outcome()
 if outcome == "" and (active().ap <= 0 or active().hp<=0):finish_turn()

func check_outcome():
 clean_dead_statuses()
 if outcome != "":return
 var allies = 0
 var enemies = 0
 for a in actors:
  if a.id == "hero" and a.hp <= 0:
   outcome = "gameover"
   events.append("团长阵亡。行旅止于此。")
   return
  if a.hp > 0:
   if a.side == 0:allies += 1
   else:enemies += 1
 if allies == 0:outcome = "defeat"
 elif enemies == 0:outcome = "victory"

func finish_turn():
 if outcome != "":return
 if not active().is_empty():active().ap = 0
 order_index += 1
 while order_index<order.size() and actors[order[order_index]].hp <= 0:order_index += 1
 if order_index >= order.size():
  if round_no >= round_limit:
   for a in actors:
    if a.side == 0:a.hp = 0
   outcome = "defeat"
   for a in actors:
    if a.id == "hero":outcome = "gameover"
   events.append("期限已至。出战队伍全灭。")
   return
  if round_no in [3,5,7,9]:
   shrink()
   if outcome != "":return
  round_no += 1
  rebuild_order()
  events.append("第 %d 回合"%round_no)
 else:
  begin_turn(active())

func shrink():
 if not boss_intents.is_empty():events.append("灰潮打断首领蓄力，旧危险格已取消")
 boss_intents=[]
 radius = maxi(0,radius-1)
 events.append("灰潮收缩：安全半径 %d"%radius)
 var sequence = order.duplicate()
 for i in range(actors.size()):
  if i not in sequence:sequence.append(i)
 for i in sequence:
  var a = actors[i]
  if a.hp<=0 or hex_distance(a.cell,Vector2i.ZERO)<=radius:continue
  var destinations = cells().filter(func(c):return is_free(c))
  var origin = a.cell
  destinations.sort_custom(func(c,d):
   var dc = hex_distance(origin,c)
   var dd = hex_distance(origin,d)
   if dc != dd:return dc<dd
   if c.x != d.x:return c.x<d.x
   return c.y<d.y)
  if destinations.is_empty():
   a.hp = 0
   events.append("%s 无处撤离，阵亡"%a.name)
  else:
   a.cell = destinations[0]
   var damage = int(ceil(a.max_hp*0.2))+int(relic_modifier(a,"taken"))
   lose_hp(a,damage)
   events.append("%s 被灰潮推移，−%d 生命"%[a.name,damage])
 check_outcome()

func enemy_decision() -> Dictionary:
 return EnemyAI.decide(self)

func enemy_step():
 if not can_act() or active().side!=1:return
 var unit=active()
 var decision=enemy_decision()
 last_enemy_decision=decision.duplicate(true)
 events.append("敌方战术 · "+unit.name+"："+str(decision.get("reason","整队")))
 var accepted=false
 match decision.get("action",""):
  "attack":accepted=attack(decision.target)
  "skill":accepted=cast_enemy_skill(decision.skill,decision.get("target"))
  "move":accepted=move_to(decision.target)
  "rest":accepted=rest(decision.get("target","hp"))
 if not accepted:
  check_outcome()
  if outcome=="":finish_turn()

func use_medicine(id: String) -> bool:
 if not can_act() or active().side!=0 or active().ap<2:return false
 var a=active()
 var target=find_actor(id)
 if target.is_empty() or target.side!=0 or target.hp<=0:return false
 if hex_distance(a.cell,target.cell)>3:return false
 if target.hp==target.max_hp and target.mp==target.max_mp:return false
 a.ap-=2
 heal_unit(target,int(target.max_hp*0.3))
 target.mp=mini(target.max_mp,target.mp+int(target.max_mp*0.3))
 events.append("%s 为 %s 使用补给：恢复30%%生命与法力"%[a.name,target.name])
 after_action()
 return true

func end_action() -> bool:
 if not can_act() or active().side!=0:return false
 events.append("%s 结束行动"%active().name)
 finish_turn()
 return true

# Team duplicates share an effect but only one physical instance spends a charge.
func applicable_relics(unit: Dictionary) -> Array:
 if unit.get("side",-1)!=0:return []
 var result=[]
 var seen=[]
 for entry in relic_state:
  var d=Relic.definition(entry)
  if entry.remaining==0 or (d.scope=="personal" and entry.owner!=unit.id) or entry.id in seen:continue
  seen.append(entry.id)
  result.append(entry)
 return result

func combat_modifier(unit: Dictionary,key: String) -> float:
 return float(unit.get(key,0))+relic_modifier(unit,key)

func relic_modifier(unit: Dictionary,key: String) -> float:
 var value=0.0
 var entries=applicable_relics(unit)
 for entry in entries:
  var mods=Relic.definition(entry).mods
  var amount=float(mods.get(key,0))
  if key=="lifesteal" and unit.get("statuses",{}).has("shield"):
   amount*=maxf(0.0,1.0+float(mods.get("shield_lifesteal_pct",0))/100.0)
  value+=amount
 value+=Relic.resonance_modifier(entries,key)
 if key=="taken" and unit.hp*2<=unit.max_hp:
  for entry in entries:value+=float(Relic.definition(entry).mods.get("low_hp_taken",0))
  value+=Relic.resonance_modifier(entries,"low_hp_taken")
 if key=="max_ap":return minf(2.0,value)
 if key=="kill_ap":return minf(1.0,value)
 return value

func has_relic(unit: Dictionary,id: String) -> bool:
 return applicable_relics(unit).any(func(entry):return entry.id==id)

func consume_relic(unit: Dictionary,id: String):
 for entry in applicable_relics(unit):
  if entry.id!=id or entry.remaining<0:continue
  entry.remaining-=1
  if entry.remaining==0:
   relic_state.erase(entry)
   events.append("遗物损毁 · "+Relic.definition(entry).name+"（次数耗尽）")
   refresh_relic_stats()
  return

func refresh_relic_stats():
 for unit in actors:
  if unit.side!=0:continue
  var old=unit.get("relic_stats",{})
  var next={}
  for key in ["speed","armor","range","max_ap"]:
   next[key]=int(relic_modifier(unit,key))
   var base=unit.get(key,4 if key=="max_ap" else 0)-int(old.get(key,0))
   if key in ["range","max_ap","speed"]:next[key]=maxi(1,base+next[key])-base
   unit[key]=base+next[key]
  unit.relic_stats=next

func heal_unit(unit: Dictionary,amount: int) -> int:
 if unit.hp<=0:return 0
 var gain=mini(unit.max_hp-unit.hp,maxi(0,int(floor(amount*maxf(0.0,1.0+relic_modifier(unit,"healing_pct")/100.0)))))
 unit.hp+=gain
 return gain

func skill_relic_cost(unit: Dictionary,skill_id: String) -> int:
 var skill=Professions.ALL_SKILLS[skill_id]
 return int(relic_modifier(unit,"heal_mp")) if skill.effect=="heal" else 0

# Greedy decisions use the real rules on isolated state, including armor, splash,
# relic charges and overkill. Movement looks one hit ahead, then replans live.
func auto_snapshot():
 var copy=get_script().new()
 for property in ["actors","order","order_index","round_no","round_limit","radius","outcome","obstacles","bonuses","relic_state","traps","aura","biome","boss_intents","boss_cues"]:
  var value=get(property)
  copy.set(property,value.duplicate(true) if value is Array or value is Dictionary else value)
 return copy

func auto_hits() -> Array:
 var choices=[]
 if not can_act() or active().side!=0:return choices
 var a=active()
 for target in actors:
  if target.hp<=0 or target.side==a.side:continue
  if a.ap>=2 and hex_distance(a.cell,target.cell)<=a.range:
   choices.append({"action":"attack","target":target.id,"skill":""})
  for id in available_skills(a):
   if Professions.ALL_SKILLS[id].effect=="damage" and can_cast(id,target.id):
    choices.append({"action":"skill","target":target.id,"skill":id})
 return choices

func auto_best_hit() -> Dictionary:
 var best={}
 var best_damage=0
 var best_ap=999
 var best_mp=999
 for choice in auto_hits():
  var copy=auto_snapshot()
  if choice.action=="attack":copy.attack(choice.target)
  else:copy.cast(choice.target,choice.skill)
  var damage=0
  for i in range(actors.size()):
   if actors[i].side!=0:damage+=maxi(0,actors[i].hp-copy.actors[i].hp)
  var cost=2 if choice.action=="attack" else Professions.ALL_SKILLS[choice.skill].ap
  var mp=0 if choice.action=="attack" else skill_mana_cost(active(),choice.skill,choice.target)
  if damage>best_damage or (damage==best_damage and damage>0 and (cost<best_ap or (cost==best_ap and mp<best_mp))):
   best=choice.duplicate()
   best.damage=damage
   best_damage=damage
   best_ap=cost
   best_mp=mp
 return best

func auto_action() -> Dictionary:
 if not can_act() or active().side!=0:return {}
 var warned=boss_warnings()
 var actor=active()
 if actor.cell in warned:
  var escapes=[]
  for cell in cells():
   if cell in warned:continue
   var route=path_to(actor.cell,cell)
   if not route.is_empty() and movement_cost(actor,route)<=actor.ap:escapes.append({"cell":cell,"cost":movement_cost(actor,route)})
  escapes.sort_custom(func(x,y):
   if x.cost!=y.cost:return x.cost<y.cost
   if x.cell.x!=y.cell.x:return x.cell.x<y.cell.x
   return x.cell.y<y.cell.y)
  if not escapes.is_empty():return {"action":"move","target":escapes[0].cell}
 var hit=auto_best_hit()
 if not hit.is_empty():return hit
 var a=active()
 var enemies=actors.filter(func(u):return u.side!=a.side and u.hp>0)
 if enemies.is_empty():return {"action":"end"}
 var best={}
 var best_damage=-1
 var best_distance=999
 var best_cost=999
 var current_distance=999
 for enemy in enemies:current_distance=mini(current_distance,hex_distance(a.cell,enemy.cell))
 for cell in cells():
  if cell in warned:continue
  var path=path_to(a.cell,cell)
  if path.is_empty() or movement_cost(a,path)>a.ap:continue
  var copy=auto_snapshot()
  copy.move_to(cell)
  var moved=copy.find_actor(a.id)
  if moved.hp<=0 or moved.cell in warned:continue
  var damage=0
  if copy.can_act() and copy.active().id==a.id:
   damage=copy.auto_best_hit().get("damage",0)
  var distance=999
  for enemy in enemies:distance=mini(distance,hex_distance(moved.cell,enemy.cell))
  if damage==0 and distance>=current_distance:continue
  if damage>best_damage or (damage==best_damage and (distance<best_distance or (distance==best_distance and path.size()<best_cost))):
   best={"action":"move","target":cell}
   best_damage=damage
   best_distance=distance
   best_cost=path.size()
 if not best.is_empty():return best
 if rest_amount("mp")>0:return {"action":"rest_mp"}
 if rest_amount("hp")>0:return {"action":"rest_hp"}
 return {"action":"end"}

func movement_cost(unit: Dictionary,path: Array) -> int:
 return path.size()-(1 if not path.is_empty() and Talents.state(unit).free_step else 0)+(1 if not path.is_empty() and unit.get("statuses",{}).has("snare") else 0)

func boss_warnings() -> Array:
 var warned=[]
 for intent in boss_intents:
  var source=find_actor(intent.source)
  if source.is_empty() or source.hp<=0:continue
  for cell in intent.cells:
   if hex_distance(cell,Vector2i.ZERO)<=radius and cell not in warned:warned.append(cell)
 return warned

func boss_forecast() -> String:
 var result=[]
 for intent in boss_intents:
  var source=find_actor(intent.source)
  if source.is_empty() or source.hp<=0:continue
  var effects="%d基础伤害"%intent.damage if intent.damage>0 else "标记与号令"
  if intent.get("debuff","") in ["poison","chill","snare"]:effects+=" / "+{"poison":"两次毒伤","chill":"寒冷","snare":"束缚"}[intent.debuff]
  result.append(intent.name+"（"+("Ⅰ" if intent.get("phase",1)==1 else "Ⅱ")+"） · 下次首领行动结算 · "+effects+(" · 可用盾击打断" if intent.kind=="overload" else ""))
 return "；".join(result)

func enemy_skills(unit: Dictionary) -> Array:
 return EnemySkills.skills(unit)
func enemy_skill_ready(unit: Dictionary,id: String) -> bool:
 return EnemySkills.ready(self,unit,id)
func cast_enemy_skill(id: String,target=null) -> bool:
 if not EnemySkills.cast(self,id,target):return false
 after_action()
 return true
