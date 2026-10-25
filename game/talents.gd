extends RefCounted
# Identity stays independent of current profession. All transient data lives on battle actors.
static func is_character(unit: Dictionary,id: String) -> bool:
 return unit.get("character_id","")==id and unit.get("side",0)==0

static func announce(b,unit: Dictionary,detail: String):
 b.events.append("天赋 · %s · %s"%[unit.name,detail])

static func reset(unit: Dictionary):
 unit.talent_state={"moved":false,"free_step":false,"dash_used":false,"snipe_used":false,"execute_used":false,"captain_used":false,"support_used":false,"combo_jobs":[],"combo_used":false,"trap_used":false,"guard_uses":0,"interrupt_used":false}

static func state(unit: Dictionary) -> Dictionary:
 if not unit.has("talent_state"):reset(unit)
 return unit.talent_state

static func skill_range(unit: Dictionary,id: String,base: int) -> int:
 var flags=unit.get("talent_state",{})
 if is_character(unit,"ya") and id in ["sniper","ranger_hunt"] and not flags.get("moved",false) and not flags.get("snipe_used",false):return base+1
 return base

static func discount(unit: Dictionary,id: String,target: Dictionary) -> int:
 return 2 if is_character(unit,"tang") and id in ["bomb","engineer_breaker"] and target.get("statuses",{}).has("exposed") else 0

static func damage_bonus(unit: Dictionary,id: String,target: Dictionary,context: Dictionary) -> int:
 if is_character(unit,"pei") and id in ["execute","blade_hunt"] and context.half:return 6
 if is_character(unit,"chi") and id=="blade_drain" and context.self_half:return 4
 if is_character(unit,"ya") and id in ["sniper","ranger_hunt"] and not state(unit).moved and not state(unit).snipe_used:return 6
 if is_character(unit,"tang") and id in ["bomb","engineer_breaker"] and target.id==context.target:return 6
 if is_character(unit,"qin") and id in ["bash","warden_rebuke"] and not context.staggered:return 5
 return 0

static func heal_bonus(unit: Dictionary,id: String,context: Dictionary) -> int:
 if is_character(unit,"qing") and id in ["heal","medic_mend"] and context.half:return 10
 if is_character(unit,"ji") and id=="engineer_pulse" and not context.shield:return 4
 if is_character(unit,"luosui") and id=="warden_rescue" and context.half and context.target!=unit.id:return 8
 return 0

static func shield_bonus(unit: Dictionary,id: String,context: Dictionary) -> int:
 if is_character(unit,"ji") and id=="engineer_pulse":return 10 if context.shield else 6
 if is_character(unit,"bai") and id in ["cleanse","warden_ward"] and context.harmful:return 4
 return 0

static func context(unit: Dictionary,target: Dictionary) -> Dictionary:
 var statuses=target.get("statuses",{})
 var harmful=false
 for id in ["mark","exposed","poison","chill","snare","stagger"]:
  if statuses.has(id):harmful=true
 return {"target":target.get("id",""),"hp":target.get("hp",0),"mp":target.get("mp",0),"half":target.get("hp",1)*2<=target.get("max_hp",0),"self_half":unit.hp*2<=unit.max_hp,"shield":statuses.has("shield"),"harmful":harmful,"staggered":statuses.has("stagger") or statuses.has("chill"),"cell":unit.cell}

static func shield(b,target: Dictionary,source: Dictionary,amount: int):
 if target.hp<=0 or source.hp<=0:return
 var bonus=amount-10+int(b.combat_modifier(source,"shield_power"))
 # Do not shorten a stronger shield's lifetime when retaining it.
 if not target.get("statuses",{}).has("shield") or int(target.statuses.shield.get("bonus",0))<bonus:
  b.put_status(target,"shield",source.id,bonus)

