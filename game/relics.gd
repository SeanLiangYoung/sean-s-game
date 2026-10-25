extends RefCounted
# Positive and negative effects share one lifetime; no activation switch exists.
const Expansion=preload("res://game/relic_expansion.gd")
const BASE_CATALOG={
 "ember":{"name":"余烬徽印","scope":"team","uses":0,"benefit":"全队攻击与直接伤害战技 +4","risk":"战斗与补给的生命恢复减少25%","mods":{"damage":4,"healing_pct":-25},"color":"#ec9a5c"},
 "spring":{"name":"旧世泉核","scope":"team","uses":0,"benefit":"全队休息每点行动额外恢复2%生命与法力","risk":"每次受伤额外承受2点伤害","mods":{"rest_hp":0.02,"rest_mp":0.02,"taken":2},"color":"#80c7b2"},
 "lens":{"name":"测绘透镜","scope":"team","uses":0,"benefit":"获取时获得30银币","risk":"全队速度 -1；收藏不重复发放银币","mods":{"speed":-1},"color":"#97b7df"},
 "banner":{"name":"裂甲战旗","scope":"team","uses":0,"benefit":"全队攻击与直接伤害战技 +8","risk":"全队防护 -3，负防护会增加受伤","mods":{"damage":8,"armor":-3},"color":"#ec9a5c"},
 "bastion":{"name":"沉铁壁垒","scope":"team","uses":0,"benefit":"全队防护 +3","risk":"全队速度 -2","mods":{"armor":3,"speed":-2},"color":"#97b7df"},
 "hourglass":{"name":"逆流沙漏","scope":"team","uses":0,"benefit":"全队每次行动的行动点 +1","risk":"全队直接伤害 -6；生命恢复减少15%","mods":{"max_ap":1,"damage":-6,"healing_pct":-15},"color":"#dbbf78"},
 "mist":{"name":"远望雾灯","scope":"team","uses":0,"benefit":"全队普通攻击射程 +1","risk":"生命休息每点行动的恢复比例降低2%","mods":{"range":1,"rest_hp":-0.02},"color":"#80c7b2"},
 "echo":{"name":"回响棱镜","scope":"personal","uses":6,"trigger":"有敌方目标存活且法力足够时，直接伤害战技追加8点伤害（每次施法一次）","benefit":"直接伤害战技追加8点伤害","risk":"触发额外消耗3法力；法力不足则不触发","mods":{},"color":"#b4a1d1"},
 "candle":{"name":"续命烛芯","scope":"personal","uses":1,"trigger":"受到致命伤害时","benefit":"抵挡一次致命伤害，保留1生命","risk":"触发耗尽佩戴者全部法力","mods":{},"color":"#dbbf78"},
 "chalice":{"name":"噬血圣杯","scope":"personal","uses":8,"trigger":"佩戴者击杀敌人且生命未满时","benefit":"击杀恢复12生命","risk":"生命休息每点行动的恢复比例降低3%","mods":{"rest_hp":-0.03},"color":"#ec9a5c"},
 "thorn":{"name":"荆棘王冠","scope":"personal","uses":0,"benefit":"攻击与直接伤害战技 +6","risk":"每次受伤额外承受3点伤害","mods":{"damage":6,"taken":3},"color":"#ec9a5c"},
 "prism":{"name":"慈悲裂晶","scope":"personal","uses":8,"trigger":"治疗战技有效恢复生命时","benefit":"治疗战技恢复量 +12","risk":"每次治疗战技额外消耗3法力","mods":{"heal":12,"heal_mp":3},"color":"#80c7b2"},
 "fang":{"name":"饥渴獠牙","scope":"personal","uses":10,"trigger":"直接攻击或直接伤害战技命中时，每个目标一次","benefit":"该次伤害 +10","risk":"每次触发自身失去2生命，可能致命","mods":{},"color":"#ec9a5c"},
 "tide":{"name":"枯潮瓶","scope":"personal","uses":6,"trigger":"休息恢复法力且实际有恢复时","benefit":"法力休息每点行动额外恢复5%","risk":"生命休息每点行动的恢复比例降低4%","mods":{"rest_mp":0.05,"rest_hp":-0.04},"color":"#97b7df"},
 "shell":{"name":"碎誓甲壳","scope":"personal","uses":8,"trigger":"受到非零生命伤害时","benefit":"该次生命伤害减少10，最低0","risk":"速度 -2","mods":{"speed":-2},"color":"#97b7df"},
 "rune":{"name": "裂纹符核", "scope": "team", "uses": 0, "benefit": "伤害战技 +4", "risk": "全队普通攻击伤害 -2", "mods": {"skill_power": 4, "attack_power": -2}, "color": "#dbbf78"},
 "hunt":{"name": "逐猎罗盘", "scope": "team", "uses": 0, "benefit": "对被标记敌人直接伤害 +4", "risk": "全队防护 -1", "mods": {"marked_damage": 4, "armor": -1}, "color": "#dbbf78"},
 "wardbell":{"name": "守誓铜铃", "scope": "team", "uses": 0, "benefit": "护盾吸收 +4", "risk": "治疗量减少15%", "mods": {"shield_power": 4, "healing_pct": -15}, "color": "#dbbf78"},
 "reservoir":{"name": "蓄潮水囊", "scope": "team", "uses": 0, "benefit": "每点行动休息回蓝比例 +2%", "risk": "全队直接伤害 -2", "mods": {"rest_mp": 0.02, "damage": -2}, "color": "#dbbf78"},
 "boots":{"name": "流沙履印", "scope": "team", "uses": 0, "benefit": "全队速度 +2", "risk": "全队防护 -1", "mods": {"speed": 2, "armor": -1}, "color": "#dbbf78"},
 "bulwark":{"name": "沉城印玺", "scope": "team", "uses": 0, "benefit": "有护盾时受到伤害 -4", "risk": "全队普通攻击射程 -1（最低1）", "mods": {"shield_taken": -4, "range": -1}, "color": "#dbbf78"},
 "campfire":{"name": "苦火余薪", "scope": "team", "uses": 0, "benefit": "每点行动休息回血比例 +3%", "risk": "休息回蓝比例 -2%", "mods": {"rest_hp": 0.03, "rest_mp": -0.02}, "color": "#dbbf78"},
 "cog":{"name": "缚潮齿轮", "scope": "personal", "uses": 0, "benefit": "机关伤害 +8", "risk": "速度 -1", "mods": {"trap_power": 8, "speed": -1}, "color": "#80c7b2"},
 "wardstone":{"name": "护生石", "scope": "personal", "uses": 0, "benefit": "护盾吸收 +4", "risk": "伤害战技 -3", "mods": {"shield_power": 4, "skill_power": -3}, "color": "#80c7b2"},
 "well":{"name": "灵泉残页", "scope": "personal", "uses": 0, "benefit": "法力支援恢复量 +4", "risk": "防护 -2", "mods": {"mana_power": 4, "armor": -2}, "color": "#80c7b2"},
 "harvest":{"name": "收割骨笛", "scope": "personal", "uses": 0, "benefit": "击杀敌人恢复4法力", "risk": "生命恢复量减少25%", "mods": {"kill_mp": 4, "healing_pct": -25}, "color": "#80c7b2"},
 "leech":{"name": "噬生苔", "scope": "personal", "uses": 0, "benefit": "直接伤害按实际生命损失的15%回血", "risk": "每次受伤额外承受2点", "mods": {"lifesteal": 0.15, "taken": 2}, "color": "#80c7b2"},
 "focusstone":{"name": "静观瞳石", "scope": "personal", "uses": 0, "benefit": "标记附加伤害 +4", "risk": "普通攻击伤害 -3", "mods": {"mark_power": 4, "attack_power": -3}, "color": "#80c7b2"},
 "ironheart":{"name": "铁心契", "scope": "personal", "uses": 0, "benefit": "防护 +3", "risk": "法力支援恢复量 -4", "mods": {"armor": 3, "mana_power": -4}, "color": "#80c7b2"},
 "spark":{"name": "薪火戒", "scope": "personal", "uses": 0, "benefit": "治疗战技 +6", "risk": "速度 -2", "mods": {"heal": 6, "speed": -2}, "color": "#80c7b2"}
}
static var CATALOG=build_catalog()
static func build_catalog() -> Dictionary:
 var result=BASE_CATALOG.duplicate(true)
 result.merge(Expansion.ENTRIES)
 return result

