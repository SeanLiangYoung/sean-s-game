extends RefCounted
# Deterministic tactical state; no scene or rendering dependency.
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
var traps: Array = []
var aura = ""

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

func start_battle(party: Array, difficulty: int, relic_bonuses: Array = []):
 actors = []
 traps=[]
 aura=""
 bonuses = relic_bonuses.duplicate()
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
  u.used_skills=[]
  u.kill_refunded=false
  u.kills=0
  u.ap=u.max_ap
  actors.append(u)
 var enemy_starts = [Vector2i(2,0),Vector2i(2,-1),Vector2i(1,2),Vector2i(3,-2),Vector2i(0,3)]
 for i in range(3+difficulty):
  var ranged = i%3 == 2
  var hp = 36+difficulty*24
  actors.append({"id":"enemy%d"%i,"name":"灰巢弩手" if ranged else "灰巢掠夺者","role":"敌人","max_hp":hp,"hp":hp,"max_mp":0,"mp":0,"speed":9+i,"power":10+difficulty*3,"range":3 if ranged else 1,"side":1,"ap":4,"cell":enemy_starts[i]})
 for u in actors:
  if u.id=="hero" and u.side==0 and u.hp>0:aura=u.get("mainhand","")
 for u in actors:
  if u.side!=0:continue
  if aura=="dagger":u.speed+=2
  if aura=="bow":u.range+=1
  if aura=="crossbow":u.armor+=2
 rebuild_order()
 events.append("主角光环："+aura_description())
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
 if path.is_empty() or path.size()>a.ap:return false
 var traversed=0
 for step in path:
  a.ap-=1
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
 var amount=a.power
 if Professions.job_id(a)=="ranger" and hex_distance(a.cell,target.cell)>=3:amount+=3
 deal_damage(a,target,amount)
 after_action()
 return true

func available_skills(unit: Dictionary) -> Array:
 return Professions.skills_for(unit)

func default_skill(unit: Dictionary) -> String:
 var skills=available_skills(unit)
 return skills[0] if not skills.is_empty() else ""

func skill_ready(skill_id: String) -> bool:
 if not can_act() or active().side!=0 or skill_id not in available_skills(active()):return false
 var a=active()
 var skill=Professions.ALL_SKILLS[skill_id]
 return a.ap>=skill.ap and a.mp>=skill.mp and skill_id not in a.get("used_skills",[])

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
 if not skill_ready(skill_id):return false
 var a=active()
 var skill=Professions.ALL_SKILLS[skill_id]
 if skill.target=="cell":return target is Vector2i and is_free(target) and hex_distance(a.cell,target)<=skill.range
 if not target is String:return false
 var t=find_actor(target)
 if t.is_empty() or t.hp<=0 or hex_distance(a.cell,t.cell)>skill.range:return false
 if skill.target=="enemy" and t.side==a.side:return false
 if skill.target in ["ally","other_ally"] and t.side!=a.side:return false
 if skill.target=="other_ally" and t.id==a.id:return false
 if skill_id=="dash" and dash_landing(a,t)==null:return false
 return true

