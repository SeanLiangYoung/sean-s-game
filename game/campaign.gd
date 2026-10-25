extends RefCounted
const Professions=preload("res://game/professions.gd")
const Characters=preload("res://game/characters.gd")
const Rules = preload("res://game/rules.gd")
const Achievements=preload("res://game/achievements.gd")
var completed_difficulties: Array = []
var achievement_save_failed=false
var discovered_relics: Array = []
var discovery_save_failed=false
const OVERALL_DIFFICULTIES = ["普通","困难","噩梦","我想找死"]
var overall_difficulty = 0
var save_path = "user://ashbound-save.json"
const Relic=preload("res://game/relics.gd")
static func equipment_rewards() -> Array:
 var result=[]
 for id in Professions.ITEMS:
  if id=="sword" or Professions.ITEMS[id].get("legacy",false):continue
  result.append({"id":id,"name":Professions.ITEMS[id].name,"type":"equipment","desc":Professions.item_description(id),"color":"#b4a1d1"})
 return result
static var REWARDS = Relic.rewards()+equipment_rewards()+[
 {"id":"silver","name":"佣金袋","type":"resource","desc":"获得 65 银币","color":"#dbbf78"},
 {"id":"medicine","name":"战地药箱","type":"resource","desc":"获得 2 份补给，可在野外恢复队伍","color":"#80c7b2"},
 {"id":"sword","name":Professions.ITEMS.sword.name,"type":"equipment","desc":Professions.item_description("sword"),"color":"#b4a1d1"}]
const Route = preload("res://game/route.gd")
const LEGACY_GOODS = {"sword":{"name":"遗铁刃","price":45,"desc":"武器 · 攻击 +3"},"ember":{"name":"余烬徽印","price":70,"desc":"遗物 · 全队攻击与伤害战技 +4"},"spring":{"name":"旧世泉核","price":60,"desc":"遗物 · 休息恢复提升"},"fury":{"name":"技能书 · 破阵","price":35,"desc":"学习后伤害战技 +8；治疗战技 +8"},"focus":{"name":"技能书 · 调息","price":30,"desc":"学习后每点休息行动额外恢复 2%"}}
static func goods_catalog() -> Dictionary:
 var result=LEGACY_GOODS.duplicate(true)
 for id in Relic.CATALOG:
  result[id]={"name":Relic.CATALOG[id].name,"price":LEGACY_GOODS.get(id,{}).get("price",70),"desc":Relic.description(id)}
 for id in Professions.ITEMS:
  var item=Professions.ITEMS[id]
  result[id]={"name":item.name,"price":item.price,"desc":Professions.item_description(id)}
 for id in Professions.ALL_SKILLS:
  if id=="strike":continue
  var skill=Professions.ALL_SKILLS[id]
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
var cleared_regions: Array = []
var phase = "camp"
var encounters: Array = ["open","open","open"]
var relics: Array = []
var collection: Array = []
var choices: Array = []
var silver = 40
var supplies = 3
var snapshot: Dictionary = {}
var last_battle_summary: Dictionary = {}
var current_encounter = -1
var expedition = 0
var world_position = [0.0,5.0]
var notice = "整备队伍，穿过灰潮边境。"
var event_used = false
var reward_seed = 71023
var rng = RandomNumberGenerator.new()

func _init(destination: String = "user://ashbound-save.json"):
 save_path=destination
 roster = Characters.starting_party()
 for id in ["sword","dagger","bow","staff","crossbow","shield","leather","plate"]:equipment.append({"id":id,"owner":""})
 rng.randomize()
 sync_achievements()
 load_relic_discoveries()

