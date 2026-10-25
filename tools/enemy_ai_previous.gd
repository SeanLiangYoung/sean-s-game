extends RefCounted
# Public-state, deterministic one-action planning. No scene, hidden input or rule mutation.
const Skills=preload("res://game/enemy_skills.gd")
const Jobs=preload("res://game/professions.gd")
const SHRINK_ROUNDS=[3,5,7,9]

static func dangerous(b,unit: Dictionary) -> Array:
 var result=[]
 if b.round_no in SHRINK_ROUNDS:
  for cell in b.cells():
   if b.hex_distance(cell,Vector2i.ZERO)>=b.radius:result.append(cell)
 for trap in b.traps:
  if trap.side!=unit.side and trap.cell not in result:result.append(trap.cell)
 for intent in b.boss_intents:
  var source=b.find_actor(intent.source)
  if source.is_empty() or source.side==unit.side or source.hp<=0:continue
  for cell in intent.cells:
   if cell not in result:result.append(cell)
 return result

static func occupied(b,ignore: String="") -> Dictionary:
 var result={}
 for unit in b.actors:
  if unit.hp>0 and unit.id!=ignore:result[unit.cell]=true
 return result

static func distances(b,start: Vector2i,blocked: Dictionary,forbidden: Array=[],limit: int=20) -> Dictionary:
 var result={start:0};var queue=[start];var cursor=0
 while cursor<queue.size():
  var cell=queue[cursor];cursor+=1
  if result[cell]>=limit:continue
  for direction in b.DIRS:
   var next=cell+direction
   if result.has(next) or blocked.has(next) or next in b.obstacles or next in forbidden or b.hex_distance(next,Vector2i.ZERO)>b.radius:continue
   result[next]=int(result[cell])+1;queue.append(next)
 return result

static func safe_paths(b,unit: Dictionary,hazards: Array) -> Dictionary:
 var previous={unit.cell:unit.cell};var queue=[unit.cell];var cursor=0
 while cursor<queue.size():
  var cell=queue[cursor];cursor+=1
  for direction in b.DIRS:
   var next=cell+direction
   if previous.has(next) or next in hazards or not b.is_free(next):continue
   previous[next]=cell;queue.append(next)
 var result={}
 for cell in previous:
  if cell==unit.cell:continue
  var route=[];var point=cell
  while point!=unit.cell:route.push_front(point);point=previous[point]
  if b.movement_cost(unit,route)<=unit.ap:result[cell]=route
 return result

static func firing_distances(b,actor: Dictionary,targets: Array,hazards: Array) -> Dictionary:
 var blocked=occupied(b,actor.id);var result={};var queue=[]
 for cell in b.cells():
  if cell in b.obstacles or cell in hazards or blocked.has(cell):continue
  if targets.any(func(target):return b.hex_distance(cell,target.cell)<=actor.range):result[cell]=0;queue.append(cell)
 var cursor=0
 while cursor<queue.size():
  var cell=queue[cursor];cursor+=1
  for direction in b.DIRS:
   var next=cell+direction
   if result.has(next) or blocked.has(next) or next in b.obstacles or b.hex_distance(next,Vector2i.ZERO)>b.radius:continue
   if next in hazards and next!=actor.cell:continue
   result[next]=int(result[cell])+1;queue.append(next)
 return result

static func threat_fields(b,actor: Dictionary) -> Array:
 var result=[];var blocked=occupied(b,actor.id)
 for opponent in b.actors:
  if opponent.side==actor.side or opponent.hp<=0:continue
  var budget=int(opponent.get("max_ap",4))
  result.append({"id":opponent.id,"power":opponent.power,"range":maxi(1,int(opponent.range)),"ap":budget,"paths":distances(b,opponent.cell,blocked,[],maxi(0,budget-2))})
 return result

static func pressure(b,cell: Vector2i,fields: Array,state=null) -> float:
 var total=0.0
 for field in fields:
  if state!=null and state.find_actor(field.id).hp<=0:continue
  var cost=999
  for position in field.paths:
   if b.hex_distance(position,cell)<=field.range:cost=mini(cost,int(field.paths[position]))
  if cost<=field.ap-2:total+=maxi(0,field.power)*int((field.ap-cost)/2)
 return total

static func mark_power(b,unit: Dictionary,side: int) -> int:
 var mark=unit.get("statuses",{}).get("mark",{})
 if mark.is_empty():return 0
 var source=b.find_actor(mark.source)
 return maxi(0,5+int(mark.get("bonus",0))) if not source.is_empty() and source.side==side and source.hp>0 else 0

static func followers(b,actor: Dictionary,target: Dictionary) -> float:
 var shots=0.0
 for ally in b.actors:
  if ally.side!=actor.side or ally.hp<=0:continue
  var distance=b.hex_distance(ally.cell,target.cell)
  var budget=ally.ap if ally.id==actor.id else int(ally.get("max_ap",4))
  if distance<=ally.range:shots+=maxi(0,int(budget/2))
  elif distance<=ally.range+maxi(0,budget-2):shots+=0.6
 return minf(4.0,shots)

