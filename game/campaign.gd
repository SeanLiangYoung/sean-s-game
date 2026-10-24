extends RefCounted
const Professions=preload("res://game/professions.gd")
const Rules = preload("res://game/rules.gd")
var save_path = "user://ashbound-save.json"
const REWARDS = [
 {"id":"ember","name":"余烬徽印","type":"relic","desc":"全队攻击与伤害战技 +4","color":"#ec9a5c"},
 {"id":"spring","name":"旧世泉核","type":"relic","desc":"休息每点行动点恢复 7%","color":"#80c7b2"},
 {"id":"lens","name":"测绘透镜","type":"relic","desc":"拾取时获得 30 银币；可带回收藏","color":"#97b7df"},
 {"id":"silver","name":"佣金袋","type":"resource","desc":"获得 65 银币","color":"#dbbf78"},
 {"id":"medicine","name":"战地药箱","type":"resource","desc":"获得 2 份补给，可在野外恢复队伍","color":"#80c7b2"},
 {"id":"sword","name":"遗铁刃","type":"equipment","desc":"武器 · 攻击 +3；可分配、更换或卸下","color":"#b4a1d1"}]
const Route = preload("res://game/route.gd")
const LEGACY_GOODS = {"sword":{"name":"遗铁刃","price":45,"desc":"武器 · 攻击 +3"},"ember":{"name":"余烬徽印","price":70,"desc":"遗物 · 全队攻击与伤害战技 +4"},"spring":{"name":"旧世泉核","price":60,"desc":"遗物 · 休息恢复提升"},"fury":{"name":"技能书 · 破阵","price":35,"desc":"学习后伤害战技 +8；治疗战技 +8"},"focus":{"name":"技能书 · 调息","price":30,"desc":"学习后每点休息行动额外恢复 2%"}}
static func goods_catalog() -> Dictionary:
 var result=LEGACY_GOODS.duplicate(true)
 for id in Professions.ITEMS:
  var item=Professions.ITEMS[id]
  result[id]={"name":item.name,"price":item.price,"desc":Professions.item_description(id)}
 for id in Professions.SKILLS:
  if id=="strike":continue
  var skill=Professions.SKILLS[id]
  result[id]={"name":"技能书 · "+skill.name,"price":35,"desc":skill.desc}
 return result
static var GOODS=goods_catalog()
var trial_equipment_claimed=true
var route = Route.new()
var books: Array = []
var purchases: Array = []
var recruits: Array = []
var equipment: Array = []
var roster: Array = []
var phase = "camp"
var encounters: Array = ["open","open","open"]
var relics: Array = []
var collection: Array = []
var choices: Array = []
var silver = 40
var supplies = 3
var snapshot: Dictionary = {}
var current_encounter = -1
var expedition = 0
var world_position = [0.0,5.0]
var notice = "整备队伍，穿过灰潮边境。"
var event_used = false
var reward_seed = 71023
var rng = RandomNumberGenerator.new()

func _init(destination: String = "user://ashbound-save.json"):
 save_path=destination
 roster = Rules.new().default_party()
 for id in Professions.ITEMS:equipment.append({"id":id,"owner":""})
 rng.seed = reward_seed

func depart() -> bool:
 if phase != "camp":return false
 if not roster.any(func(u):return u.id=="hero" and u.hp>0):return false
 for u in roster:
  if u.hp > 0:
   u.hp = u.max_hp
   u.mp = u.max_mp
 snapshot = to_data(false)
 expedition += 1
 phase = "world"
 relics = []
 choices = []
 encounters = ["open","open","open"]
 event_used = false
 world_position = [0.0,5.0]
 notice = "远征开始。血量与法力不会在战后恢复。"
 save_game()
 return true