func depart() -> bool:
 if phase != "camp":return false
 if not roster.any(func(u):return u.id=="hero" and u.hp>0):return false
 for u in roster:
  if u.hp > 0:
   u.hp = u.max_hp
   u.mp = u.max_mp
 last_battle_summary={}
 snapshot = to_data(false)
 expedition += 1
 phase = "world"
 route=Route.new()
 relics = []
 choices = []
 encounters = ["open","open","open"]
 event_used = false
 world_position = [0.0,5.0]
 notice = "远征开始。血量与法力不会在战后恢复。"
 save_game()
 return true

func make_battle(ids: Array, encounter: int):
 if phase != "world" or encounter<0 or encounter>=encounters.size() or encounters[encounter] != "open":return null
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
 normalize_relics()
 var config=battle_config()
 b.start_battle(prepared,int(config.get("tier",encounter)),relics+collection,config)
 return b

func resolve_battle(b) -> bool:
 if phase != "battle" or b.outcome == "" or current_encounter<0:return false
 last_battle_summary={"outcome":b.outcome,"members":[]}
 for actor in b.actors:
  if actor.side==0:
   last_battle_summary.members.append({"id":actor.id,"name":actor.name,"hp":actor.hp,"max_hp":actor.max_hp,"mp":actor.mp,"max_mp":actor.max_mp,"kills":int(actor.get("kills",0))})
 sync_relics(b.relic_state)
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
  if route.node(route.current).get("threat","")=="boss" and route.region not in cleared_regions:
   cleared_regions.append(route.region)
  phase = "reward"
  choices = []
  var equipment_pool=REWARDS.filter(func(reward):return reward.type=="equipment")
  choices.append(equipment_pool[rng.randi_range(0,equipment_pool.size()-1)].duplicate(true))
  for id in Relic.draft_rewards(rng,relics+collection,relics):
   var reward=REWARDS.filter(func(candidate):return candidate.type=="relic" and candidate.id==id)[0]
   choices.append(reward.duplicate(true))
  var resource_pool=REWARDS.filter(func(reward):return reward.type=="resource")
  choices.append(resource_pool[rng.randi_range(0,resource_pool.size()-1)].duplicate(true))
  var survivors=b.actors.filter(func(a):return a.side==0 and a.hp>0)
  var config=route.node(route.current) if route.seed_value>=0 else {}
  var pool=120+current_encounter*60 if config.is_empty() else 200+int(config.tier)*40+(40 if config.threat=="boss" else (20 if config.threat=="elite" else 0))
  if not config.is_empty():
   silver+=15+int(config.tier)*5+(25 if config.threat=="boss" else 0)
  var share=int(pool/maxi(1,survivors.size()))
  for unit in roster:
   for actor in survivors:
    if unit.id==actor.id:unit.xp+=share+int(actor.get("kills",0))*15
  notice = "战斗胜利！上阵幸存者每人获得 %d 经验，击杀额外奖励每名15经验。选择一份战利品。"%share
 else:
  phase = "world"
  notice = "出战队伍全灭。幸存留守者接续远征；该遭遇已无法重试。"
  if route.seed_value>=0 and route.node(route.current).get("threat","")=="boss":
   phase="camp"
   relics=[]
   for u in roster:
    if u.hp>0:u.hp=u.max_hp;u.mp=u.max_mp
   notice="首领战失利：留守队员撤回营地，本次远征遗物全部遗失；阵亡队员不会复活。"
 if campaign_completed():notice="全部通关！星陨监守已被击败，六片区域的远征全部完成。选择战利品后可继续探索。"
 current_encounter = -1
 save_game()
 return true