static func status_value(b,after,actor: Dictionary,old: Dictionary,unit: Dictionary) -> float:
 var value=0.0
 if old.side!=actor.side:
  value+=(mark_power(after,unit,actor.side)-mark_power(b,old,actor.side))*followers(after,after.find_actor(actor.id),unit)*0.6
  var was_controlled=old.get("statuses",{}).has("stagger") or old.get("statuses",{}).has("chill")
  var controlled=unit.get("statuses",{}).has("stagger") or unit.get("statuses",{}).has("chill")
  if controlled and not was_controlled:value+=5.0
  if unit.get("statuses",{}).has("snare") and not old.get("statuses",{}).has("snare"):value+=2.5
  var ticks=int(unit.get("statuses",{}).get("poison",{}).get("ticks",0))-int(old.get("statuses",{}).get("poison",{}).get("ticks",0))
  value+=maxi(0,ticks)*maxi(1,3-int(unit.get("armor",0)))*0.65
 else:
  if unit.get("statuses",{}).has("command") and not old.get("statuses",{}).has("command"):
   var can_follow=b.actors.any(func(enemy):return enemy.hp>0 and enemy.side!=actor.side and b.hex_distance(unit.cell,enemy.cell)<=unit.range+maxi(0,int(unit.get("max_ap",4))-2))
   if can_follow:value+=3.5
 return value

static func shield(unit: Dictionary) -> int:
 var data=unit.get("statuses",{}).get("shield",{})
 return maxi(0,10+int(data.get("bonus",0))) if not data.is_empty() else 0

static func score_change(b,after,actor: Dictionary,fields: Array,hazards: Array) -> float:
 if after.outcome in ["gameover","defeat"]:return 100000.0
 if after.outcome=="victory":return -100000.0
 var result=0.0
 for old in b.actors:
  var unit=after.find_actor(old.id)
  if old.hp<=0:continue
  if old.side!=actor.side:
   result+=maxi(0,old.hp-unit.hp)
   if unit.hp<=0:result+=26.0
   result+=maxi(0,old.mp-unit.mp)*0.45
   result+=maxi(0,shield(old)-shield(unit))*0.25
   if unit.hp>0:result+=status_value(b,after,actor,old,unit)
  else:
   result-=maxi(0,old.hp-unit.hp)*1.25
   if unit.hp<=0:result-=38.0
   result+=maxi(0,unit.hp-old.hp)*0.55
   var absorbed=maxi(0,shield(unit)-shield(old))
   result+=minf(absorbed,pressure(b,unit.cell,fields,after))*0.85
   if unit.hp>0:result+=status_value(b,after,actor,old,unit)
 var moved=after.find_actor(actor.id)
 var old_risk=pressure(b,actor.cell,fields)
 var risk=pressure(after,moved.cell,fields,after)
 result+=(old_risk-risk)*0.28
 result+=(maxf(0,old_risk-actor.hp)-maxf(0,risk-moved.hp))*0.85
 if actor.cell in hazards and moved.cell not in hazards:result+=100.0
 if moved.cell in hazards and actor.cell not in hazards:result-=80.0
 return result

static func intent_value(b,after,actor: Dictionary) -> float:
 if after.boss_intents.size()<=b.boss_intents.size():return 0.0
 var intent=after.boss_intents[-1];var total=0.0
 for target in b.actors:
  if target.hp<=0 or target.side==actor.side or target.cell not in intent.cells:continue
  var damage=maxi(0,int(intent.damage)-int(target.get("armor",0))-shield(target))
  total+=damage*0.65
  if intent.get("debuff","") in ["snare","chill","poison"]:total+=2.5
  if intent.kind=="command":total+=minf(7.0,followers(b,actor,target)*2.5)
 if intent.kind=="command":
  var available=b.actors.filter(func(u):return u.side==actor.side and u.hp>0 and u.id!=actor.id and not u.get("statuses",{}).has("command"))
  total+=minf(2.0,available.size())*2.0
 return total+1.5

static func consider(best: Dictionary,choice: Dictionary,score: float,cost: int) -> Dictionary:
 if score>float(best.get("score",0.0))+0.001 or (absf(score-float(best.get("score",0)))<0.001 and score>0 and cost<int(best.get("cost",999))):
  var result=choice.duplicate(true);result.score=score;result.cost=cost;return result
 return best