func cast(target,skill_id: String="") -> bool:
 if skill_id=="" and can_act():skill_id=default_skill(active())
 if not can_cast(skill_id,target):return false
 var a=active()
 var skill=Professions.ALL_SKILLS[skill_id]
 var effect_id=skill.get("base",skill_id)
 var rank_bonus=Professions.skill_bonus(a,skill_id)
 a.ap-=skill.ap
 a.mp-=skill.mp
 a.used_skills.append(skill_id)
 events.append("%s 施放 %s"%[a.name,skill.name])
 if effect_id=="trap":
  traps=traps.filter(func(trap):return trap.source!=a.id)
  traps.append({"source":a.id,"side":a.side,"cell":target,"damage":(26 if Professions.job_id(a)=="engineer" else 20)+rank_bonus})
 else:
  var t=find_actor(target)
  match effect_id:
   "heal":
    var amount=26+rank_bonus+a.get("heal_bonus",0)+(6 if Professions.job_id(a)=="medic" else 0)+(8 if "fury" in a.get("learned",[]) else 0)
    var gain=mini(t.max_hp-t.hp,amount)
    t.hp+=gain
    events.append("%s 恢复 %d 生命"%[t.name,gain])
   "mark":put_status(t,"mark",a.id,rank_bonus)
   "cleanse":
    t.statuses.erase("mark")
    put_status(t,"shield",a.id,rank_bonus)
   "guard":put_status(t,"guard",a.id,rank_bonus)
   _:
    if skill_id=="dash":
     var destination=dash_landing(a,t)
     if destination!=a.cell:
      a.cell=destination
      trigger_trap(a)
    if a.hp>0:
     var extra={"strike":14,"dash":4,"execute":6,"sniper":10,"bomb":2,"bash":0}.get(effect_id,0)
     if effect_id=="execute" and t.hp*2<=t.max_hp:extra+=10
     var victims=[t]
     if effect_id=="bomb":victims=actors.filter(func(u):return u.hp>0 and u.side!=a.side and hex_distance(t.cell,u.cell)<=1)
     for victim in victims:
      if a.hp>0:deal_damage(a,victim,a.power+extra+rank_bonus+(8 if "fury" in a.get("learned",[]) else 0))
     if effect_id=="bash" and t.hp>0:put_status(t,"stagger",a.id)
 after_action()
 return true

func put_status(unit: Dictionary,kind: String,source_id: String,bonus: int=0):
 if not unit.has("statuses"):unit.statuses={}
 unit.statuses[kind]={"source":source_id,"bonus":bonus}

func clear_source_statuses(source_id: String):
 for unit in actors:
  for kind in unit.get("statuses",{}).keys():
   if kind!="stagger" and unit.statuses[kind].source==source_id:unit.statuses.erase(kind)

func clean_dead_statuses():
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
 unit.used_skills=[]
 unit.kill_refunded=false
 var stagger=unit.get("statuses",{}).has("stagger")
 unit.ap=maxi(1,unit.get("max_ap",4)-(1 if stagger else 0))
 if stagger:unit.statuses.erase("stagger")
 if aura=="staff" and unit.side==0 and unit.hp>0:
  var gain=mini(3,unit.max_hp-unit.hp)
  unit.hp+=gain
  if gain>0:events.append("主角光环 · %s 恢复 %d 生命"%[unit.name,gain])

func lose_hp(unit: Dictionary,amount: int):
 unit.hp=maxi(0,unit.hp-amount)
 events.append("%s −%d 生命"%[unit.name,amount])

func deal_damage(source: Dictionary,target: Dictionary,amount: int,direct: bool=true):
 if direct:
  if source.side==0:
   if "ember" in bonuses:amount+=4
   if aura=="sword":amount+=2
  var marked=target.get("statuses",{}).get("mark",{})
  if not marked.is_empty():
   var marker=find_actor(marked.source)
   if not marker.is_empty() and marker.hp>0 and marker.side==source.side:amount+=5+int(marked.get("bonus",0))
 amount=maxi(1,amount-target.get("armor",0))
 if target.get("statuses",{}).has("shield"):
  amount=maxi(0,amount-10-int(target.statuses.shield.get("bonus",0)))
  target.statuses.erase("shield")
 var guard_data=target.get("statuses",{}).get("guard",{})
 if direct and not guard_data.is_empty():
  var protector=find_actor(guard_data.source)
  if not protector.is_empty() and protector.hp>0 and protector.id!=target.id and hex_distance(protector.cell,target.cell)<=2:
   var share=int(ceil(amount/2.0))
   amount-=share
   var reduced=share-int(guard_data.get("bonus",0))-protector.get("armor",0)-(3 if Professions.job_id(protector)=="warden" else 0)
   if protector.get("statuses",{}).has("shield"):
    reduced-=10+int(protector.statuses.shield.get("bonus",0));protector.statuses.erase("shield")
   lose_hp(protector,maxi(0,reduced))
 var was_alive=target.hp>0
 lose_hp(target,amount)
 if was_alive and target.hp<=0 and source.get("side",-1)==0 and target.side==1:
  source.kills=int(source.get("kills",0))+1
  events.append("%s 击杀奖励 +15经验（胜利后结算）"%source.name)
 if target.hp<=0 and source.hp>0 and Professions.job_id(source)=="blade" and not source.get("kill_refunded",false):
  source.ap+=1;source.kill_refunded=true
  events.append("游剑客专精 · 击杀恢复1行动点")
 clean_dead_statuses()