func choose_reward(index: int,owner: String="") -> bool:
 if phase != "reward" or index<0 or index>=choices.size():return false
 var reward = choices[index]
 if reward.type == "relic":
  if not acquire_relic(reward.id,owner if Relic.definition(reward.id).scope=="personal" else ""):return false
 elif reward.id == "silver":silver += 65
 elif reward.id == "medicine":supplies += 2
 elif reward.type == "equipment":
  equipment.append({"id":reward.id,"owner":""})
 notice = "获得 %s。继续深入，或前往北方渡口撤离。"%reward.name
 if campaign_completed():notice="全部通关！星陨遗城已平定。可继续探索，或撤离带回宝物。"
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
   var healing_pct=0.0
   var seen=[]
   for entry in relics+collection:
    var definition=Relic.definition(entry)
    var id=Relic.id_of(entry)
    if id in seen or (definition.scope=="personal" and entry.owner!=u.id):continue
    seen.append(id)
    healing_pct+=float(definition.mods.get("healing_pct",0))
   var applicable=(relics+collection).filter(func(entry):return Relic.definition(entry).scope=="team" or (entry is Dictionary and entry.owner==u.id))
   healing_pct+=Relic.resonance_modifier(applicable,"healing_pct")
   var healing_scale=maxf(0.0,1.0+healing_pct/100.0)
   u.hp = mini(u.max_hp,u.hp+int(u.max_hp*0.3*healing_scale))
   u.mp = mini(u.max_mp,u.mp+int(u.max_mp*0.3))
 notice = "消耗 1 份补给，所有存活队员恢复生命与法力（基础30%，生命恢复受遗物代价影响）。"
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
 var data = {"version":9,"discovered_relics":discovered_relics.duplicate(),"completed_difficulties":completed_difficulties.duplicate(),"overall_difficulty":overall_difficulty,"cleared_regions":cleared_regions.duplicate(),"trial_equipment_claimed":trial_equipment_claimed,"equipment":equipment.duplicate(true),"roster":units,"phase":phase,"encounters":encounters.duplicate(),"relics":relics.duplicate(true),"collection":collection.duplicate(true),"silver":silver,"supplies":supplies,"expedition":expedition,"world_position":world_position.duplicate(),"event_used":event_used,"choices":choices.duplicate(true),"notice":notice,"rng_state":str(rng.state),"route":route.data() if route.region!="" else {},"books":books.duplicate(),"purchases":purchases.duplicate(),"recruits":recruits.duplicate()}
 data["last_battle_summary"]=last_battle_summary.duplicate(true)
 if include_snapshot:data["snapshot"] = snapshot.duplicate(true)
 return data

func is_number(value) -> bool:
 return (value is int or value is float) and is_finite(float(value))

func valid_battle_summary(value) -> bool:
 if not value is Dictionary:return false
 if value.is_empty():return true
 if value.get("outcome","") not in ["victory","defeat","gameover"]:return false
 if not value.get("members") is Array or value.members.size()>5:return false
 var ids=[]
 for unit in value.members:
  if not unit is Dictionary:return false
  if not unit.get("id") is String or not unit.get("name") is String or unit.id in ids:return false
  ids.append(unit.id)
  for key in ["hp","max_hp","mp","max_mp","kills"]:
   if not is_number(unit.get(key)) or unit[key]<0:return false
  if unit.max_hp<=0 or unit.hp>unit.max_hp or unit.mp>unit.max_mp:return false
 return true

