extends RefCounted
const Characters=preload("res://game/characters.gd")
const Jobs=preload("res://game/professions.gd")

static func stat_line(stats: Dictionary) -> String:
 return "攻击 %d · 射程 %d · 防护 %d · 速度 %d · 行动点 %d"%[stats.power,stats.range,stats.armor,stats.speed,stats.max_ap]

static func comparison(before: Dictionary,after: Dictionary) -> String:
 var result=[]
 for pair in [["power","攻击"],["range","射程"],["armor","防护"],["speed","速度"],["max_ap","行动点"]]:
  result.append("%s %d → %d"%[pair[1],before[pair[0]],after[pair[0]]])
 return " · ".join(result)

static func skill_details(host,parent: Control,unit: Dictionary):
 var relic_rules=host.battle
 if relic_rules==null:
  relic_rules=host.campaign.Rules.new()
  var uid=1
  for entry in host.campaign.relics+host.campaign.collection:
   relic_rules.relic_state.append(host.campaign.Relic.instance(entry,uid) if entry is String else entry.duplicate(true))
   uid+=1
 host.detail_section(parent,"当前技能")
 for id in Jobs.skills_for(unit):
  var skill=Jobs.ALL_SKILLS[id]
  parent.add_child(host.text_label(skill.name+" · %d点 / %d法力 · 射程%d"%[skill.ap,relic_rules.skill_mana_cost(unit,id),relic_rules.skill_range(unit,id)],17,host.TEAL))
  var description=Jobs.rank_description(unit,id)
  if skill.effect=="heal":
   var stats=host.campaign.character_stats(unit.id)
   var base=18 if skill.get("base",id)=="barrier" else 26
   var amount=base+Jobs.skill_bonus(unit,id)+stats.heal_bonus+(6 if unit.profession=="medic" else 0)+(8 if "fury" in unit.get("learned",[]) else 0)
   amount+=int(relic_rules.relic_modifier(unit,"heal"))
   amount=int(floor(amount*maxf(0.0,1.0+relic_rules.relic_modifier(unit,"healing_pct")/100.0)))
   description="恢复 %d 生命（以自身为目标，已计入职业、装备及遗物，条件天赋另见人物详情；基础%d）"%[amount,base]
   if skill.get("base",id)=="barrier":description+="；给予护盾吸收%d伤害"%[10+Jobs.skill_bonus(unit,id)+stats.shield_power+int(relic_rules.relic_modifier(unit,"shield_power"))]
  parent.add_child(host.text_label(description+"；每次个人行动限用一次",15,host.MUTED))
 for id in unit.get("learned",[]):
  if id in ["fury","focus"]:
   parent.add_child(host.text_label(host.Campaign.GOODS[id].name+" · "+host.Campaign.GOODS[id].desc,15,host.TEAL))
  elif id not in Jobs.skills_for(unit):
   parent.add_child(host.text_label(Jobs.ALL_SKILLS[id].name+" · 已学，转回对应职业后可用",15,host.MUTED))

static func role_page(host,parent: Control,unit: Dictionary):
 var stats=unit if host.battle!=null and not host.battle.find_actor(unit.id).is_empty() else host.campaign.character_stats(unit.id)
 parent.add_child(host.text_label("身份：%s · 职业：%s"%[unit.identity,unit.role],18,host.TEAL))
 parent.add_child(host.text_label("生命 %d / %d · 法力 %d / %d"%[unit.hp,unit.max_hp,unit.mp,unit.max_mp],19))
 parent.add_child(host.text_label(stat_line(stats),17))
 parent.add_child(host.text_label("角色基础：攻击%d · 速度%d · 裸装射程%d"%[unit.base_power,unit.base_speed,unit.base_range],15,host.MUTED))
 parent.add_child(host.text_label("普通攻击消耗2行动点；休息消耗剩余行动点恢复生命或法力。",15,host.MUTED))
 parent.add_child(host.text_label("职业专精："+Jobs.JOBS[unit.profession].specialty,16,host.TEAL))
 if not stats.get("adaptation",[]).is_empty():parent.add_child(host.text_label("装备适应性："+"；".join(stats.adaptation),16,host.GOLD))
 if unit.profession=="hero":aura_preview(host,parent,unit)
 var character=Characters.definition(unit)
 if not character.is_empty():
  host.detail_section(parent,"专属天赋 · "+character.talent)
  parent.add_child(host.text_label(character.effect,17,host.TEAL))
  host.detail_section(parent,"人物背景 · "+character.title)
  parent.add_child(host.text_label(character.story,17,host.MUTED))
  parent.add_child(host.text_label("遗物搭配："+character.relics,16,host.GOLD))
  if unit.profession!=character.job:parent.add_child(host.text_label("天赋随人物保留；指定技能需当前职业可用才会触发。",15,host.MUTED))
 host.detail_section(parent,"生效的遗物")
 host.show_relic_details(parent,true)