func trigger_trap(unit: Dictionary) -> bool:
 for i in range(traps.size()):
  var trap=traps[i]
  if trap.cell!=unit.cell or trap.side==unit.side:continue
  traps.remove_at(i)
  var source=find_actor(trap.source)
  deal_damage(source,unit,trap.damage,false)
  events.append("机关触发 · %s 停止移动"%unit.name)
  return true
 return false

func aura_description() -> String:
 return Professions.AURAS.get(aura,"无生效光环（主角未上阵或未装备主手）")

func status_text(unit: Dictionary) -> String:
 var names={"mark":"被标记：受击+5","shield":"净护：下次减伤10","guard":"援护中","stagger":"下次行动点-1"}
 var result=[]
 for kind in unit.get("statuses",{}):
  var bonus=int(unit.statuses[kind].get("bonus",0))
  if kind=="mark":result.append("被标记：受击+%d"%[5+bonus])
  elif kind=="shield":result.append("净护：下次减伤%d"%[10+bonus])
  elif kind=="guard":result.append("援护中 · 额外减伤%d"%bonus)
  else:result.append(names.get(kind,kind))
 return " · ".join(result)

func rest_amount(kind: String) -> int:
 var a = active()
 if a.is_empty() or a.ap <= 0:return 0
 var maximum = a.max_hp if kind == "hp" else a.max_mp
 var current = a.hp if kind == "hp" else a.mp
 var ratio = 0.07 if "spring" in bonuses and a.side == 0 else 0.05
 if "focus" in a.get("learned",[]):ratio+=0.02
 return mini(maximum-current,maxi(1,int(floor(maximum*a.ap*ratio))))

func rest(kind: String) -> bool:
 if not can_act() or kind not in ["hp","mp"]:return false
 var a = active()
 var gain = rest_amount(kind)
 a[kind] += gain
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
   var damage = int(ceil(a.max_hp*0.2))
   a.hp = maxi(0,a.hp-damage)
   events.append("%s 被灰潮推移，−%d 生命"%[a.name,damage])
 check_outcome()

func enemy_step():
 if not can_act() or active().side != 1:return
 var a = active()
 var targets = actors.filter(func(u):return u.side == 0 and u.hp > 0)
 if targets.is_empty():check_outcome();return
 targets.sort_custom(func(x,y):return hex_distance(a.cell,x.cell)<hex_distance(a.cell,y.cell))
 for t in targets:
  if hex_distance(a.cell,t.cell)<=a.range and a.ap>=2:
   attack(t.id)
   return
 if a.ap > 0:
  var target = targets[0]
  var candidates = cells().filter(func(c):return is_free(c))
  candidates.sort_custom(func(x,y):return hex_distance(x,target.cell)<hex_distance(y,target.cell))
  for c in candidates:
   if hex_distance(c,target.cell)>=hex_distance(a.cell,target.cell):continue
   var path = path_to(a.cell,c)
   if path.is_empty():continue
   # Stop in attack range and preserve attack AP when feasible.
   var steps = mini(path.size(),maxi(1,a.ap-2))
   move_to(path[steps-1])
   return
 rest("hp")

func use_medicine(id: String) -> bool:
 if not can_act() or active().side!=0 or active().ap<2:return false
 var a=active()
 var target=find_actor(id)
 if target.is_empty() or target.side!=0 or target.hp<=0:return false
 if hex_distance(a.cell,target.cell)>3:return false
 if target.hp==target.max_hp and target.mp==target.max_mp:return false
 a.ap-=2
 target.hp=mini(target.max_hp,target.hp+int(target.max_hp*0.3))
 target.mp=mini(target.max_mp,target.mp+int(target.max_mp*0.3))
 events.append("%s 为 %s 使用补给：恢复30%%生命与法力"%[a.name,target.name])
 after_action()
 return true

func end_action() -> bool:
 if not can_act() or active().side!=0:return false
 events.append("%s 结束行动"%active().name)
 finish_turn()
 return true
