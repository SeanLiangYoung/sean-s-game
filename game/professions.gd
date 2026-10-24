extends RefCounted
# Stable IDs are gameplay data; display names and character identities are independent.
const JOBS={
 "hero":{"name":"主角","skills":["strike","hero_burst","hero_heal"],"specialty":"可学所有技能；无职业装备增益或惩罚。主角光环随主手变化。"},
 "blade":{"name":"游剑客","skills":["dash","execute","blade_sweep"],"specialty":"击杀恢复1行动点，每次个人行动最多一次；短刃攻击+2；板甲行动点减半。"},
 "ranger":{"name":"荒原猎手","skills":["mark","sniper","ranger_volley"],"specialty":"相距至少3格时普攻伤害+3；猎弓攻击+2；板甲行动点减半。"},
 "medic":{"name":"行医者","skills":["heal","cleanse","medic_mend"],"specialty":"治疗+6；医杖治疗额外+4；板甲行动点减半。"},
 "engineer":{"name":"遗械师","skills":["trap","bomb","engineer_shot"],"specialty":"机关伤害+6；遗械弩攻击+2；板甲行动点-1。"},
 "warden":{"name":"盾卫","skills":["guard","bash","warden_ward"],"specialty":"援护承伤减免3；木盾防护额外+2；板甲无惩罚。"}}
const SKILLS={
 "strike":{"name":"破势","job":"hero","ap":3,"mp":8,"range":3,"target":"enemy","effect":"damage","desc":"单体攻击+14伤害"},
 "dash":{"name":"掠影突袭","job":"blade","ap":2,"mp":6,"range":2,"target":"enemy","effect":"damage","desc":"突进至目标邻近空格，攻击+4伤害"},
 "execute":{"name":"追斩","job":"blade","ap":2,"mp":6,"range":1,"target":"enemy","effect":"damage","desc":"攻击+6伤害；目标半血及以下额外+10"},
 "mark":{"name":"猎物标记","job":"ranger","ap":1,"mp":4,"range":4,"target":"enemy","effect":"mark","desc":"友军对目标的直接攻击伤害+5，至施法者下次行动"},
 "sniper":{"name":"狙击","job":"ranger","ap":3,"mp":8,"range":5,"target":"enemy","effect":"damage","desc":"单体攻击+10伤害"},
 "heal":{"name":"回春","job":"medic","ap":2,"mp":6,"range":3,"target":"ally","effect":"heal","desc":"恢复26生命，叠加治疗专精与医杖增益"},
 "cleanse":{"name":"净护","job":"medic","ap":2,"mp":6,"range":3,"target":"ally","effect":"shield","desc":"解除标记，并抵挡下一次伤害的10点，至施法者下次行动"},
 "trap":{"name":"布设机关","job":"engineer","ap":2,"mp":6,"range":3,"target":"cell","effect":"trap","desc":"空格布设机关：敌人踏入受20伤害并停止移动，每人最多1个"},
 "bomb":{"name":"震荡弹","job":"engineer","ap":3,"mp":8,"range":3,"target":"enemy","effect":"damage","desc":"目标及相邻敌人受到攻击+2伤害"},
 "guard":{"name":"援护","job":"warden","ap":2,"mp":6,"range":2,"target":"other_ally","effect":"guard","desc":"射程2内替友军承担一半直接伤害，至下次行动"},
 "bash":{"name":"盾击","job":"warden","ap":2,"mp":6,"range":1,"target":"enemy","effect":"damage","desc":"造成攻击伤害，目标下次行动少1行动点"}}