static func after_cast(b,unit: Dictionary,id: String,target: Dictionary,before: Dictionary):
 if unit.hp<=0:return
 var flags=state(unit)
 if is_character(unit,"lu"):
  var job=b.Professions.ALL_SKILLS[id].job
  if job not in flags.combo_jobs:flags.combo_jobs.append(job)
  if flags.combo_jobs.size()>=2 and not flags.combo_used:
   flags.combo_used=true;unit.mp=mini(unit.max_mp,unit.mp+4)
   announce(b,unit,"异式演算 · 法力+4")
 if target.is_empty():return
 var life_damage=maxi(0,before.hp-target.hp)
 if is_character(unit,"shen") and id in ["strike","hero_burst","hero_sunder","hero_judgment"] and life_damage>0 and not flags.captain_used:
  flags.captain_used=true
  if target.hp>0:b.put_status(target,"advance",unit.id)
  announce(b,unit,"余烬接力 · 进军号令")
 if is_character(unit,"wen") and id in ["hero_heal","hero_rally"] and target.id!=unit.id and (target.hp>before.hp or target.mp>before.mp) and not flags.support_used:
  flags.support_used=true
  shield(b,target,unit,10 if before.half else 6)
  announce(b,unit,"归途之约 · 保护同伴")
 if is_character(unit,"aling") and id=="dash" and unit.cell!=before.cell and life_damage>0 and not flags.dash_used:
  flags.dash_used=true;flags.free_step=true
  announce(b,unit,"落脚有声 · 下一次移动首格免费")
 if is_character(unit,"pei") and id in ["execute","blade_hunt"] and before.hp>0 and target.hp<=0 and not flags.execute_used:
  flags.execute_used=true;unit.mp=mini(unit.max_mp,unit.mp+3)
  announce(b,unit,"一刀清账 · 法力+3")
 if is_character(unit,"ya") and id in ["sniper","ranger_hunt"]:flags.snipe_used=true
 if is_character(unit,"lin") and id in ["mark","ranger_expose"] and target.hp>0:
  target.statuses.mark.bonus+=2
  target.statuses.mark.talent_mana=true
  announce(b,unit,"众矢之的 · 标记伤害+2")
 if is_character(unit,"suo") and id=="ranger_pin" and target.hp>0:
  b.put_status(target,"snare",unit.id)
  announce(b,unit,"截途箭 · 束缚")
 if is_character(unit,"bai") and id in ["cleanse","warden_ward"] and before.harmful:
  b.heal_unit(target,6)
  announce(b,unit,"祛厄留生 · 恢复生命")
 if is_character(unit,"wenlan") and id in ["medic_channel","hero_rally"] and target.id!=unit.id and target.mp>before.mp and not flags.support_used:
  flags.support_used=true;unit.mp=mini(unit.max_mp,unit.mp+3)
  b.heal_unit(target,4)
  announce(b,unit,"细水长流 · 法力+3，友军恢复生命")
 if is_character(unit,"luosui") and id=="warden_rescue" and before.half and target.id!=unit.id:
  for harmful in ["poison","chill"]:
   if target.statuses.has(harmful):
    target.statuses.erase(harmful);announce(b,unit,"带你回去 · 清除负面状态");break
 if is_character(unit,"qin") and id in ["bash","warden_rebuke"] and target.hp>0 and not flags.interrupt_used:
  var interruptible=b.boss_intents.filter(func(intent):return intent.source==target.id and intent.kind=="overload")
  if not interruptible.is_empty():
   for intent in interruptible:b.boss_intents.erase(intent)
   flags.interrupt_used=true
   shield(b,unit,unit,8)
   announce(b,unit,"震腕 · 打断星核过载，获得护盾")

static func direct_hit(b,source: Dictionary,target: Dictionary) -> Dictionary:
 var result={"damage":0,"mana":0,"kill_mana":0}
 var statuses=target.get("statuses",{})
 if statuses.has("advance"):
  var captain=b.find_actor(statuses.advance.source)
  if not captain.is_empty() and captain.hp>0 and captain.side==source.side and captain.id!=source.id:
   result.damage=4;result.kill_mana=3
   target.statuses.erase("advance")
   announce(b,source,"余烬接力 · 伤害+4")
 if statuses.has("mark") and statuses.mark.get("talent_mana",false):
  var marker=b.find_actor(statuses.mark.source)
  if not marker.is_empty() and marker.hp>0 and marker.side==source.side and marker.id!=source.id:
   result.mana=2
   target.statuses.mark.talent_mana=false
   announce(b,source,"众矢之的 · 攻击后回蓝2")
 return result

static func guard_reduction(b,unit: Dictionary) -> int:
 if not is_character(unit,"yue") or state(unit).guard_uses>=2:return 0
 state(unit).guard_uses+=1
 announce(b,unit,"最后一面盾 · 分担伤害-3")
 return 3

static func trap_trigger(b,unit: Dictionary):
 if unit.is_empty() or unit.hp<=0 or not is_character(unit,"li") or state(unit).trap_used:return
 state(unit).trap_used=true;unit.mp=mini(unit.max_mp,unit.mp+2)
 announce(b,unit,"藏齿 · 法力+2")