func load_data(data: Dictionary,persist_discoveries: bool=true) -> bool:
 if not valid_discoveries(data.get("discovered_relics",[])):return false
 if not valid_battle_summary(data.get("last_battle_summary",{})):return false
 if not Achievements.valid(data.get("completed_difficulties",[])):return false
 var saved_difficulty=data.get("overall_difficulty",0)
 if not is_number(saved_difficulty) or float(saved_difficulty)!=floor(float(saved_difficulty)) or int(saved_difficulty)<0 or int(saved_difficulty)>3:return false
 if not data.has("version") or not is_number(data.version) or float(data.version)!=floor(float(data.version)) or int(data.version) not in [1,2,3,4,5,6,7,8,9]:return false
 var saved_clears=data.get("cleared_regions",[])
 if not saved_clears is Array:return false
 var seen_clears=[]
 for id in saved_clears:
  if not id is String or id not in Route.REGIONS.map(func(r):return r.id) or id in seen_clears:return false
  seen_clears.append(id)
 if "ruins" in saved_clears and saved_clears.size()!=6:return false
 var migrated=data.get("version")==1
 data=data.duplicate(true)
 if not data.get("roster") is Array or data.roster.is_empty() or data.roster.size()>10:return false
 var next_route=Route.new()
 var saved_route=data.get("route",{})
 if not saved_route is Dictionary:return false
 if not saved_route.is_empty() and not next_route.restore(saved_route):return false
 var encounter_count=next_route.nodes.filter(func(n):return n.kind=="battle").size() if next_route.seed_value>=0 else 3
 if not data.get("encounters") is Array or data.encounters.size()!=encounter_count:return false
 if data.get("phase","") not in ["camp","world","reward","gameover"]:return false
 var ids = []
 var has_hero = false
 var character_ids=[]
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
  if data.version>=8 or u.has("character_id"):
   if not u.get("character_id") is String or not Characters.CATALOG.has(u.character_id):return false
   if (u.character_id in Characters.CAPTAINS)!=(u.id=="hero"):return false
   if u.has("legacy_identity") and not u.legacy_identity is bool:return false
   if data.version>=7 and u.character_id in character_ids and not u.get("legacy_identity",false):return false
   character_ids.append(u.character_id)
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
 var relic_uids=[]
 var relic_owners=[]
 for entry in data.relics+data.collection:
  if not entry is String and not entry is Dictionary:return false
  if not Relic.CATALOG.has(Relic.id_of(entry)):return false
  if entry is String:
   if Relic.definition(entry).scope!="team":return false
   continue
  var d=Relic.definition(entry)
  if not entry.get("owner") is String or not is_number(entry.get("uid")):return false
  if entry.uid<1 or float(entry.uid)!=floor(float(entry.uid)) or entry.uid in relic_uids:return false
  relic_uids.append(entry.uid)
  if not is_number(entry.get("remaining")):return false
  if float(entry.remaining)!=floor(float(entry.remaining)):return false
  if d.uses==0 and entry.remaining!=-1:return false
  if d.uses>0 and (entry.remaining<1 or entry.remaining>d.uses):return false
  if d.scope=="team" and entry.owner!="":return false
  if d.scope=="personal":
   if entry.owner not in ids or entry.owner in relic_owners:return false
   relic_owners.append(entry.owner)
 for reward in data.choices:
  if not reward is Dictionary:return false
  var normalized=reward.duplicate(true)
  if normalized.get("id")=="sword" and normalized.get("desc")=="永久强化一名存活队员：攻击 +3":
   normalized.desc=REWARDS[-1].desc
  if data.version<9:
   if normalized.get("id","")=="healer_guard" and normalized.get("type","")=="equipment":normalized.id="focus_guard"
   var candidates=REWARDS.filter(func(r):return r.id==normalized.get("id","") and r.type==normalized.get("type",""))
   if candidates.is_empty():return false
   normalized=candidates[0]
  if not REWARDS.any(func(r):return r==normalized):return false
 if data.phase=="reward" and data.choices.size() not in [3,5]:return false
 var saved_equipment=data.get("equipment",[])
 if not saved_equipment is Array:return false
 var owners=[]
 for item in saved_equipment:
  if not item is Dictionary or not Professions.ITEMS.has(item.get("id","")) or not item.get("owner") is String:return false
  if item.owner!="":
   var slot_key=item.owner+":"+Professions.ITEMS[item.id].slot
   if item.owner not in ids or slot_key in owners:return false
   owners.append(slot_key)
 for key in ["books","purchases","recruits"]:
  if not data.get(key,[]) is Array:return false
 for id in data.get("books",[]):
  if id not in ["fury","focus"] and not Professions.ALL_SKILLS.has(id):return false
 for u in data.roster:
  if data.version>=3 and (not u.has("xp") or not u.has("skill_ranks")):return false
  if not is_number(u.get("xp",0)) or u.get("xp",0)<0 or float(u.get("xp",0))!=floor(float(u.get("xp",0))):return false
  if not u.get("skill_ranks",{}) is Dictionary:return false
  for id in u.get("skill_ranks",{}):
   var rank=u.skill_ranks[id]
   if not Professions.ALL_SKILLS.has(id) or not is_number(rank):return false
   if rank<1 or rank>3 or float(rank)!=floor(float(rank)):return false
  if not u.get("learned",[]) is Array:return false
  for id in u.get("learned",[]):
   if id not in ["fury","focus"] and not Professions.ALL_SKILLS.has(id):return false
 var saved_snapshot=data.get("snapshot",{})
 if not saved_snapshot.is_empty():
  if not saved_snapshot.get("snapshot",{}) is Dictionary or not saved_snapshot.get("snapshot",{}).is_empty():return false
  var validator=get_script().new(save_path)
  if not validator.load_data(saved_snapshot,false):return false
  data.snapshot=validator.to_data(false)
 for u in data.roster:
  if migrated:
   u.erase("base_power");u.erase("base_range");u.erase("base_speed")
   for item in saved_equipment:
    if item.owner==u.id:u.power-=Professions.ITEMS[item.id].power
  if data.version<3 and not u.has("skill_ranks"):
   u.skill_ranks={}
   for id in Professions.JOBS[Professions.job_id(u)].skills:
    if not Professions.BRANCHES.has(id) and not Professions.ADVANCED.has(id):u.skill_ranks[id]=1
  Professions.normalize(u)
  if data.version<7 or not u.has("character_id"):
   Characters.migrate(u)
   u.legacy_identity=true
 trial_equipment_claimed=bool(data.get("trial_equipment_claimed",not migrated))
 overall_difficulty=int(saved_difficulty)
 cleared_regions=saved_clears.duplicate()
 for rank in data.get("completed_difficulties",[]):
  if int(rank) not in completed_difficulties:completed_difficulties.append(int(rank))
 route=next_route
 books=data.get("books",[]).duplicate()
 purchases=data.get("purchases",[]).duplicate()
 recruits=data.get("recruits",[]).duplicate()
 equipment=saved_equipment.duplicate(true)
 roster = data.roster.duplicate(true)
 for u in roster:u.cell = Vector2i.ZERO
 sync_achievements()
 phase = data.phase
 encounters = data.encounters.duplicate()
 relics = data.relics.duplicate(true)
 collection = data.collection.duplicate(true)
 normalize_relics()
 choices = data.choices.duplicate(true)
 if data.version<9:
  for i in choices.size():
   if choices[i].id=="healer_guard" and choices[i].type=="equipment":choices[i].id="focus_guard"
   var candidates=REWARDS.filter(func(reward):return reward.id==choices[i].id and reward.type==choices[i].type)
   if not candidates.is_empty():choices[i]=candidates[0].duplicate(true)
 for reward in choices:
  for canonical in REWARDS:
   if reward.id==canonical.id:reward.merge(canonical,true)
 silver = int(data.get("silver",0))
 supplies = int(data.get("supplies",0))
 expedition = int(data.get("expedition",0))
 world_position = data.world_position.duplicate()
 event_used = bool(data.get("event_used",false))
 snapshot = data.get("snapshot",{}).duplicate(true)
 last_battle_summary=data.get("last_battle_summary",{}).duplicate(true)
 notice = data.get("notice","")
 rng.state = int(data.get("rng_state",str(reward_seed)))
 current_encounter = -1
 load_relic_discoveries()
 for id in data.get("discovered_relics",[]):discover_relic(id,false)
 for entry in relics+collection:discover_relic(Relic.id_of(entry),false)
 for reward in choices:
  if reward.type=="relic":discover_relic(reward.id,false)
 if persist_discoveries:save_relic_discoveries()
 return true

