extends RefCounted
const Skills=preload("res://game/enemy_skills.gd")
const Regions=preload("res://game/regions.gd")

static func setup(b,unit: Dictionary,biome: String,is_boss: bool):
 var region=Regions.definition(biome)
 var row=region.enemies[0 if unit.range>1 else 1]
 unit.merge({"biome":biome,"archetype":row[0],"trait":region.boss_trait if is_boss else row[1],"boss":is_boss,"statuses":{},"frost_used":false,"venom_used":false,"boss_prepared":false,"turn_serial":0},true)
 unit.region_trait=unit.trait
 unit.cooldowns={};unit.enemy_used=false
 if is_boss:
  unit.boss_phase=1;unit.boss_passive=Regions.phase_data(biome,1).passive
  unit.passive_used=false
 unit.name=region.boss if is_boss else row[0]
 renew_barrier(b,unit)

static func renew_barrier(b,unit: Dictionary):
 if unit.hp<=0 or unit.get("statuses",{}).has("exposed"):return
 var amount={"capacitor":6,"core":10,"ice_king":10}.get(unit.get("trait",""),0)
 if unit.get("boss_phase",1)==2:
  if unit.trait=="ice_king":amount=6
  elif unit.trait=="core":amount=6
 if amount>0 and unit.get("affix","")=="warded":amount+=4
 if amount>0:b.put_status(unit,"shield",unit.id,amount-10)

static func reduction(b,source: Dictionary,target: Dictionary,direct: bool) -> int:
 if not direct:return 0
 var exposed=target.get("statuses",{}).has("exposed")
 var passive=target.get("boss_passive","")
 var passive_reduction=0
 if not target.get("passive_used",false):
  if passive=="standard" and b.actors.any(func(u):return u.side==target.side and u.id!=target.id and u.hp>0):passive_reduction=2
  elif passive=="sandguard" and not exposed and not target.get("statuses",{}).has("mark") and b.hex_distance(source.cell,target.cell)>=3:passive_reduction=2
  if passive_reduction>0:target.passive_used=true
 match target.get("trait",""):
  "formation":
   if b.actors.any(func(a):return a.hp>0 and a.side==target.side and a.id!=target.id and b.hex_distance(a.cell,target.cell)==1):return 2+passive_reduction
  "camouflage":
   if not exposed and not target.get("statuses",{}).has("mark") and b.hex_distance(source.cell,target.cell)>=3:return (2 if target.get("boss_phase",1)==2 else 4)+passive_reduction
  "frost_armor":
   if not exposed and not target.get("frost_used",false):
    target.frost_used=true
    return 4+passive_reduction
 return passive_reduction

static func attack_bonus(unit: Dictionary,target: Dictionary) -> int:
 var bonus=0
 if unit.get("trait","")=="raider" and unit.hp*2<=unit.max_hp:bonus+=3
 if unit.get("trait","")=="ambush" and target.hp==target.max_hp:bonus+=3
 if unit.get("statuses",{}).has("command"):
  bonus+=3
  unit.statuses.erase("command")
 return bonus

static func after_attack(b,source: Dictionary,target: Dictionary,damage: int):
 if damage<=0 or source.hp<=0:return
 if source.get("trait","")=="mirehide":source.hp=mini(source.max_hp,source.hp+int(damage*0.2))
 if target.hp<=0 or source.get("venom_used",false):return
 match source.get("trait",""):
  "spotter":b.put_status(target,"mark",source.id)
  "venom":poison(b,target,source.id)
  "frostshot":b.put_status(target,"chill",source.id)
  "sapper","drainer":target.mp=maxi(0,target.mp-(2 if source.trait=="sapper" else 3))
  _:return
 source.venom_used=true

static func poison(b,target: Dictionary,source: String):
 b.put_status(target,"poison",source,2)
 target.statuses.poison.ticks=2

static func turn_start(b,unit: Dictionary,staggered: bool):
 unit.frost_used=false
 unit.venom_used=false
 unit.boss_prepared=false
 unit.turn_serial=int(unit.get("turn_serial",0))+1
 unit.passive_used=false
 update_phase(b,unit)
 Skills.turn_start(b,unit)
 if unit.get("boss_passive","")=="rootheart" and not unit.get("statuses",{}).has("exposed"):unit.hp=mini(unit.max_hp,unit.hp+2)
 if unit.get("boss_passive","")=="sporeveil" and b.actors.any(func(u):return u.side!=unit.side and u.hp>0 and u.get("statuses",{}).has("poison")):unit.hp=mini(unit.max_hp,unit.hp+3)
 renew_barrier(b,unit)
 if not unit.get("boss",false):return
 var due=b.boss_intents.filter(func(intent):return intent.source==unit.id and intent.due<=unit.turn_serial)
 for intent in due:
  b.boss_intents.erase(intent)
  if staggered and intent.kind=="overload":
   b.events.append("星核过载被打断 · 监守失去本次蓄力")
   cue(b,unit,"interrupt",intent)
   continue
  resolve(b,unit,intent)
  b.check_outcome()
  if b.outcome!="":return

