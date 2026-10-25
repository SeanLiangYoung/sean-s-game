extends RefCounted
# Stable IDs are gameplay data; display names and character identities are independent.
const JOBS={
 "hero":{"name":"主角","skills":["strike","hero_burst","hero_heal","hero_sunder","hero_rally","hero_judgment"],"specialty":"可学所有技能；无职业装备增益或惩罚。团队效果由遗物提供。"},
 "blade":{"name":"游剑客","skills":["dash","execute","blade_sweep","blade_feint","blade_drain","blade_hunt"],"specialty":"击杀恢复1行动点，每次个人行动最多一次。"},
 "ranger":{"name":"荒原猎手","skills":["mark","sniper","ranger_volley","ranger_pin","ranger_expose","ranger_hunt"],"specialty":"相距至少3格时普攻伤害+3。"},
 "medic":{"name":"行医者","skills":["heal","cleanse","medic_mend","medic_barrier","medic_channel","medic_purge"],"specialty":"治疗+6。"},
 "engineer":{"name":"遗械师","skills":["trap","bomb","engineer_shot","engineer_snare","engineer_breaker","engineer_pulse"],"specialty":"机关伤害+6。"},
 "warden":{"name":"盾卫","skills":["guard","bash","warden_ward","warden_fortify","warden_rebuke","warden_rescue"],"specialty":"援护承伤减免3。"}}
const SKILLS={
 "strike":{"name":"破势","job":"hero","ap":3,"mp":8,"range":3,"target":"enemy","effect":"damage","desc":"单体攻击+14伤害"},
 "dash":{"name":"掠影突袭","job":"blade","ap":2,"mp":6,"range":2,"target":"enemy","effect":"damage","desc":"突进至目标邻近空格，攻击+4伤害"},
 "execute":{"name":"追斩","job":"blade","ap":2,"mp":6,"range":1,"target":"enemy","effect":"damage","desc":"攻击+6伤害；目标半血及以下额外+10"},
 "mark":{"name":"猎物标记","job":"ranger","ap":1,"mp":4,"range":4,"target":"enemy","effect":"mark","desc":"友军对目标的直接攻击伤害+5，至施法者下次行动"},
 "sniper":{"name":"狙击","job":"ranger","ap":3,"mp":8,"range":5,"target":"enemy","effect":"damage","desc":"单体攻击+10伤害"},
 "heal":{"name":"回春","job":"medic","ap":2,"mp":6,"range":3,"target":"ally","effect":"heal","desc":"恢复26生命，叠加治疗专精与遗物增益"},
 "cleanse":{"name":"净护","job":"medic","ap":2,"mp":6,"range":3,"target":"ally","effect":"shield","desc":"解除标记、破甲、中毒、寒冷与束缚，并抵挡下一次伤害的10点，至施法者下次行动"},
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
 "medic_mend":{"name":"深度回春","job":"medic","base":"heal","ap":3,"mp":4,"range":2,"target":"ally","effect":"heal","desc":"恢复26生命，叠加职业及遗物治疗增益；更节省法力"},
 "engineer_shot":{"name":"穿甲弩","job":"engineer","base":"sniper","ap":3,"mp":8,"range":4,"target":"enemy","effect":"damage","desc":"单体攻击+10伤害"},
 "warden_ward":{"name":"坚盾庇护","job":"warden","base":"cleanse","ap":2,"mp":6,"range":2,"target":"ally","effect":"shield","desc":"解除标记、破甲、中毒、寒冷与束缚，抵挡下一次伤害的10点"}}
