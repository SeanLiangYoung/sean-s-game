extends RefCounted
# Deterministic tactical state; no scene or rendering dependency.
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
  u.ap = 4
  actors.append(u)
 var enemy_starts = [Vector2i(2,0),Vector2i(2,-1),Vector2i(1,2),Vector2i(3,-2),Vector2i(0,3)]
 for i in range(3+difficulty):
  var ranged = i%3 == 2
  var hp = 36+difficulty*24
  actors.append({"id":"enemy%d"%i,"name":"灰巢弩手" if ranged else "灰巢掠夺者","role":"敌人","max_hp":hp,"hp":hp,"max_mp":0,"mp":0,"speed":9+i,"power":10+difficulty*3,"range":3 if ranged else 1,"side":1,"ap":4,"cell":enemy_starts[i]})
 rebuild_order()
 events.append("遭遇开始。第 3 回合结束时首次收缩。")

func rebuild_order():
 order = []
 for i in range(actors.size()):
  if actors[i].hp > 0:order.append(i)
 order.sort_custom(func(a,b):return actors[a].speed > actors[b].speed if actors[a].speed != actors[b].speed else a < b)
 order_index = 0
 if not order.is_empty():actors[order[0]].ap = 4

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
 a.ap -= path.size()
 a.cell = cell
 events.append("%s 移动 %d 格"%[a.name,path.size()])
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
 var damage = a.power+(4 if "ember" in bonuses and a.side == 0 else 0)
 target.hp = maxi(0,target.hp-damage)
 events.append("%s → %s  −%d 生命"%[a.name,target.name,damage])
 after_action()
 return true

func cast(id: String) -> bool:
 if not can_act():return false
 var a = active()
 var t = find_actor(id)
 if t.is_empty() or t.hp <= 0 or a.ap < 3 or a.mp < 8:return false
 if hex_distance(a.cell,t.cell)>3:return false
 var heal = a.role == "行医者"
 if heal and t.side != a.side:return false
 if not heal and t.side == a.side:return false
 a.ap -= 3
 a.mp -= 8
 if heal:
  t.hp = mini(t.max_hp,t.hp+26+(8 if "fury" in a.get("learned",[]) else 0))
  events.append("%s 为 %s 恢复 26 生命"%[a.name,t.name])
 else:
  var damage = a.power+14+(8 if "fury" in a.get("learned",[]) else 0)+(4 if "ember" in bonuses and a.side == 0 else 0)
  t.hp = maxi(0,t.hp-damage)
  events.append("%s 施放战技 → %s  −%d 生命"%[a.name,t.name,damage])
 after_action()
 return true

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
 if outcome == "" and active().ap <= 0:finish_turn()

func check_outcome():
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
  active().ap = 4

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