static func prepare(b,boss: Dictionary,preferred: String="") -> bool:
 if not boss.get("boss",false) or boss.get("boss_prepared",false) or not Skills.ready(b,boss,boss.biome+"_intent"):return false
 var targets=b.actors.filter(func(u):return u.side==0 and u.hp>0)
 if targets.is_empty():return false
 targets.sort_custom(func(x,y):
  if boss.biome=="ruins" and x.mp!=y.mp:return x.mp>y.mp
  if x.hp!=y.hp:return x.hp<y.hp
  return str(x.id)<str(y.id))
 if preferred!="":
  var chosen=targets.filter(func(u):return u.id==preferred)
  if chosen.is_empty():return false
  targets.erase(chosen[0]);targets.push_front(chosen[0])
 var center=targets[0].cell
 var region=Regions.definition(boss.biome)
 var phase=int(boss.get("boss_phase",1))
 var phase_info=Regions.phase_data(boss.biome,phase)
 var warned=[center]
 if region.kind=="command":
  if targets.size()>1:warned.append(targets[1].cell)
 elif region.kind=="sandline":
  # Pick one of six straight hex axes; a lateral step always leaves the ray.
  var direction=b.DIRS[0]
  var closest=999
  for dir in b.DIRS:
   var distance=b.hex_distance(boss.cell+dir,center)
   if distance<closest:closest=distance;direction=dir
  warned=[]
  for step in range(-2,3):warned.append(center+direction*step)
  if phase==2:
   var crossing=b.DIRS[(b.DIRS.find(direction)+2)%6]
   warned.append(center+crossing);warned.append(center-crossing)
 else:
  warned.append(center+b.DIRS[1]);warned.append(center+b.DIRS[4])
  if phase==2:warned.append(center+b.DIRS[0]);warned.append(center+b.DIRS[3])
 warned=warned.filter(func(cell):return b.hex_distance(cell,Vector2i.ZERO)<=b.radius and cell not in b.obstacles)
 if warned.is_empty():warned=[center]
 warned=fair_warnings(b,warned)
 Skills.spend(boss,boss.biome+"_intent")
 boss.boss_prepared=true
 var intent={"source":boss.id,"kind":region.kind,"name":phase_info.name if phase==2 else region.intent,"cells":warned,"damage":phase_info.damage if phase==2 else region.damage,"debuff":region.debuff,"due":boss.turn_serial+1,"phase":phase,"drain":(3 if phase==2 else 2) if region.kind=="sandline" else (5 if phase==2 else 4),"followers":1 if phase==2 else 2}
 b.boss_intents.append(intent)
 cue(b,boss,"charge",intent)
 b.events.append("首领预告 · "+intent.name+"：下次自身行动结算，移出危险格")
 return true

static func resolve(b,boss: Dictionary,intent: Dictionary):
 b.events.append("首领施放 · "+intent.name)
 cue(b,boss,"release",intent)
 var targets=b.actors.filter(func(u):return u.hp>0 and u.side==0 and u.cell in intent.cells and b.hex_distance(u.cell,Vector2i.ZERO)<=b.radius)
 if intent.kind=="command":
  for target in targets:b.put_status(target,"mark",boss.id)
  var followers=b.actors.filter(func(u):return u.hp>0 and u.side==1 and u.id!=boss.id)
  for follower in followers.slice(0,int(intent.get("followers",2))):b.put_status(follower,"command",boss.id)
  if intent.damage<=0:return
 for target in targets:
  var before=target.hp
  b.deal_damage(boss,target,intent.damage,true)
  if target.hp<=0 or target.hp==before:continue
  if intent.debuff=="poison":poison(b,target,boss.id)
  elif intent.debuff!="":b.put_status(target,intent.debuff,boss.id)
  if intent.kind in ["sandline","overload"]:target.mp=maxi(0,target.mp-int(intent.get("drain",2 if intent.kind=="sandline" else 4)))

static func update_phase(b,unit: Dictionary):
 if not unit.get("boss",false) or unit.hp<=0 or unit.get("boss_phase",1)>=2 or unit.hp*2>unit.max_hp:return
 unit.boss_phase=2
 var phase=Regions.phase_data(unit.biome,2)
 b.events.append("首领转阶段 · "+unit.name+"："+phase.title+"；已预告招式保持不变")
 cue(b,unit,"phase",{"name":phase.title,"kind":Regions.definition(unit.biome).kind,"cells":[unit.cell],"damage":0,"debuff":"","phase":2})

static func cue(b,unit: Dictionary,type: String,intent: Dictionary):
 var entry=intent.duplicate(true)
 entry.merge({"type":type,"source":unit.id,"biome":unit.get("biome","border"),"phase":intent.get("phase",unit.get("boss_phase",1))},true)
 b.boss_cues.append(entry)

static func fair_warnings(b,candidates: Array) -> Array:
 var result=[]
 for cell in candidates:
  if cell not in result and b.hex_distance(cell,Vector2i.ZERO)<=b.radius and cell not in b.obstacles:result.append(cell)
 # Never cover the whole late board or every reachable escape from a threatened unit.
 for ally in b.actors:
  if ally.side!=0 or ally.hp<=0 or ally.cell not in result:continue
  var reachable=b.cells().filter(func(cell):return b.is_free(cell) and not b.path_to(ally.cell,cell).is_empty())
  if reachable.is_empty():continue
  var allowance=maxi(1,int(ally.get("max_ap",4))-(1 if ally.get("statuses",{}).has("stagger") or ally.get("statuses",{}).has("chill") else 0))
  var affordable=reachable.filter(func(cell):return b.movement_cost(ally,b.path_to(ally.cell,cell))<=allowance)
  var free=affordable.filter(func(cell):return cell not in result)
  if free.is_empty() and not affordable.is_empty():result.erase(affordable[0])
 return result