func make_battle(ids: Array, encounter: int):
 if phase != "world" or encounter<0 or encounter>=3 or encounters[encounter] != "open":return null
 if route.region!="" and (not at_node("battle") or route.completed or int(route.node(route.current).encounter)!=encounter):return null
 if ids.is_empty() or ids.size()>5:return null
 var chosen = []
 for id in ids:
  var matches = roster.filter(func(u):return u.id==id and u.hp>0)
  if matches.is_empty() or chosen.any(func(u):return u.id==id):return null
  chosen.append(matches[0])
 # Keep the latest world progress as the pre-battle checkpoint.
 if not save_game():
  notice="开战前保存失败，请检查存储空间或目录权限后重试。"
  return null
 current_encounter = encounter
 phase = "battle"
 var b = Rules.new()
 var prepared=[]
 for unit in chosen:
  var actor=unit.duplicate(true)
  actor.merge(character_stats(unit.id),true)
  prepared.append(actor)
 b.start_battle(prepared,encounter,relics+collection)
 return b

func resolve_battle(b) -> bool:
 if phase != "battle" or b.outcome == "" or current_encounter<0:return false
 for u in roster:
  for a in b.actors:
   if u.id==a.id:
    u.hp = a.hp
    u.mp = a.mp
 if route.region!="":route.completed=true
 encounters[current_encounter] = "cleared" if b.outcome=="victory" else "failed"
 if b.outcome == "gameover":
  phase = "gameover"
  notice = "团长阵亡。可读取远征前存档。"
 elif b.outcome == "victory":
  phase = "reward"
  var available = REWARDS.duplicate(true)
  choices = []
  for i in range(3):
   var index = rng.randi_range(0,available.size()-1)
   choices.append(available.pop_at(index))
  notice = "战斗胜利。选择一份战利品。"
 else:
  phase = "world"
  notice = "出战队伍全灭。幸存留守者接续远征；该遭遇已无法重试。"
 current_encounter = -1
 save_game()
 return true

func choose_reward(index: int) -> bool:
 if phase != "reward" or index<0 or index>=choices.size():return false
 var reward = choices[index]
 if reward.type == "relic":
  relics.append(reward.id)
  if reward.id == "lens":silver += 30
 elif reward.id == "silver":silver += 65
 elif reward.id == "medicine":supplies += 2
 elif reward.type == "equipment":
  equipment.append({"id":reward.id,"owner":""})
 notice = "获得 %s。继续深入，或前往北方渡口撤离。"%reward.name
 choices = []
 phase = "world"
 save_game()
 return true

func extract(indices: Array) -> bool:
 if phase != "world" or indices.size()>2:return false
 if route.region!="" and not at_node("extract"):return false
 var seen = []
 for i in indices:
  if i is not int or i<0 or i>=relics.size() or i in seen:return false
  seen.append(i)
 for i in indices:collection.append(relics[i])
 var converted = (relics.size()-indices.size())*25
 silver += converted
 relics = []
 phase = "camp"
 notice = "远征结束：保留 %d 件宝物，其余兑换 %d 银币。幸存队员已休整。"%[indices.size(),converted]
 for u in roster:
  if u.hp>0:
   u.hp = u.max_hp
   u.mp = u.max_mp
 save_game()
 return true

func use_supply() -> bool:
 if phase != "world" or supplies<=0:return false
 supplies -= 1
 for u in roster:
  if u.hp>0:
   u.hp = mini(u.max_hp,u.hp+int(u.max_hp*0.3))
   u.mp = mini(u.max_mp,u.mp+int(u.max_mp*0.3))
 notice = "消耗 1 份补给，所有存活队员恢复 30% 生命与法力。"
 save_game()
 return true

func visit_event() -> bool:
 if phase != "world" or event_used:return false
 event_used = true
 supplies += 1
 silver += 15
 notice = "废弃驿站：你从旧医箱里找到 1 份补给与 15 银币。"
 save_game()
 return true

func to_data(include_snapshot: bool = true) -> Dictionary:
 var units = roster.duplicate(true)
 for u in units:u.erase("cell")
 var data = {"version":2,"trial_equipment_claimed":trial_equipment_claimed,"equipment":equipment.duplicate(true),"roster":units,"phase":phase,"encounters":encounters.duplicate(),"relics":relics.duplicate(),"collection":collection.duplicate(),"silver":silver,"supplies":supplies,"expedition":expedition,"world_position":world_position.duplicate(),"event_used":event_used,"choices":choices.duplicate(true),"notice":notice,"rng_state":str(rng.state),"route":route.data() if route.region!="" else {},"books":books.duplicate(),"purchases":purchases.duplicate(),"recruits":recruits.duplicate()}
 if include_snapshot:data["snapshot"] = snapshot.duplicate(true)
 return data