func save_game() -> bool:
 # Battles are never checkpointed midway; reload returns to pre-battle world save.
 if phase == "battle":return false
 sync_achievements()
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
 if DirAccess.rename_absolute(save_path+".tmp",save_path)!=OK:return false
 save_relic_discoveries()
 achievement_save_failed=not Achievements.save_profile(save_path+".achievements",completed_difficulties)
 return true

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
  if unit.id==character_id:return stats_for(unit,equipment)
 return {}

func refresh_stats():
 for unit in roster:unit.merge(stats_for(unit,equipment),true)

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
  if unit.id==character_id:return stats_for(unit,preview)
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
  Professions.grant_basic(unit)
  refresh_stats()
  notice="%s 已转职为 %s；已学技能与装备保留。"%[unit.name,unit.role]
  save_game()
  return true
 return false

func claim_trial_equipment() -> bool:
 if phase!="camp" or trial_equipment_claimed:return false
 for id in ["sword","dagger","bow","staff","crossbow","shield","leather","plate"]:
  if id!="sword":equipment.append({"id":id,"owner":""})
 trial_equipment_claimed=true
 save_game()
 return true

func normalize_relics():
 var next_uid=1
 for entry in relics+collection:
  if entry is Dictionary:next_uid=maxi(next_uid,int(entry.uid)+1)
 for pool in [relics,collection]:
  for i in pool.size():
   if pool[i] is String:
    pool[i]=Relic.instance(pool[i],next_uid)
    next_uid+=1

