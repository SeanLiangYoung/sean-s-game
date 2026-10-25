extends RefCounted
const Characters=preload("res://game/characters.gd")
const Compact=preload("res://game/compact_ui.gd")
const Jobs=preload("res://game/professions.gd")

static func stat_line(stats: Dictionary) -> String:
 return "攻击 %d · 射程 %d · 防护 %d · 速度 %d · 行动点 %d"%[stats.power,stats.range,stats.armor,stats.speed,stats.max_ap]

static func comparison(before: Dictionary,after: Dictionary) -> String:
 var result=[]
 for pair in [["power","攻击"],["range","射程"],["armor","防护"],["speed","速度"],["max_ap","行动点"]]:
  result.append("%s %d → %d"%[pair[1],before[pair[0]],after[pair[0]]])
 return " · ".join(result)

static func rules_for(host):
 var relic_rules=host.battle
 if relic_rules==null:
  relic_rules=host.campaign.Rules.new()
  var uid=1
  for entry in host.campaign.relics+host.campaign.collection:
   relic_rules.relic_state.append(host.campaign.Relic.instance(entry,uid) if entry is String else entry.duplicate(true))
   uid+=1
 return relic_rules

static func skill_reference(host,unit: Dictionary) -> String:
 var lines=[]
 var relic_rules=rules_for(host)
 lines.append("当前技能 · 消耗与实际效果")
 for id in Jobs.skills_for(unit):
  var skill=Jobs.ALL_SKILLS[id]
  lines.append(skill.name+" · %d点 / %d法力 · 射程%d"%[skill.ap,relic_rules.skill_mana_cost(unit,id),relic_rules.skill_range(unit,id)])
  var description=Jobs.rank_description(unit,id)
  if skill.effect=="heal":
   var stats=host.campaign.character_stats(unit.id)
   var base=18 if skill.get("base",id)=="barrier" else 26
   var amount=base+Jobs.skill_bonus(unit,id)+stats.heal_bonus+(6 if unit.profession=="medic" else 0)+(8 if "fury" in unit.get("learned",[]) else 0)
   amount+=int(relic_rules.relic_modifier(unit,"heal"))
   amount=int(floor(amount*maxf(0.0,1.0+relic_rules.relic_modifier(unit,"healing_pct")/100.0)))
   description="恢复 %d 生命（以自身为目标，已计入职业、装备及遗物，条件天赋另见人物详情；基础%d）"%[amount,base]
   if skill.get("base",id)=="barrier":description+="；给予护盾吸收%d伤害"%[10+Jobs.skill_bonus(unit,id)+stats.shield_power+int(relic_rules.relic_modifier(unit,"shield_power"))]
  lines.append(description+"；每次个人行动限用一次\n")
 for id in unit.get("learned",[]):
  if id in ["fury","focus"]:
   lines.append(host.Campaign.GOODS[id].name+" · "+host.Campaign.GOODS[id].desc)
  elif id not in Jobs.skills_for(unit):
   lines.append(Jobs.ALL_SKILLS[id].name+" · 已学，转回对应职业后可用")

 return "\n".join(lines)

static func role_page(host,parent: Control,unit: Dictionary):
 var stats=unit if host.battle!=null and not host.battle.find_actor(unit.id).is_empty() else host.campaign.character_stats(unit.id)
 Compact.metrics(host,parent,[["hp","%d / %d"%[unit.hp,unit.max_hp],"生命"],["mp","%d / %d"%[unit.mp,unit.max_mp],"法力"]],"CharacterMetrics")
 Compact.metrics(host,parent,[["attack",stats.power,"攻击"],["range",stats.range,"普攻射程"],["armor",stats.armor,"防护"],["speed",stats.speed,"速度"],["ap",stats.max_ap,"每次行动的行动点"]])
 var actions=HFlowContainer.new();actions.add_theme_constant_override("h_separation",8);parent.add_child(actions)
 for tab in ["装备","技能","职业"]:
  var target=tab;actions.add_child(Compact.symbolize(host.button("管理"+tab,func():host.show_party_menu(target,unit.id)),{"装备":"equipment","技能":"skill","职业":"profession"}[tab]))
 var character=Characters.definition(unit)
 if not character.is_empty():
  parent.add_child(host.text_label("天赋 · "+character.talent,16,host.TEAL))
  var bio=host.details_button(parent,"人物背景与天赋",character.title+"\n\n"+character.story+"\n\n"+character.talent+"："+character.effect+"\n\n遗物搭配："+character.relics+"\n\n天赋随人物保留；指定技能需当前职业可用才会触发。")
  bio.name="CharacterBiography"
 host.details_button(parent,"角色基础与职业规则","角色基础：攻击%d · 速度%d · 裸装射程%d\n\n职业专精："%[unit.base_power,unit.base_speed,unit.base_range]+Jobs.JOBS[unit.profession].specialty+"\n\n普通攻击消耗2行动点，休息消耗剩余行动点恢复生命或法力。\n团队能力来自全队遗物；个人遗物仅影响佩戴者。装备提供基础属性。")
 host.show_relic_details(parent,true)