const ADVANCED={
 "hero_sunder":{"name":"裂阵","job":"hero","ap":2,"mp":7,"range":2,"target":"enemy","effect":"damage","base":"sunder","desc":"攻击+6；使目标承受直接伤害+4，至自身下次行动","prerequisite":"hero_burst"},
 "hero_rally":{"name":"军心回响","job":"hero","ap":2,"mp":6,"range":3,"target":"ally","effect":"mana","base":"mana","desc":"为目标恢复10法力；不能超出法力上限","prerequisite":"hero_heal"},
 "hero_judgment":{"name":"终焉裁决","job":"hero","ap":3,"mp":11,"range":2,"target":"enemy","effect":"damage","base":"execute","desc":"攻击+6；半血目标额外+10；受标记目标额外+8","prerequisite":"hero_burst","marked_bonus":8},
 "blade_feint":{"name":"破绽突刺","job":"blade","ap":2,"mp":5,"range":1,"target":"enemy","effect":"damage","base":"sunder","desc":"攻击+6；使目标承受直接伤害+4","prerequisite":"execute"},
 "blade_drain":{"name":"饮血斩","job":"blade","ap":2,"mp":7,"range":1,"target":"enemy","effect":"damage","base":"drain","desc":"攻击+4；按实际伤害的30%恢复自身生命","prerequisite":"blade_sweep"},
 "blade_hunt":{"name":"猎影处决","job":"blade","ap":3,"mp":9,"range":2,"target":"enemy","effect":"damage","base":"execute","desc":"攻击+6；半血目标额外+10；受标记目标额外+8","prerequisite":"execute","marked_bonus":8},
 "ranger_pin":{"name":"钉足箭","job":"ranger","ap":2,"mp":6,"range":4,"target":"enemy","effect":"damage","base":"pin","desc":"攻击+2；目标下次行动少1行动点","prerequisite":"sniper"},
 "ranger_expose":{"name":"追猎印记","job":"ranger","ap":1,"mp":6,"range":5,"target":"enemy","effect":"mark","base":"mark","desc":"团队直接伤害+8；配合远程集火","prerequisite":"ranger_volley","mark_bonus":3},
 "ranger_hunt":{"name":"逐猎贯射","job":"ranger","ap":3,"mp":10,"range":5,"target":"enemy","effect":"damage","base":"sniper","desc":"攻击+10；受标记目标额外+8","prerequisite":"sniper","marked_bonus":8},
 "medic_barrier":{"name":"生息屏障","job":"medic","ap":3,"mp":9,"range":3,"target":"ally","effect":"heal","base":"barrier","desc":"恢复18生命并给予抵挡10伤害的护盾","prerequisite":"cleanse"},
 "medic_channel":{"name":"灵泉引流","job":"medic","ap":2,"mp":4,"range":3,"target":"other_ally","effect":"mana","base":"mana","desc":"为其他友军恢复10法力；需要友军协作","prerequisite":"medic_mend"},
 "medic_purge":{"name":"净罪之光","job":"medic","ap":2,"mp":7,"range":3,"target":"enemy","effect":"damage","base":"sunder","desc":"攻击+6；使目标承受直接伤害+4","prerequisite":"cleanse"},
 "engineer_snare":{"name":"重压机关","job":"engineer","ap":3,"mp":9,"range":3,"target":"cell","effect":"trap","base":"trap","desc":"强化机关伤害+8；触发后停止敌人移动","prerequisite":"bomb","trap_bonus":8},
 "engineer_breaker":{"name":"破甲爆弹","job":"engineer","ap":3,"mp":10,"range":3,"target":"enemy","effect":"damage","base":"bomb","desc":"目标及相邻敌人受到攻击+2，并承受直接伤害+4","prerequisite":"engineer_shot","expose":true},
 "engineer_pulse":{"name":"修复脉冲","job":"engineer","ap":2,"mp":7,"range":2,"target":"ally","effect":"heal","base":"barrier","desc":"恢复18生命并给予抵挡10伤害的护盾","prerequisite":"engineer_shot"},
 "warden_fortify":{"name":"壁垒誓言","job":"warden","ap":2,"mp":8,"range":2,"target":"other_ally","effect":"guard","base":"guard","desc":"分担附近友军一半直接伤害；自身额外减伤4","prerequisite":"bash","guard_bonus":4},
 "warden_rebuke":{"name":"震慑重击","job":"warden","ap":3,"mp":8,"range":1,"target":"enemy","effect":"damage","base":"pin","desc":"攻击+2与自身防护；目标下次行动少1行动点","prerequisite":"warden_ward","armor_damage":true},
 "warden_rescue":{"name":"守望救援","job":"warden","ap":3,"mp":8,"range":2,"target":"ally","effect":"heal","base":"barrier","desc":"恢复18生命并给予抵挡10伤害的护盾","prerequisite":"warden_ward"}}