func is_number(value) -> bool:
 return (value is int or value is float) and is_finite(float(value))

func load_data(data: Dictionary) -> bool:
 if data.get("version",0)!=1 and data.get("version",0)!=2:return false
 var migrated=data.get("version")==1
 data=data.duplicate(true)
 if not data.get("roster") is Array or data.roster.is_empty() or data.roster.size()>10:return false
 if not data.get("encounters") is Array or data.encounters.size()!=3:return false
 if data.get("phase","") not in ["camp","world","reward","gameover"]:return false
 var ids = []
 var has_hero = false
 for u in data.roster:
  if not u is Dictionary:return false
  for key in ["id","name","role","hp","max_hp","mp","max_mp","power","range","speed","side","ap"]:
   if not u.has(key):return false
  for key in ["hp","max_hp","mp","max_mp","power","range","speed","side","ap"]:
   if not is_number(u[key]):return false
  if not u.id is String or not u.name is String or not u.role is String:return false
  if u.has("profession") and not u.profession is String:return false
  var job=Professions.job_id(u)
  if not Professions.JOBS.has(job) or (job=="hero")!=(u.id=="hero"):return false
  for key in ["base_power","base_range","base_speed"]:
   if not migrated and not u.has(key):return false
   if u.has(key) and (not is_number(u[key]) or u[key]<0):return false
  for key in ["identity","appearance"]:
   if u.has(key) and not u[key] is String:return false
  if u.id in ids or u.max_hp<=0 or u.hp<0 or u.hp>u.max_hp or u.max_mp<0 or u.mp<0 or u.mp>u.max_mp:return false
  ids.append(u.id)
  if u.id=="hero":has_hero=true
 if not has_hero:return false
 for key in ["relics","collection","choices","world_position"]:
  if not data.get(key) is Array:return false
 if data.world_position.size()!=2:return false
 for coordinate in data.world_position:
  if not is_number(coordinate):return false
 for encounter in data.encounters:
  if encounter not in ["open","cleared","failed"]:return false
 for key in ["silver","supplies","expedition"]:
  if not is_number(data.get(key,0)) or data.get(key,0)<0:return false
 if not data.get("snapshot",{}) is Dictionary:return false
 for id in data.relics+data.collection:
  if id not in ["ember","spring","lens"]:return false
 for reward in data.choices:
  if not reward is Dictionary:return false
  var normalized=reward.duplicate(true)
  if normalized.get("id")=="sword" and normalized.get("desc")=="永久强化一名存活队员：攻击 +3":
   normalized.desc=REWARDS[-1].desc
  if not REWARDS.any(func(r):return r==normalized):return false
 if data.phase=="reward" and data.choices.size()!=3:return false
 var saved_equipment=data.get("equipment",[])
 if not saved_equipment is Array:return false
 var owners=[]
 for item in saved_equipment:
  if not item is Dictionary or not Professions.ITEMS.has(item.get("id","")) or not item.get("owner") is String:return false
  if item.owner!="":
   var slot_key=item.owner+":"+Professions.ITEMS[item.id].slot
   if item.owner not in ids or slot_key in owners:return false
   owners.append(slot_key)
 var next_route=Route.new()
 var saved_route=data.get("route",{})
 if not saved_route is Dictionary:return false
 if not saved_route.is_empty() and not next_route.restore(saved_route):return false
 for key in ["books","purchases","recruits"]:
  if not data.get(key,[]) is Array:return false
 for id in data.get("books",[]):
  if id not in ["fury","focus"] and not Professions.SKILLS.has(id):return false
 for u in data.roster:
  if not u.get("learned",[]) is Array:return false
  for id in u.get("learned",[]):
   if id not in ["fury","focus"] and not Professions.SKILLS.has(id):return false
 var saved_snapshot=data.get("snapshot",{})
 if not saved_snapshot.is_empty():
  if not saved_snapshot.get("snapshot",{}) is Dictionary or not saved_snapshot.get("snapshot",{}).is_empty():return false
  var validator=get_script().new(save_path)
  if not validator.load_data(saved_snapshot):return false
  data.snapshot=validator.to_data(false)
 for u in data.roster:
  if migrated:
   u.erase("base_power");u.erase("base_range");u.erase("base_speed")
   for item in saved_equipment:
    if item.owner==u.id:u.power-=Professions.ITEMS[item.id].power
  Professions.normalize(u)
 trial_equipment_claimed=bool(data.get("trial_equipment_claimed",not migrated))
 route=next_route
 books=data.get("books",[]).duplicate()
 purchases=data.get("purchases",[]).duplicate()
 recruits=data.get("recruits",[]).duplicate()
 equipment=saved_equipment.duplicate(true)
 roster = data.roster.duplicate(true)
 for u in roster:u.cell = Vector2i.ZERO
 refresh_stats()
 phase = data.phase
 encounters = data.encounters.duplicate()
 relics = data.relics.duplicate()
 collection = data.collection.duplicate()
 choices = data.choices.duplicate(true)
 for reward in choices:
  if reward.id=="sword":reward.desc=REWARDS[-1].desc
 silver = int(data.get("silver",0))
 supplies = int(data.get("supplies",0))
 expedition = int(data.get("expedition",0))
 world_position = data.world_position.duplicate()
 event_used = bool(data.get("event_used",false))
 snapshot = data.get("snapshot",{}).duplicate(true)
 notice = data.get("notice","")
 rng.state = int(data.get("rng_state",str(reward_seed)))
 current_encounter = -1
 return true