func active_relics() -> Array:
 var result=[]
 for entry in relics+collection:
  var id=Relic.id_of(entry)
  if id not in result:result.append(id)
 return result

func personal_relic(owner: String) -> Dictionary:
 for entry in relics+collection:
  if entry is Dictionary and entry.owner==owner:return entry
 return {}

func acquire_relic(id: String,owner: String="") -> bool:
 if phase not in ["world","reward"] or not Relic.CATALOG.has(id):return false
 var d=Relic.CATALOG[id]
 if d.scope=="personal":
  if not roster.any(func(u):return u.id==owner and u.hp>0):return false
 elif owner!="":return false
 normalize_relics()
 var uid=1
 for entry in relics+collection:uid=maxi(uid,int(entry.uid)+1)
 if d.scope=="personal":
  for pool in [relics,collection]:
   for i in range(pool.size()-1,-1,-1):
    if pool[i].owner==owner:pool.remove_at(i)
 discover_relic(id)
 relics.append(Relic.instance(id,uid,owner))
 if id=="lens":silver+=30
 return true

func sync_relics(state: Array):
 for pool in [relics,collection]:
  for i in range(pool.size()-1,-1,-1):
   var found=state.filter(func(entry):return entry.uid==pool[i].uid)
   if found.is_empty():pool.remove_at(i)
   else:pool[i]=found[0].duplicate(true)

func difficulty_level() -> int:
 return mini(6,cleared_regions.size()+1)

func campaign_completed() -> bool:
 return "ruins" in cleared_regions

func region_unlocked(id: String) -> bool:
 return id!="ruins" or Route.REGIONS.all(func(r):return r.id=="ruins" or r.id in cleared_regions)

func start_region(id: String) -> bool:
 if not region_unlocked(id):return false
 if id not in Route.REGIONS.map(func(r):return r.id) or phase!="camp":return false
 if not depart():return false
 route.setup(id,int(rng.randi()))
 encounters=[]
 for n in route.nodes:
  if n.kind=="battle":encounters.append("open")
 purchases=[]
 recruits=[]
 save_game()
 return true

func enter_route(id: String) -> bool:
 if phase!="world" or not route.enter(id):return false
 var n=route.node(id)
 if n.kind=="event":
  if route.seed_value<0:
   silver+=25;supplies+=1;notice="旅人留下 25 银币与一份补给。"
  else:resolve_route_event(int(n.event))
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