# Branches reuse proven combat effects with independent names, ranks and tuning.
const BRANCHES={
 "hero_burst":{"name":"破阵斩","job":"hero","base":"bomb","ap":3,"mp":10,"range":2,"target":"enemy","effect":"damage","desc":"目标及相邻敌人受到攻击+2伤害"},
 "hero_heal":{"name":"振奋","job":"hero","base":"heal","ap":2,"mp":8,"range":2,"target":"ally","effect":"heal","desc":"恢复26生命"},
 "blade_sweep":{"name":"回旋刃","job":"blade","base":"bomb","ap":3,"mp":8,"range":1,"target":"enemy","effect":"damage","desc":"目标及相邻敌人受到攻击+2伤害"},
 "ranger_volley":{"name":"散射","job":"ranger","base":"bomb","ap":3,"mp":8,"range":4,"target":"enemy","effect":"damage","desc":"目标及相邻敌人受到攻击+2伤害"},
 "medic_mend":{"name":"深度回春","job":"medic","base":"heal","ap":3,"mp":4,"range":2,"target":"ally","effect":"heal","desc":"恢复26生命，叠加职业及装备治疗增益；更节省法力"},
 "engineer_shot":{"name":"穿甲弩","job":"engineer","base":"sniper","ap":3,"mp":8,"range":4,"target":"enemy","effect":"damage","desc":"单体攻击+10伤害"},
 "warden_ward":{"name":"坚盾庇护","job":"warden","base":"cleanse","ap":2,"mp":6,"range":2,"target":"ally","effect":"shield","desc":"解除标记，抵挡下一次伤害的10点"}}
static var ALL_SKILLS=all_skills()
static func all_skills() -> Dictionary:
 var result=SKILLS.duplicate(true)
 result.merge(BRANCHES)
 return result

static func skill_rank(unit: Dictionary,id: String) -> int:
 return int(unit.get("skill_ranks",{}).get(id,0))

static func skill_bonus(unit: Dictionary,id: String) -> int:
 return maxi(0,skill_rank(unit,id)-1)*4

static func skill_cost(unit: Dictionary,id: String) -> int:
 return [30,45,75,0][clampi(skill_rank(unit,id),0,3)]

static func prerequisite(id: String) -> String:
 if not ALL_SKILLS.has(id):return ""
 var root=JOBS[ALL_SKILLS[id].job].skills[0]
 return "" if root==id else root

static func training_reason(unit: Dictionary,id: String) -> String:
 if not ALL_SKILLS.has(id) or not can_learn(unit,id):return "当前职业无法学习"
 if skill_rank(unit,id)>=3:return "已满级"
 var root=prerequisite(id)
 if skill_rank(unit,id)==0 and root!="" and skill_rank(unit,root)<2:return "需要"+ALL_SKILLS[root].name+" 2级"
 if unit.get("xp",0)<skill_cost(unit,id):return "经验不足"
 return ""

static func rank_description(unit: Dictionary,id: String,rank: int=-1) -> String:
 var skill=ALL_SKILLS[id]
 var level=skill_rank(unit,id) if rank<0 else rank
 var bonus=maxi(0,level-1)*4
 var base=skill.get("base",id)
 match base:
  "mark":return "友军直接攻击伤害 +%d，持续至施法者下次行动"%[5+bonus]
  "cleanse":return "解除标记；下次受击抵挡 %d 伤害"%[10+bonus]
  "guard":return "替2格内友军承担一半直接伤害，自身额外减伤 %d"%bonus
  "trap":return "机关伤害 %d，触发后停止移动"%[(26 if job_id(unit)=="engineer" else 20)+bonus]
  "heal":return "恢复 %d 生命，另计装备与被动增益"%[26+(6 if job_id(unit)=="medic" else 0)+bonus]
  _:return skill.desc+("；伤害额外 +%d"%bonus if bonus>0 else "")

static func grant_basic(unit: Dictionary):
 var root=JOBS[job_id(unit)].skills[0]
 if skill_rank(unit,root)==0:unit.skill_ranks[root]=1

const ITEMS={
 "sword":{"name":"遗铁刃","slot":"mainhand","kind":"sword","power":3,"range":1,"armor":0,"price":45},
 "dagger":{"name":"短刃","slot":"mainhand","kind":"dagger","power":2,"range":1,"armor":0,"price":40},
 "bow":{"name":"猎弓","slot":"mainhand","kind":"bow","power":2,"range":3,"armor":0,"price":45},
 "staff":{"name":"医杖","slot":"mainhand","kind":"staff","power":1,"range":2,"armor":0,"price":40},
 "crossbow":{"name":"遗械弩","slot":"mainhand","kind":"crossbow","power":3,"range":2,"armor":0,"price":50},
 "shield":{"name":"木盾","slot":"offhand","kind":"shield","power":0,"armor":2,"price":35},
 "leather":{"name":"皮甲","slot":"armor","kind":"leather","power":0,"armor":1,"price":30},
 "plate":{"name":"板甲","slot":"armor","kind":"plate","power":0,"armor":5,"price":60}}