static var ALL_SKILLS=all_skills()
static func all_skills() -> Dictionary:
 var result=SKILLS.duplicate(true)
 result.merge(BRANCHES)
 result.merge(ADVANCED)
 return result

static func skill_rank(unit: Dictionary,id: String) -> int:
 return int(unit.get("skill_ranks",{}).get(id,0))

static func skill_bonus(unit: Dictionary,id: String) -> int:
 return maxi(0,skill_rank(unit,id)-1)*4

static func skill_cost(unit: Dictionary,id: String) -> int:
 return [30,45,75,0][clampi(skill_rank(unit,id),0,3)]

static func prerequisite(id: String) -> String:
 if not ALL_SKILLS.has(id):return ""
 if ALL_SKILLS[id].has("prerequisite"):return ALL_SKILLS[id].prerequisite
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
  "mark":return "友军直接攻击伤害 +%d，持续至施法者下次行动"%[5+bonus+skill.get("mark_bonus",0)]
  "cleanse":return "解除标记、破甲、中毒、寒冷与束缚；下次受击抵挡 %d 伤害"%[10+bonus]
  "guard":return "替2格内友军承担一半直接伤害，自身额外减伤 %d"%[bonus+skill.get("guard_bonus",0)]
  "trap":return "机关伤害 %d，另计遗物；触发后停止移动"%[(26 if job_id(unit)=="engineer" else 20)+bonus+skill.get("trap_bonus",0)]
  "mana":return "恢复 %d 法力；不能超过法力上限"%[10+bonus]
  "barrier":return "恢复 %d 生命，并抵挡下次 %d 伤害；另计遗物"%[18+bonus,10+bonus]
  "heal":return "恢复 %d 生命，另计遗物与被动增益"%[26+(6 if job_id(unit)=="medic" else 0)+bonus]
  _:return skill.desc.replace("直接伤害+4","直接伤害+%d"%[4+bonus])+("；伤害额外 +%d"%bonus if bonus>0 else "")

static func grant_basic(unit: Dictionary):
 var root=JOBS[job_id(unit)].skills[0]
 if skill_rank(unit,root)==0:unit.skill_ranks[root]=1