# Callers pass only entries applicable to this actor, respecting personal binding.
static func resonance_counts(entries: Array) -> Dictionary:
 var counts={}
 var seen=[]
 for entry in entries:
  var id=id_of(entry)
  if id in seen or (entry is Dictionary and entry.get("remaining",-1)==0):continue
  seen.append(id)
  var family=definition(entry).get("family","")
  if family!="":counts[family]=int(counts.get(family,0))+1
 return counts

static func resonance_modifier(entries: Array,key: String) -> float:
 var counts=resonance_counts(entries)
 var value=0.0
 for family in counts:
  var d=Expansion.SETS[family]
  if counts[family]>=2:value+=float(d.two.get(key,0))
  if counts[family]>=4:value+=float(d.four.get(key,0))
 return value

static func resonance_description(entries: Array) -> String:
 var counts=resonance_counts(entries)
 var lines=[]
 for family in counts:
  var d=Expansion.SETS[family]
  lines.append("%s · %d/4件\n%s2件：%s\n%s4件：%s"%[d.name,counts[family],"◆ 已激活 " if counts[family]>=2 else "◇ 未激活 ",d.two_desc,"◆ 已激活 " if counts[family]>=4 else "◇ 未激活 ",d.four_desc])
 return "\n".join(lines) if not lines.is_empty() else "尚未形成遗物共鸣 · 同主题2/4件解锁组合收益"