static func skills_page(host,parent: Control,unit: Dictionary):
 Compact.metrics(host,parent,[["xp","可用经验 %d"%unit.get("xp",0),"当前角色技能经验；选择节点不消耗经验"]])
 var actions=HBoxContainer.new();actions.add_theme_constant_override("separation",8);parent.add_child(actions)
 var reference=host.details_button(actions,"当前技能与效果",skill_reference(host,unit));reference.name="SkillReference"
 var books=host.button("技能书 · %d本"%host.campaign.books.size(),func():book_page(host,unit))
 Compact.symbolize(books,"book","技能书 · %d本"%host.campaign.books.size(),str(host.campaign.books.size()));books.name="SkillBooks";actions.add_child(books)
 var tree=preload("res://game/skill_tree.gd").new();parent.add_child(tree);tree.setup(host,unit)

static func book_page(host,unit: Dictionary):
 host.open_modal(unit.name+" · 技能书","选择书籍学习 · 消耗1本 · 仅为当前角色生效")
 host.set_page_back(func():host.show_party_menu("技能",unit.id))
 var grid=Compact.grid(host.modal_body,2)
 if host.campaign.books.is_empty():host.modal_body.add_child(host.text_label("暂无技能书，可从商店与事件获得。职业技能可在技能树中使用经验解锁。",16,host.MUTED))
 for i in host.campaign.books.size():
  var book_index=i;var book_id=host.campaign.books[i];var good=host.Campaign.GOODS[book_id]
  var card=Compact.card(host,grid,good.name,host.GOLD,Compact.icon("skill"))
  var reason=""
  if host.battle!=null or host.campaign.phase not in ["camp","world"]:reason="当前阶段无法学习"
  elif unit.hp<=0:reason="已阵亡，无法学习"
  elif book_id in unit.get("learned",[]):reason="已学习"
  elif not Jobs.can_learn(unit,book_id):reason="当前职业无法学习"
  card.add_child(host.text_label(good.desc,14,host.TEAL))
  host.details_button(card,"效果详情",good.desc+"\n\n学习将消耗1本，仅为当前角色生效；同一本书每名角色只能学习一次。职业技能需当前职业支持才可使用，通用被动始终有效。")
  var learn=host.button(good.name+" → "+unit.name+(" · "+reason if reason!="" else ""),func():
   if host.campaign.learn_book(book_index,unit.id):host.refresh_ui();host.show_party_menu("技能",unit.id),reason=="")
  Compact.symbolize(learn,"learn")
  if reason!="":card.add_child(host.text_label(reason,14,host.MUTED))
  learn.disabled=reason!="";card.add_child(learn)

static func aura_preview(host,parent: Control,unit: Dictionary):
 parent.add_child(host.text_label("团队能力来自全队遗物；个人遗物只影响佩戴者。装备只提供基础属性。",16,host.GOLD))

static func profession_page(host,parent: Control,unit: Dictionary):
 if unit.profession=="hero":
  parent.add_child(host.text_label("团长 · 主角专属职业 · 全队遗物提供团队能力",16,host.TEAL))
  host.details_button(parent,"主角职业说明",unit.name+"可学习、使用所有职业技能；不享受其他职业专精。\n"+Jobs.JOBS.hero.specialty)
  parent.add_child(Compact.symbolize(host.button("查看主角技能 →",func():host.show_party_menu("技能",unit.id),true),"skill"))
  return
 parent.add_child(host.text_label("营地转职 · 免费 · 保留装备、已学技能与当前生命/法力",16,host.GOLD))
 var grid=Compact.grid(parent,2);var before=host.campaign.character_stats(unit.id)
 for id in Jobs.JOBS:
  if id=="hero":continue
  var job_id=id;var job=Jobs.JOBS[id]
  var card=Compact.card(host,grid,job.name+(" · 当前" if id==unit.profession else ""),host.GOLD,Compact.icon("person"))
  var candidate=unit.duplicate(true);candidate.profession=id
  var after=host.campaign.stats_for(candidate,host.campaign.equipment)
  Compact.metrics(host,card,[["attack","%d→%d"%[before.power,after.power],"攻击变化"],["armor","%d→%d"%[before.armor,after.armor],"防护变化"],["range","%d→%d"%[before.range,after.range],"射程变化"]])
  Compact.metrics(host,card,[["speed","%d→%d"%[before.speed,after.speed],"速度变化"],["ap","%d→%d"%[before.max_ap,after.max_ap],"行动点变化"]])
  var description=job.specialty
  for skill_id in job.skills:description+="\n\n"+Jobs.ALL_SKILLS[skill_id].name+"："+Jobs.ALL_SKILLS[skill_id].desc
  host.details_button(card,"专精与技能",description+"\n\n普通职业只使用当前职业技能，通用被动始终可用。")
  var reason="仅营地可转职" if host.campaign.phase!="camp" or host.battle!=null else "已阵亡" if unit.hp<=0 else "当前职业" if id==unit.profession else ""
  var entry=host.button("转职为 "+job.name+(" · "+reason if reason!="" else ""),func():
   if host.campaign.change_profession(unit.id,job_id):host.refresh_ui();host.show_party_menu("职业",unit.id),reason=="")
  Compact.symbolize(entry,"profession")
  if reason!="":card.add_child(host.text_label(reason,14,host.MUTED))
  entry.add_theme_font_size_override("font_size",15);entry.disabled=reason!="";card.add_child(entry)

static func equipment_page(host,parent: Control,unit: Dictionary):
 preload("res://game/equipment_menu.gd").page(host,parent,unit)