static func skills_page(host,parent: Control,unit: Dictionary):
 parent.add_child(host.text_label("职业技能树 · 可用经验 %d"%unit.get("xp",0),22,host.GOLD))
 parent.add_child(host.text_label("点击节点查看、解锁或强化 · 基础2级开放进阶 · 最高3级 · 同职业共享树，等级独立",14,host.MUTED))
 var tree=preload("res://game/skill_tree.gd").new()
 parent.add_child(tree)
 tree.setup(host,unit)
 var builds={"hero":"秘法共鸣＋裂纹符核：强化战技；军心回响维持法力。","blade":"血契共鸣＋收割骨笛：残血增伤、吸血、击杀回蓝。","ranger":"追猎共鸣＋静观瞳石：标记后全队集火，击杀衔接行动。","medic":"生息共鸣＋护生石：治疗续航，灵泉引流支援队友。","engineer":"遗械共鸣＋缚潮齿轮：强化机关与首次命中。","warden":"守誓共鸣＋守誓铜铃：自动护盾、盾下增伤与援护。"}
 parent.add_child(host.text_label("搭配思路："+builds.get(unit.profession,""),15,host.TEAL))
 skill_details(host,parent,unit)
 host.detail_section(parent,"技能书 · 为当前角色学习")
 parent.add_child(host.text_label("通用被动技能书可从商店与事件获得；职业技能通过经验解锁，旧书仍可学习。",15,host.MUTED))
 if host.campaign.books.is_empty():
  parent.add_child(host.text_label("暂无技能书。职业技能请在上方使用经验解锁。",16,host.MUTED))
 for i in host.campaign.books.size():
  var book_index=i
  var book_id=host.campaign.books[i]
  var good=host.Campaign.GOODS[book_id]
  var reason=""
  if host.battle!=null or host.campaign.phase not in ["camp","world"]:reason="当前阶段无法学习"
  elif unit.hp<=0:reason="已阵亡，无法学习"
  elif book_id in unit.get("learned",[]):reason="已学习"
  elif not Jobs.can_learn(unit,book_id):reason="当前职业无法学习"
  parent.add_child(host.text_label(good.name,18,host.GOLD))
  parent.add_child(host.text_label(good.desc,15,host.MUTED))
  var learn=host.button(good.name+" → "+unit.name+(" · "+reason if reason!="" else ""),func():
   if host.campaign.learn_book(book_index,unit.id):
    host.refresh_ui();host.show_party_menu("技能",unit.id))
  learn.disabled=reason!=""
  parent.add_child(learn)

static func aura_preview(host,parent: Control,unit: Dictionary):
 parent.add_child(host.text_label("团队能力来自全队遗物；个人遗物只影响佩戴者。装备只提供基础属性。",16,host.GOLD))

static func profession_page(host,parent: Control,unit: Dictionary):
 parent.add_child(host.text_label("身份："+unit.identity+" · 当前职业："+unit.role,19,host.TEAL))
 parent.add_child(host.text_label(Jobs.JOBS[unit.profession].specialty,16))
 if unit.profession=="hero":
  parent.add_child(host.text_label(unit.name+"的团长专属职业 · 可学习、使用所有职业技能；不享受其他职业专精。",16,host.MUTED))
  aura_preview(host,parent,unit)
  parent.add_child(host.button("查看主角技能 →",func():host.show_party_menu("技能",unit.id)))
  return
 host.detail_section(parent,"营地转职")
 parent.add_child(host.text_label("免费转职；保留装备、已学技能和当前生命/法力。普通职业只使用当前职业技能，通用被动始终可用。",16,host.MUTED))
 if host.campaign.phase!="camp":parent.add_child(host.text_label("返回营地后可转职。",16,host.GOLD))
 var before=host.campaign.character_stats(unit.id)
 for id in Jobs.JOBS:
  if id=="hero":continue
  var job_id=id
  var job=Jobs.JOBS[id]
  host.detail_section(parent,job.name+(" · 当前" if id==unit.profession else ""))
  parent.add_child(host.text_label(job.specialty,15,host.TEAL))
  var candidate=unit.duplicate(true)
  candidate.profession=id
  var after=host.campaign.stats_for(candidate,host.campaign.equipment)
  parent.add_child(host.text_label(comparison(before,after),15,host.MUTED))
  for skill_id in job.skills:
   var skill=Jobs.ALL_SKILLS[skill_id]
   parent.add_child(host.text_label(skill.name+" · "+skill.desc,15))
  var entry=host.button("转职为 "+job.name,func():
   if host.campaign.change_profession(unit.id,job_id):
    host.refresh_ui();host.show_party_menu("职业",unit.id))
  entry.disabled=host.campaign.phase!="camp" or host.battle!=null or unit.hp<=0 or id==unit.profession
  parent.add_child(entry)

static func equipment_page(host,parent: Control,unit: Dictionary):
 preload("res://game/equipment_menu.gd").page(host,parent,unit)
