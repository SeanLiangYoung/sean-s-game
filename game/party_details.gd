extends RefCounted
const Jobs=preload("res://game/professions.gd")

static func stat_line(stats: Dictionary) -> String:
 return "攻击 %d · 射程 %d · 防护 %d · 速度 %d · 行动点 %d"%[stats.power,stats.range,stats.armor,stats.speed,stats.max_ap]

static func comparison(before: Dictionary,after: Dictionary) -> String:
 var result=[]
 for pair in [["power","攻击"],["range","射程"],["armor","防护"],["speed","速度"],["max_ap","行动点"]]:
  result.append("%s %d → %d"%[pair[1],before[pair[0]],after[pair[0]]])
 return " · ".join(result)

static func skill_details(host,parent: Control,unit: Dictionary):
 host.detail_section(parent,"当前技能")
 for id in Jobs.skills_for(unit):
  var skill=Jobs.ALL_SKILLS[id]
  parent.add_child(host.text_label(skill.name+" · %d点 / %d法力 · 射程%d"%[skill.ap,skill.mp,skill.range],17,host.TEAL))
  var description=Jobs.rank_description(unit,id)
  if skill.get("base",id)=="heal":
   var stats=host.campaign.character_stats(unit.id)
   var amount=26+Jobs.skill_bonus(unit,id)+stats.heal_bonus+(6 if unit.profession=="medic" else 0)+(8 if "fury" in unit.get("learned",[]) else 0)
   description="恢复 %d 生命（基础26，已计入职业及装备增益）"%amount
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
 host.detail_section(parent,"生效的遗物")
 host.show_relic_details(parent,true)

static func skills_page(host,parent: Control,unit: Dictionary):
 parent.add_child(host.text_label("职业技能树 · 可用经验 %d"%unit.get("xp",0),22,host.GOLD))
 parent.add_child(host.text_label("战胜敌人后，上阵幸存者平分经验；击杀者每次额外获得15经验。解锁与强化均消耗经验，最高3级。",15,host.MUTED))
 parent.add_child(host.text_label("基础技能达到2级后，可选择任一进阶分支；两条分支都可学习。转职保留投入，主角可学习所有职业。",15,host.MUTED))
 var jobs=Jobs.JOBS.keys() if unit.profession=="hero" else [unit.profession]
 for job_id in jobs:
  host.detail_section(parent,Jobs.JOBS[job_id].name+" · 技能树")
  var root=Jobs.JOBS[job_id].skills[0]
  var branches=Jobs.JOBS[job_id].skills
  parent.add_child(host.text_label(Jobs.ALL_SKILLS[root].name+" 2级 → "+Jobs.ALL_SKILLS[branches[1]].name+" / "+Jobs.ALL_SKILLS[branches[2]].name,16,host.TEAL))
  for skill_id in Jobs.JOBS[job_id].skills:
   var id=skill_id
   var skill=Jobs.ALL_SKILLS[id]
   var rank=Jobs.skill_rank(unit,id)
   var root_id=Jobs.prerequisite(id)
   var title=("◆ 基础 · " if root_id=="" else "↳ 进阶 · ")+skill.name+" · "+("未解锁" if rank==0 else "%d / 3级"%rank)
   parent.add_child(host.text_label(title,19,host.TEAL if rank>0 else host.MUTED))
   parent.add_child(host.text_label("%d行动点 / %d法力 · 射程%d"%[skill.ap,skill.mp,skill.range],15,host.MUTED))
   if rank>0:parent.add_child(host.text_label("当前："+Jobs.rank_description(unit,id),15))
   if rank<3:parent.add_child(host.text_label(("解锁效果：" if rank==0 else "下一级：")+Jobs.rank_description(unit,id,rank+1),15,host.TEAL))
   if root_id!="":parent.add_child(host.text_label("前置："+Jobs.ALL_SKILLS[root_id].name+" 2级",14,host.MUTED))
   var reason=Jobs.training_reason(unit,id)
   if host.battle!=null or host.campaign.phase not in ["camp","world"]:reason="当前阶段无法加点"
   elif unit.hp<=0:reason="已阵亡，无法加点"
   var label=("解锁" if rank==0 else "强化")+skill.name+" · %d经验"%Jobs.skill_cost(unit,id)
   if rank>=3:label=skill.name+" · 已满级"
   elif reason!="":label+=" · "+reason
   var train=host.button(label,func():
    if host.campaign.train_skill(unit.id,id):
     host.refresh_ui();host.show_party_menu("技能",unit.id))
   train.disabled=reason!=""
   parent.add_child(train)
 skill_details(host,parent,unit)
 host.detail_section(parent,"技能书 · 为当前角色学习")
 parent.add_child(host.text_label("旧存档中的技能书仍可直接学习；职业技能书不再售卖，新增技能通过经验解锁。",15,host.MUTED))
 if host.campaign.books.is_empty():
  parent.add_child(host.text_label("暂无旧技能书。职业技能请在上方使用经验解锁。",16,host.MUTED))
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
 var stats=host.campaign.character_stats(unit.id)
 var state="上阵生效 · 留守不生效"
 if host.battle!=null:
  var deployed=host.battle.find_actor(unit.id)
  state="本场生效" if not deployed.is_empty() and deployed.hp>0 else "本场留守，不生效"
 elif unit.hp<=0:state="已阵亡，不生效"
 parent.add_child(host.text_label("主角光环 · "+Jobs.aura_for(stats)+"\n"+state,16,host.GOLD))