const ITEMS={"sword":{"name":"低档遗铁刃","slot":"mainhand","kind":"sword","tier":1,"power":3,"armor":0,"price":30,"range":1},"runic_sword":{"name":"中档遗铁刃","slot":"mainhand","kind":"sword","tier":2,"power":4,"armor":0,"price":45,"range":1},"bastion_sword":{"name":"高档遗铁刃","slot":"mainhand","kind":"sword","tier":3,"power":5,"armor":0,"price":60,"range":1},"dagger":{"name":"低档短刃","slot":"mainhand","kind":"dagger","tier":1,"power":2,"armor":0,"price":30,"range":1},"blood_dagger":{"name":"中档短刃","slot":"mainhand","kind":"dagger","tier":2,"power":3,"armor":0,"price":45,"range":1},"wind_dagger":{"name":"高档短刃","slot":"mainhand","kind":"dagger","tier":3,"power":4,"armor":0,"price":60,"range":1},"bow":{"name":"低档猎弓","slot":"mainhand","kind":"bow","tier":1,"power":2,"armor":0,"price":30,"range":3},"longbow":{"name":"中档猎弓","slot":"mainhand","kind":"bow","tier":2,"power":3,"armor":0,"price":45,"range":3},"mark_bow":{"name":"高档猎弓","slot":"mainhand","kind":"bow","tier":3,"power":4,"armor":0,"price":60,"range":3},"staff":{"name":"低档医杖","slot":"mainhand","kind":"staff","tier":1,"power":1,"armor":0,"price":30,"range":2},"ward_staff":{"name":"中档医杖","slot":"mainhand","kind":"staff","tier":2,"power":2,"armor":0,"price":45,"range":2},"spring_staff":{"name":"高档医杖","slot":"mainhand","kind":"staff","tier":3,"power":3,"armor":0,"price":60,"range":2},"crossbow":{"name":"低档遗械弩","slot":"mainhand","kind":"crossbow","tier":1,"power":3,"armor":0,"price":30,"range":2},"snare_crossbow":{"name":"中档遗械弩","slot":"mainhand","kind":"crossbow","tier":2,"power":4,"armor":0,"price":45,"range":2},"siege_crossbow":{"name":"高档遗械弩","slot":"mainhand","kind":"crossbow","tier":3,"power":5,"armor":0,"price":60,"range":2},"shield":{"name":"低档木盾","slot":"offhand","kind":"shield","tier":1,"power":0,"armor":2,"price":30},"focus_guard":{"name":"中档木盾","slot":"offhand","kind":"shield","tier":2,"power":0,"armor":3,"price":45},"tower_shield":{"name":"高档木盾","slot":"offhand","kind":"shield","tier":3,"power":0,"armor":4,"price":60},"leather":{"name":"低档皮甲","slot":"armor","kind":"leather","tier":1,"power":0,"armor":1,"price":30},"scout_leather":{"name":"中档皮甲","slot":"armor","kind":"leather","tier":2,"power":0,"armor":2,"price":45},"ritual_leather":{"name":"高档皮甲","slot":"armor","kind":"leather","tier":3,"power":0,"armor":3,"price":60},"plate":{"name":"低档板甲","slot":"armor","kind":"plate","tier":1,"power":0,"armor":3,"price":30},"bulwark_plate":{"name":"中档板甲","slot":"armor","kind":"plate","tier":2,"power":0,"armor":4,"price":45},"veteran_plate":{"name":"高档板甲","slot":"armor","kind":"plate","tier":3,"power":0,"armor":5,"price":60},"healer_guard":{"name":"中档木盾","slot":"offhand","kind":"shield","tier":2,"power":0,"armor":3,"price":45,"legacy":true}}

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
 var result={"power":unit.get("base_power",unit.power),"range":unit.get("base_range",unit.range),"speed":unit.get("base_speed",unit.speed),"armor":0,"max_ap":4,"heal_bonus":0,"mainhand":"","skill_power":0,"trap_power":0,"shield_power":0,"mark_power":0,"mana_power":0,"kill_mp":0,"rest_hp":0.0,"rest_mp":0.0,"adaptation":[]}
 var job=job_id(unit)
 for entry in equipment:
  if entry.owner!=unit.id or not ITEMS.has(entry.id):continue
  var item=ITEMS[entry.id]
  result.power+=item.power
  result.armor+=item.armor
  if item.slot=="mainhand":
   result.range=item.range
   result.mainhand=item.kind
 result.range=maxi(1,result.range)
 result.speed=maxi(1,result.speed)
 return result

static func aura_for(unit: Dictionary) -> String:
 return "遗物提供团队效果；装备仅提供基础属性"

static func item_description(id: String) -> String:
 var item=ITEMS[id]
 var text="%s · 基础装备 · 攻击%+d / 防护%+d%s"%[SLOTS[item.slot],item.power,item.armor," / 射程%d"%item.range if item.has("range") else ""]
 var labels={"speed":"速度","skill_power":"伤害战技","heal_bonus":"治疗","trap_power":"机关伤害","shield_power":"护盾吸收","mark_power":"标记增伤","mana_power":"法力支援","kill_mp":"击杀回蓝","rest_mp":"每行动点回蓝比例"}
 for key in item.get("mods",{}):
  var value=item.mods[key]
  text+=" / "+labels.get(key,key)+( "%+d%%"%int(value*100) if key.begins_with("rest_") else "%+d"%value)
 return text