static func id_of(entry) -> String:
 return entry if entry is String else str(entry.get("id",""))
static func definition(entry) -> Dictionary:
 return CATALOG.get(id_of(entry),{})
static func description(entry) -> String:
 var d=definition(entry)
 if d.is_empty():return "未知遗物"
 var family=d.get("family","")
 var theme=""
 if family!="":
  var set_data=Expansion.SETS[family]
  theme="\n共鸣 · "+set_data.name+"：2件 "+set_data.two_desc+"；4件 "+set_data.four_desc+"（全队遗物与本人个人遗物计数；遗物行动点最多+2，击杀回行动点最多1）"
 return ("全队遗物" if d.scope=="team" else "个人遗物 · 每人限1件")+"\n收益："+d.benefit+"\n代价："+d.risk+"\n"+("持续生效" if d.uses==0 else "触发："+d.trigger+" · %d次后损毁"%d.uses)+theme
static func instance(id: String,uid: int,owner: String="") -> Dictionary:
 return {"id":id,"uid":uid,"owner":owner,"remaining":CATALOG[id].uses if CATALOG[id].uses>0 else -1}
static func rewards() -> Array:
 var result=[]
 for id in CATALOG:
  var d=CATALOG[id]
  result.append({"id":id,"name":d.name,"type":"relic","desc":description(id),"color":d.color})
 return result

# The first slot advances this expedition, the second opens a different theme,
# and the third keeps the complete catalog available. Saved RNG owns every draw.
static func draft_rewards(rng: RandomNumberGenerator,held: Array,current_run: Array) -> Array:
 var owned=held.map(func(entry):return id_of(entry))
 var pool=CATALOG.keys().filter(func(id):return id not in owned)
 if pool.size()<3:pool=CATALOG.keys()
 var counts=resonance_counts(current_run)
 var focus=""
 var highest=0
 var leaders=[]
 for family in counts:
  if counts[family]>highest:highest=counts[family];leaders=[family]
  elif counts[family]==highest:leaders.append(family)
 if not leaders.is_empty():focus=leaders[rng.randi_range(0,leaders.size()-1)]
 var result=[]
 for slot in range(3):
  var candidates=[]
  if slot==0:
   var themes=Expansion.SETS.keys().filter(func(family):return (focus=="" or family==focus) and pool.any(func(id):return CATALOG[id].get("family","")==family and CATALOG[id].scope=="team"))
   if themes.is_empty():themes=Expansion.SETS.keys().filter(func(family):return pool.any(func(id):return CATALOG[id].get("family","")==family and CATALOG[id].scope=="team"))
   if not themes.is_empty():
    var family=themes[rng.randi_range(0,themes.size()-1)]
    candidates=pool.filter(func(id):return CATALOG[id].get("family","")==family and CATALOG[id].scope=="team")
   elif focus!="":candidates=pool.filter(func(id):return CATALOG[id].get("family","")==focus)
  elif slot==1:
   var first_family=CATALOG[result[0]].get("family","")
   var themes=Expansion.SETS.keys().filter(func(family):return family!=first_family and pool.any(func(id):return CATALOG[id].get("family","")==family and CATALOG[id].scope=="team"))
   # Keep a genuine alternative slot, but help an already chosen secondary theme reach two.
   var unfinished=themes.filter(func(family):return int(counts.get(family,0))==1)
   var established=themes.filter(func(family):return int(counts.get(family,0))>=2)
   if not unfinished.is_empty():themes=unfinished
   elif not established.is_empty():themes=established
   if not themes.is_empty():
    var family=themes[rng.randi_range(0,themes.size()-1)]
    candidates=pool.filter(func(id):return CATALOG[id].get("family","")==family and CATALOG[id].scope=="team")
  if candidates.is_empty():candidates=pool
  var id=candidates[rng.randi_range(0,candidates.size()-1)]
  result.append(id);pool.erase(id)
 return result