const SLOTS={"mainhand":"主手","offhand":"副手","armor":"护甲"}
const AURAS={"sword":"锋芒 · 全队直接攻击伤害+2","dagger":"迅捷 · 全队速度+2","bow":"远望 · 全队普攻射程+1","staff":"复苏 · 全队行动开始恢复3生命","crossbow":"坚阵 · 全队防护+2"}

static func job_id(unit: Dictionary) -> String:
 if unit.has("profession"):return unit.profession
 for id in JOBS:
  if JOBS[id].name==unit.get("role",""):return id
 return "hero" if unit.get("role","")=="团长" else ""

static func normalize(unit: Dictionary):
 unit.profession=job_id(unit)
 unit.role=JOBS[unit.profession].name
 if not unit.has("identity"):unit.identity="团长" if unit.id=="hero" else "佣兵"
 if not unit.has("appearance"):unit.appearance=unit.id
 if not unit.has("base_power"):unit.base_power=unit.power
 if not unit.has("base_range"):unit.base_range=unit.range
 if not unit.has("base_speed"):unit.base_speed=unit.speed
 if not unit.has("learned"):unit.learned=[]
 if not unit.has("xp"):unit.xp=0
 if not unit.has("skill_ranks"):unit.skill_ranks={}
 grant_basic(unit)
 for id in unit.learned:
  if ALL_SKILLS.has(id) and skill_rank(unit,id)==0:unit.skill_ranks[id]=1

static func skills_for(unit: Dictionary) -> Array:
 var job=job_id(unit)
 if not JOBS.has(job):return []
 var result=[]
 for id in ALL_SKILLS:
  if skill_rank(unit,id)>0 and (job=="hero" or ALL_SKILLS[id].job==job):result.append(id)
 return result

static func can_learn(unit: Dictionary,id: String) -> bool:
 return id in ["fury","focus"] or (ALL_SKILLS.has(id) and (job_id(unit)=="hero" or ALL_SKILLS[id].job==job_id(unit)))

static func stats(unit: Dictionary,equipment: Array) -> Dictionary:
 var result={"power":unit.get("base_power",unit.power),"range":unit.get("base_range",unit.range),"speed":unit.get("base_speed",unit.speed),"armor":0,"max_ap":4,"heal_bonus":0,"mainhand":"","adaptation":[]}
 var job=job_id(unit)
 for entry in equipment:
  if entry.owner!=unit.id or not ITEMS.has(entry.id):continue
  var item=ITEMS[entry.id]
  result.power+=item.power
  result.armor+=item.armor
  if item.slot=="mainhand":
   result.range=item.range
   result.mainhand=item.kind
   if (job=="blade" and item.kind=="dagger") or (job=="ranger" and item.kind=="bow") or (job=="engineer" and item.kind=="crossbow"):
    result.power+=2;result.adaptation.append("职业武器攻击+2")
   if job=="medic" and item.kind=="staff":
    result.heal_bonus+=4;result.adaptation.append("医杖治疗+4")
  if job=="warden" and item.kind=="shield":
   result.armor+=2;result.adaptation.append("盾卫木盾防护+2")
  if item.kind=="plate":
   if job in ["blade","ranger","medic"]:
    result.max_ap=2;result.adaptation.append("板甲：行动点减半 4 → 2")
   elif job=="engineer":
    result.max_ap=3;result.adaptation.append("板甲：行动点 4 → 3")
 return result

static func aura_for(unit: Dictionary) -> String:
 return AURAS.get(unit.get("mainhand",""),"未装备主手，无光环")

static func item_description(id: String) -> String:
 var item=ITEMS[id]
 return "%s · 攻击+%d / 防护+%d%s"%[SLOTS[item.slot],item.power,item.armor," / 射程%d"%item.range if item.has("range") else ""]