static func profession_page(host,parent: Control,unit: Dictionary):
 parent.add_child(host.text_label("身份："+unit.identity+" · 当前职业："+unit.role,19,host.TEAL))
 parent.add_child(host.text_label(Jobs.JOBS[unit.profession].specialty,16))
 if unit.profession=="hero":
  parent.add_child(host.text_label("沈烬专属职业 · 可学习、使用所有职业技能；不享受其他职业专精。",16,host.MUTED))
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
  var after=Jobs.stats(candidate,host.campaign.equipment)
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
 parent.add_child(host.text_label("主手 / 副手 / 护甲 · 各1件 · 所有职业均可穿戴",17,host.TEAL))
 var editable=host.campaign.phase in ["camp","world"] and host.battle==null and unit.hp>0
 if not editable:parent.add_child(host.text_label("当前只能查看装备。",15,host.MUTED))
 var before=host.campaign.character_stats(unit.id)
 parent.add_child(host.text_label("当前："+stat_line(before),16))
 for slot in Jobs.SLOTS:
  var slot_id=slot
  var index=host.campaign.equipped_index(unit.id,slot)
  parent.add_child(host.text_label(Jobs.SLOTS[slot]+"："+(Jobs.ITEMS[host.campaign.equipment[index].id].name if index>=0 else "空置"),18,host.GOLD))
  if index>=0:
   var remove=host.button("卸下当前"+Jobs.SLOTS[slot],func():
    if host.campaign.unequip_item(unit.id,slot_id):host.refresh_ui();host.show_party_menu("装备",unit.id))
   remove.disabled=not editable;parent.add_child(remove)
 if not host.campaign.trial_equipment_claimed:
  var claim=host.button("领取职业试用装备（旧档一次）",func():
   if host.campaign.claim_trial_equipment():host.show_party_menu("装备",unit.id))
  claim.disabled=host.campaign.phase!="camp";parent.add_child(claim)
 host.detail_section(parent,"队伍装备库  /  %d 件"%host.campaign.equipment.size())
 if host.campaign.equipment.is_empty():parent.add_child(host.text_label("暂无装备，可从商店或战利品获得。",16))
 for i in host.campaign.equipment.size():
  var index=i
  var entry_data=host.campaign.equipment[i]
  var item=Jobs.ITEMS[entry_data.id]
  var owner="背包中"
  for member in host.campaign.roster:
   if member.id==entry_data.owner:owner=member.name+"装备中"
  parent.add_child(host.text_label(item.name+" · "+owner,18,host.GOLD))
  parent.add_child(host.text_label(Jobs.item_description(entry_data.id),15))
  var preview=host.campaign.preview_equipment(i,unit.id)
  parent.add_child(host.text_label(comparison(before,preview),15,host.MUTED))
  var adaptation="；".join(preview.adaptation)
  parent.add_child(host.text_label(adaptation if adaptation!="" else "无职业装备增益或惩罚",15,host.TEAL if preview.max_ap>=before.max_ap else host.RED))
  if unit.profession=="hero" and item.slot=="mainhand":parent.add_child(host.text_label("穿戴后光环："+Jobs.aura_for(preview),15,host.TEAL))
  var equip=host.button("已装备" if entry_data.owner==unit.id else (("装备此武器" if item.slot=="mainhand" else "装备此"+Jobs.SLOTS[item.slot]) if entry_data.owner=="" else "转交并装备"),func():
   if host.campaign.equip_item(index,unit.id):host.refresh_ui();host.show_party_menu("装备",unit.id))
  equip.disabled=not editable or entry_data.owner==unit.id
  parent.add_child(equip)