static func evaluate(b,actor: Dictionary,fields: Array,hazards: Array) -> Dictionary:
 var best={"score":0.0,"cost":999}
 var targets=b.actors.filter(func(u):return u.side!=actor.side and u.hp>0)
 # Prefer basic attack on equal value, preserving a cooldown.
 for target in targets:
  if actor.ap<2 or b.hex_distance(actor.cell,target.cell)>actor.range:continue
  var copy=b.auto_snapshot()
  if not copy.attack(target.id):continue
  var score=score_change(b,copy,actor,fields,hazards)
  best=consider(best,{"action":"attack","target":target.id,"reason":"补刀与协同集火" if target.hp<=actor.power or mark_power(b,target,actor.side)>0 else "选择有效伤害目标"},score,2)
 for id in Skills.skills(actor):
  if not Skills.ready(b,actor,id):continue
  var skill=Skills.SKILLS[id]
  var options=[null] if skill.range==0 else targets.map(func(u):return u.id)
  for target in options:
   if not Skills.can_cast(b,id,target):continue
   var copy=b.auto_snapshot()
   if not copy.cast_enemy_skill(id,target):continue
   var score=score_change(b,copy,actor,fields,hazards)+intent_value(b,copy,actor)
   var reason={"intent":"预告压制密集目标","mark":"为同伴建立标记","shield":"应对即将承受的攻击","recover":"恢复生命维持战线","command":"支援可接战的同伴","cleave":"压制相邻多目标","pin":"控制目标行动","cold":"控制目标行动","drain":"压制法力与输出"}.get(skill.effect,"按实际伤害与状态选择技能")
   best=consider(best,{"action":"skill","skill":id,"target":target,"reason":reason},score,int(skill.ap))
 return best

static func decide(b) -> Dictionary:
 return plan(b.auto_snapshot())

static func plan(b) -> Dictionary:
 if not b.can_act() or b.active().side!=1:return {}
 var actor=b.active();var hazards=dangerous(b,actor);var fields=threat_fields(b,actor)
 var best=evaluate(b,actor,fields,hazards)
 var old_pressure=pressure(b,actor.cell,fields)
 var targets=b.actors.filter(func(u):return u.side!=actor.side and u.hp>0)
 if targets.is_empty():return {"action":"end","reason":"战斗结束"}
 var firing=firing_distances(b,actor,targets,hazards)
 var old_gap=int(firing.get(actor.cell,999))
 var paths=safe_paths(b,actor,hazards)
 var candidates=[]
 for cell in paths:
  var route=paths[cell];var cost=b.movement_cost(actor,route)
  var remaining=actor.ap-cost;var gap=int(firing.get(cell,999));var shot=0.0
  for target in targets:
   var distance=b.hex_distance(cell,target.cell)
   if distance<=actor.range and remaining>=2:shot=maxf(shot,maxi(1,actor.power-target.get("armor",0))*int(remaining/2)*0.65)
  if actor.range>1 and gap>old_gap and shot<=0 and actor.cell not in hazards and old_pressure<actor.hp:continue
  var safety=(old_pressure-pressure(b,cell,fields))*(0.45 if actor.range>1 else 0.12)
  var score=(old_gap-gap)*3.0+safety+shot-cost*0.25
  if actor.cell in hazards:score+=100.0
  if actor.get("trait","")=="formation" or actor.get("boss_passive","")=="standard":
   var near=b.actors.filter(func(u):return u.side==actor.side and u.hp>0 and u.id!=actor.id and b.hex_distance(cell,u.cell)==1).size()
   var old_near=b.actors.filter(func(u):return u.side==actor.side and u.hp>0 and u.id!=actor.id and b.hex_distance(actor.cell,u.cell)==1).size()
   score+=minf(2.0,near-old_near)*1.5
  candidates.append({"cell":cell,"score":score,"cost":cost,"route":route})
 candidates.sort_custom(func(x,y):
  if absf(x.score-y.score)>0.001:return x.score>y.score
  if x.cost!=y.cost:return x.cost<y.cost
  if x.cell.x!=y.cell.x:return x.cell.x<y.cell.x
  return x.cell.y<y.cell.y)
 for candidate in candidates.slice(0,5):
  var destination=candidate.cell
  var actual=b.path_to(actor.cell,destination)
  # Real move_to follows its own shortest path. If it crosses a hazard, take a safe adjacent step and replan.
  var detour=actual.any(func(cell):return cell in hazards)
  if detour:destination=candidate.route[0]
  var route=b.path_to(actor.cell,destination)
  if route.is_empty() or route.any(func(cell):return cell in hazards):continue
  var reason="撤出灰潮与敌对危险格" if actor.cell in hazards else ("绕开机关寻找通路" if detour else ("借地形拉开距离并保留攻击点" if actor.range>1 and candidate.cost<=actor.ap-2 else "接近目标并利用通路"))
  best=consider(best,{"action":"move","target":destination,"reason":reason},candidate.score,int(candidate.cost))
 if best.has("action"):return best
 # Paid recovery/end is finite; there is no movement recursion or free action retry.
 return {"action":"rest","target":"hp","reason":"无有效进攻，休整结束行动","score":0.0}