# The saved purchase ledger, not a transient flag, owns the once-per-expedition offer.
func shop_price(id: String) -> int:
 if not GOODS.has(id):return 0
 var base=int(GOODS[id].price)
 if not Relic.CATALOG.has(id):return base
 for purchase in purchases:
  var parts=str(purchase).split(":")
  if parts.size()==2 and Relic.CATALOG.has(parts[1]):return base
 return maxi(1,base-15)

func buy(id: String,owner: String="") -> bool:
 if not at_node("shop") or id not in shop_inventory() or not GOODS.has(id) or Professions.ALL_SKILLS.has(id):return false
 var key=route.current+":"+id
 var price=shop_price(id)
 if key in purchases or silver<price:return false
 if Relic.CATALOG.has(id) and not acquire_relic(id,owner):return false
 silver-=price
 purchases.append(key)
 if Professions.ITEMS.has(id):equipment.append({"id":id,"owner":""})
 elif id in ["fury","focus"] or Professions.ALL_SKILLS.has(id):books.append(id)
 elif not Relic.CATALOG.has(id):return false
 notice="购入 "+GOODS[id].name
 save_game()
 return true

func select_captain(character_id: String) -> bool:
 if phase!="camp" or expedition!=0 or character_id not in Characters.CAPTAINS:return false
 roster[0]=Characters.create(character_id)
 refresh_stats()
 return true

func recruit_candidates() -> Array:
 # Stable catalog indexes keep buttons and purchase history deterministic.
 var result=[]
 for id in ["lin","qing","aling","pei","chi","ya","suo","bai","wenlan","li","tang","ji","yue","qin","luosui"]:result.append(id)
 return result

func can_hire(index: int) -> bool:
 var candidates=recruit_candidates()
 if not at_node("hire") or index<0 or index>=candidates.size() or silver<55 or roster.size()>=10:return false
 if route.current+":"+str(index) in recruits:return false
 return not roster.any(func(u):return u.get("character_id","")==candidates[index])

func hire(index: int) -> bool:
 if not can_hire(index):return false
 var unit=Characters.create(recruit_candidates()[index],"hire_%d_%s_%d"%[expedition,route.current,index])
 roster.append(unit)
 recruits.append(route.current+":"+str(index))
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
  if Professions.ALL_SKILLS.has(books[index]) and Professions.skill_rank(u,books[index])==0:u.skill_ranks[books[index]]=1
  books.remove_at(index)
  notice="%s 学会了新技能。"%u.name
  save_game()
  return true
 return false

func train_skill(character_id: String,skill_id: String) -> bool:
 if phase not in ["camp","world"]:return false
 for unit in roster:
  if unit.id!=character_id or unit.hp<=0:continue
  if Professions.training_reason(unit,skill_id)!="":return false
  var cost=Professions.skill_cost(unit,skill_id)
  unit.xp-=cost
  unit.skill_ranks[skill_id]=Professions.skill_rank(unit,skill_id)+1
  notice="%s 的 %s 达到%d级（消耗%d经验）。"%[unit.name,Professions.ALL_SKILLS[skill_id].name,unit.skill_ranks[skill_id],cost]
  save_game()
  return true
 return false

func shop_inventory() -> Array:
 if not at_node("shop"):return []
 return route.node(route.current).get("stock",GOODS.keys().filter(func(id):return not Professions.ALL_SKILLS.has(id))).duplicate()

func resolve_route_event(event_id: int):
 match event_id:
  0:
   silver+=30;supplies+=1;notice="迷途商旅：护送旅人穿过灰潮，获得30银币和1份补给。"
  1:
   for u in roster:
    if u.hp>0:u.xp+=20
   notice="古碑研习：存活队员各获得20经验，可用于技能搭配。"
  2:
   supplies+=2;notice="隐秘药圃：找到2份补给。"
  3:
   silver+=45;notice="沉船遗箱：找到45银币。"
  4:
   for u in roster:
    if u.hp>0:u.mp=mini(u.max_mp,u.mp+10)
   notice="灵泉营地：所有存活队员恢复10法力。"
  _:
   books.append("focus" if route.node(route.current).seed%2==0 else "fury")
   notice="旧日手稿：获得一本通用被动技能书。"