func save_game() -> bool:
 # Battles are never checkpointed midway; reload returns to pre-battle world save.
 if phase == "battle":return false
 var file = FileAccess.open(save_path+".tmp",FileAccess.WRITE)
 if file == null:return false
 var data=to_data()
 data["saved_at"]=Time.get_datetime_string_from_system(false,true)
 file.store_string(JSON.stringify(data))
 file.flush()
 var write_error=file.get_error()
 file.close()
 if write_error!=OK:
  DirAccess.remove_absolute(save_path+".tmp")
  return false
 return DirAccess.rename_absolute(save_path+".tmp",save_path)==OK

func load_game() -> bool:
 if not FileAccess.file_exists(save_path):return false
 var parser=JSON.new()
 if parser.parse(FileAccess.get_file_as_string(save_path))!=OK:return false
 var data = parser.data
 if not data is Dictionary:return false
 return load_data(data)

func restore_snapshot() -> bool:
 if snapshot.is_empty():return false
 var previous = snapshot.duplicate(true)
 if not load_data(previous):return false
 snapshot = previous
 notice = "已读取远征前存档。"
 save_game()
 return true

func visual_profile(character_id: String) -> Dictionary:
 for unit in roster:
  if unit.id!=character_id:continue
  var profile={"appearance":unit.get("appearance",unit.id),"mainhand":"","offhand":"","armor":""}
  for item in equipment:
   if item.owner==character_id:profile[Professions.ITEMS[item.id].slot]=item.id
  return profile
 return {}

func character_stats(character_id: String) -> Dictionary:
 for unit in roster:
  if unit.id==character_id:return Professions.stats(unit,equipment)
 return {}

func refresh_stats():
 for unit in roster:unit.merge(Professions.stats(unit,equipment),true)

func equipped_index(character_id: String,slot: String="mainhand") -> int:
 for i in range(equipment.size()):
  if equipment[i].owner==character_id and Professions.ITEMS[equipment[i].id].slot==slot:return i
 return -1

func preview_equipment(index: int,character_id: String) -> Dictionary:
 if index<0 or index>=equipment.size():return {}
 var preview=equipment.duplicate(true)
 var slot=Professions.ITEMS[preview[index].id].slot
 for item in preview:
  if item.owner==character_id and Professions.ITEMS[item.id].slot==slot:item.owner=""
 preview[index].owner=character_id
 for unit in roster:
  if unit.id==character_id:return Professions.stats(unit,preview)
 return {}