func encounter_title(index: int) -> String:
 if route.seed_value>=0:
  var n=route.node(route.current)
  var region_name=route.REGIONS.filter(func(r):return r.id==route.region)[0].name
  return region_name+" · "+{"normal":"遭遇","elite":"精英","boss":"首领"}.get(n.get("threat","normal"),"遭遇")
 return ["断桥哨站","古道伏击","灰潮深处"][clampi(index,0,2)]

func encounter_description(index: int) -> String:
 if route.seed_value<0:return ["外围哨站 · 3名敌人","古道伏击 · 4名敌人","灰潮深处 · 5名敌人"][clampi(index,0,2)]
 var n=route.node(route.current)
 return "第%d段 · 威胁%d · %s · 3—5名敌人 · 胜利获得经验和银币"%[n.depth+1,n.tier+1,{"normal":"普通遭遇","elite":"精英强化，奖励增加","boss":preload("res://game/regions.gd").definition(route.region).boss+" · "+preload("res://game/regions.gd").definition(route.region).intent}.get(n.threat,"普通遭遇")]

func battle_config() -> Dictionary:
 var config=route.node(route.current).duplicate(true) if route.seed_value>=0 else {}
 if not config.is_empty():config["campaign_difficulty"]=difficulty_level()
 config["overall_difficulty"]=overall_difficulty
 return config

func preview_enemies(index: int) -> Array:
 if index<0 or index>=encounters.size():return []
 var config=battle_config()
 var preview=Rules.new()
 preview.start_battle([],int(config.get("tier",index)),[],config)
 return preview.actors.filter(func(u):return u.side==1).duplicate(true)

func achievement_bonus() -> Dictionary:
 return Achievements.bonus(completed_difficulties)

func stats_for(unit: Dictionary,items: Array) -> Dictionary:
 var result=Professions.stats(unit,items)
 var bonus=achievement_bonus()
 result.power+=bonus.power
 result.armor+=bonus.armor
 return result

func sync_achievements():
 for rank in Achievements.load_profile(save_path+".achievements"):
  if int(rank) not in completed_difficulties:completed_difficulties.append(int(rank))
 if campaign_completed() and overall_difficulty not in completed_difficulties:
  completed_difficulties.append(overall_difficulty)
 completed_difficulties.sort()
 refresh_stats()

static func valid_discoveries(value) -> bool:
 if not value is Array:return false
 var seen=[]
 for id in value:
  if not id is String or not Relic.CATALOG.has(id) or id in seen:return false
  seen.append(id)
 return true

func load_relic_discoveries():
 var path=save_path+".relics"
 if not FileAccess.file_exists(path):return
 var parser=JSON.new()
 if parser.parse(FileAccess.get_file_as_string(path))!=OK or not valid_discoveries(parser.data):return
 for id in parser.data:
  if id not in discovered_relics:discovered_relics.append(id)

func save_relic_discoveries() -> bool:
 load_relic_discoveries()
 discovery_save_failed=not Achievements.save_profile(save_path+".relics",discovered_relics)
 return not discovery_save_failed

func discover_relic(id: String,persist: bool=true) -> bool:
 if not Relic.CATALOG.has(id) or id in discovered_relics:return false
 discovered_relics.append(id)
 if persist:save_relic_discoveries()
 return true

func discover_reward_relics():
 var changed=false
 for reward in choices:
  if reward.type=="relic":changed=discover_relic(reward.id,false) or changed
 if changed:save_relic_discoveries()

func relic_achievement_count() -> int:
 var count=0
 for threshold in [1,10,100,Relic.CATALOG.size()]:
  if discovered_relics.size()>=threshold:count+=1
 return count