func equip_item(index: int,character_id: String) -> bool:
 if phase not in ["camp","world"] or index<0 or index>=equipment.size():return false
 if not roster.any(func(u):return u.id==character_id and u.hp>0):return false
 var slot=Professions.ITEMS[equipment[index].id].slot
 var previous=equipped_index(character_id,slot)
 if previous>=0:equipment[previous].owner=""
 equipment[index].owner=character_id
 refresh_stats()
 save_game()
 return true

func unequip_item(character_id: String,slot: String="mainhand") -> bool:
 if phase not in ["camp","world"]:return false
 var index=equipped_index(character_id,slot)
 if index<0:return false
 equipment[index].owner=""
 refresh_stats()
 save_game()
 return true

func change_profession(character_id: String,job: String) -> bool:
 if phase!="camp" or not Professions.JOBS.has(job) or job=="hero" or character_id=="hero":return false
 for unit in roster:
  if unit.id!=character_id or unit.hp<=0:continue
  unit.profession=job
  unit.role=Professions.JOBS[job].name
  refresh_stats()
  notice="%s 已转职为 %s；已学技能与装备保留。"%[unit.name,unit.role]
  save_game()
  return true
 return false

func claim_trial_equipment() -> bool:
 if phase!="camp" or trial_equipment_claimed:return false
 for id in Professions.ITEMS:
  if id!="sword":equipment.append({"id":id,"owner":""})
 trial_equipment_claimed=true
 save_game()
 return true

func active_relics() -> Array:
 var result=[]
 for id in relics+collection:
  if id not in result:result.append(id)
 return result

func start_region(id: String) -> bool:
 if id not in Route.REGIONS.map(func(r):return r.id) or phase!="camp":return false
 if not depart():return false
 route.setup(id)
 purchases=[]
 recruits=[]
 save_game()
 return true

func enter_route(id: String) -> bool:
 if phase!="world" or not route.enter(id):return false
 var n=route.node(id)
 if n.kind=="event":
  silver+=25
  supplies+=1
  notice="旅人留下 25 银币与一份补给。"
  route.completed=true
 elif n.kind=="supply":
  supplies+=2
  notice="找到两份补给，可在背包中使用。"
  route.completed=true
 elif n.kind in ["shop","hire"]:
  route.completed=true
  notice="可以交易，或选择下一处地点离开。"
 save_game()
 return true

func at_node(kind: String) -> bool:
 return phase=="world" and route.region!="" and route.node(route.current).get("kind","")==kind

func buy(id: String) -> bool:
 if not at_node("shop") or not GOODS.has(id):return false
 var key=route.current+":"+id
 if key in purchases or silver<GOODS[id].price:return false
 silver-=GOODS[id].price
 purchases.append(key)
 if Professions.ITEMS.has(id):equipment.append({"id":id,"owner":""})
 elif id in ["fury","focus"] or Professions.SKILLS.has(id):books.append(id)
 else:relics.append(id)
 notice="购入 "+GOODS[id].name
 save_game()
 return true

func hire(index: int) -> bool:
 if not at_node("hire") or index<0 or index>1 or silver<55 or roster.size()>=10:return false
 var key=route.current+":"+str(index)
 if key in recruits:return false
 var unit=Rules.new().default_party()[2 if index==0 else 3].duplicate(true)
 unit.id="hire_%d_%s_%d"%[expedition,route.current,index]
 unit.name="林鸦" if index==0 else "青禾"
 roster.append(unit)
 recruits.append(key)
 silver-=55
 notice="%s 加入佣兵团。"%unit.name
 save_game()
 return true

func learn_book(index: int,character_id: String) -> bool:
 if phase not in ["camp","world"] or index<0 or index>=books.size():return false
 for u in roster:
  if u.id!=character_id or u.hp<=0:continue
  if not Professions.can_learn(u,books[index]):return false
  var learned=u.get("learned",[]).duplicate()
  if books[index] in learned:return false
  learned.append(books[index])
  u.learned=learned
  books.remove_at(index)
  notice="%s 学会了新技能。"%u.name
  save_game()
  return true
 return false
