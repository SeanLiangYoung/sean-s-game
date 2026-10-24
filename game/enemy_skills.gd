extends RefCounted
const Regions=preload("res://game/regions.gd")
const AFFIXES={
 "vigor":{"name":"强健","desc":"最大生命增加15%"},"brutal":{"name":"凶猛","desc":"攻击+2，上限20"},"iron":{"name":"铁壁","desc":"防护+2"},"swift":{"name":"迅捷","desc":"速度+2"},"reach":{"name":"延伸","desc":"普通攻击射程+1"},"mending":{"name":"自愈","desc":"每次自身行动开始恢复3生命"},"warded":{"name":"护体","desc":"每次自身行动额外获得4点护盾，与原生屏障合并"}}
const NORMAL={
 "formation":{"name":"架盾固守","effect":"shield","ap":2,"cd":3,"range":0,"amount":6},
 "spotter":{"name":"哨声指认","effect":"mark","ap":2,"cd":2,"range":4},
 "camouflage":{"name":"林间钉射","effect":"pin","ap":2,"cd":2,"range":4,"bonus":-3},
 "ambush":{"name":"棘影突袭","effect":"dash","ap":2,"cd":2,"range":2,"bonus":-2},
 "raider":{"name":"裂砂横斩","effect":"cleave","ap":2,"cd":2,"range":1,"bonus":-4},
 "sapper":{"name":"蚀能弩矢","effect":"drain","ap":2,"cd":2,"range":3,"bonus":-3,"drain":2},
 "frost_armor":{"name":"霜甲覆身","effect":"shield","ap":2,"cd":3,"range":0,"amount":6},
 "frostshot":{"name":"凝寒箭","effect":"cold","ap":2,"cd":2,"range":3,"bonus":-1},
 "venom":{"name":"淬毒箭","effect":"venom","ap":2,"cd":2,"range":3,"bonus":-4},
 "mirehide":{"name":"汲血撕咬","effect":"leech","ap":2,"cd":2,"range":1,"bonus":-2},
 "capacitor":{"name":"应急屏障","effect":"shield","ap":2,"cd":3,"range":0,"amount":10},
 "drainer":{"name":"汲能射线","effect":"drain","ap":2,"cd":2,"range":3,"bonus":-3,"drain":4,"shield_drain":1},
 "legacy":{"name":"蓄力强击","effect":"strike","ap":2,"cd":2,"range":3,"bonus":-2}}
static var SKILLS=build_skills()
static func build_skills() -> Dictionary:
 var result={}
 for id in NORMAL:result[id+"_skill"]=NORMAL[id].duplicate(true)
 var names={"border":["督军破阵箭","战旗整军"],"wood":["荆棘穿刺","树心回生"],"waste":["裂风突刺","扬沙护体"],"frost":["冰锋裁断","重铸冰盾"],"marsh":["毒牙追猎","菌膜再生"],"ruins":["汲星射线","星核修复"]}
 for region in Regions.CATALOG:
  result[region+"_intent"]={"name":Regions.CATALOG[region].intent,"effect":"intent","ap":2,"cd":2,"range":99}
  result[region+"_strike"]={"name":names[region][0],"effect":{"border":"mark_hit","wood":"snare","waste":"pin","frost":"cold","marsh":"venom","ruins":"drain"}[region],"ap":2,"cd":2,"range":3,"bonus":-1 if region=="frost" else -3,"drain":4 if region=="ruins" else 3,"shield_drain":1 if region=="ruins" else 0}
  result[region+"_support"]={"name":names[region][1],"effect":{"border":"command","wood":"recover","waste":"shield","frost":"shield","marsh":"recover","ruins":"recover"}[region],"ap":2,"cd":3,"range":0,"amount":8}
 return result

static func skills(unit: Dictionary) -> Array:
 if unit.get("side",-1)!=1:return []
 if unit.get("boss",false):return [unit.biome+"_intent",unit.biome+"_strike",unit.biome+"_support"]
 return [(unit.get("trait","") if NORMAL.has(unit.get("trait","")) else "legacy")+"_skill"]

static func ready(b,unit: Dictionary,id: String) -> bool:
 if unit.hp<=0 or id not in skills(unit) or not SKILLS.has(id):return false
 return not unit.get("enemy_used",false) and unit.ap>=SKILLS[id].ap and int(unit.get("turn_serial",0))>=int(unit.get("cooldowns",{}).get(id,0))

static func spend(unit: Dictionary,id: String):
 unit.ap-=SKILLS[id].ap
 unit.enemy_used=true
 if not unit.has("cooldowns"):unit.cooldowns={}
 unit.cooldowns[id]=int(unit.get("turn_serial",0))+SKILLS[id].cd

static func can_cast(b,id: String,target=null) -> bool:
 if not b.can_act() or b.active().side!=1:return false
 var unit=b.active()
 if not ready(b,unit,id):return false
 var skill=SKILLS[id]
 if skill.effect=="intent":
  if target==null:return true
  if not target is String:return false
  var aimed=b.find_actor(target)
  return not aimed.is_empty() and aimed.hp>0 and aimed.side!=unit.side
 var victim=unit
 if skill.range>0:
  if not target is String:return false
  victim=b.find_actor(target)
  if victim.is_empty() or victim.side==unit.side or victim.hp<=0 or b.hex_distance(unit.cell,victim.cell)>skill.range:return false
  if skill.effect=="dash" and b.dash_landing(unit,victim)==null:return false
 if skill.effect=="recover" and unit.hp>=unit.max_hp:return false
 if skill.effect=="shield" and unit.get("statuses",{}).has("shield") and 10+int(unit.statuses.shield.get("bonus",0))>=int(skill.amount):return false
 if skill.effect=="command" and not b.actors.any(func(u):return u.side==1 and u.id!=unit.id and u.hp>0):return false
 return true

static func cast(b,id: String,target=null) -> bool:
 if not can_cast(b,id,target):return false
 var unit=b.active()
 var skill=SKILLS[id]
 if skill.effect=="intent":return b.Regional.prepare(b,unit,str(target) if target is String else "")
 var victim=b.find_actor(target) if skill.range>0 else unit
 var origin=unit.cell
 spend(unit,id)
 var cells=[victim.cell]
 var effect=skill.effect
 var cue_kind="support" if skill.range==0 else "strike"
 b.events.append("敌方技能 · "+unit.name+"："+skill.name+"（无耗蓝，冷却%d次自身行动）"%skill.cd)
 var shielded=unit.get("statuses",{}).has("shield")
 match effect:
  "shield":b.put_status(unit,"shield",unit.id,int(skill.amount)-10)
  "recover":unit.hp=mini(unit.max_hp,unit.hp+int(skill.amount))
  "command":
   var followers=b.actors.filter(func(u):return u.side==1 and u.hp>0 and u.id!=unit.id)
   for follower in followers.slice(0,2):b.put_status(follower,"command",unit.id)
  "mark":b.put_status(victim,"mark",unit.id,-2)
  _:
   if effect=="dash":
    var destination=b.dash_landing(unit,victim)
    if destination!=unit.cell:
     unit.cell=destination
     b.trigger_trap(unit)
   if unit.hp>0:
    var victims=[victim]
    if effect=="cleave":victims=b.actors.filter(func(u):return u.side!=unit.side and u.hp>0 and b.hex_distance(unit.cell,u.cell)<=1).slice(0,2)
    cells=[]
    for enemy in victims:
     cells.append(enemy.cell)
     var before=enemy.hp
     var target_shielded=enemy.get("statuses",{}).has("shield")
     b.deal_damage(unit,enemy,maxi(1,unit.power+int(skill.get("bonus",0))),true)
     var lost=maxi(0,before-enemy.hp)
     if unit.hp<=0:break
     if effect=="leech":unit.hp=mini(unit.max_hp,unit.hp+int(lost*0.3))
     if enemy.hp<=0:continue
     if lost==0:
      if effect=="drain" and target_shielded:enemy.mp=maxi(0,enemy.mp-int(skill.get("shield_drain",0)))
      continue
     if effect in ["pin","cold"]:b.put_status(enemy,"stagger" if effect=="pin" else "chill",unit.id)
     if effect=="snare":b.put_status(enemy,"snare",unit.id)
     if effect=="mark_hit":b.put_status(enemy,"mark",unit.id,-2)
     if effect=="venom":b.Regional.poison(b,enemy,unit.id)
     if effect=="drain":enemy.mp=maxi(0,enemy.mp-int(skill.get("drain",3))-(1 if shielded and unit.get("boss_passive","")=="feedback" else 0))
 b.boss_cues.append({"type":"enemy_skill","source":unit.id,"biome":unit.get("biome","border"),"phase":unit.get("boss_phase",1),"name":skill.name,"kind":cue_kind,"cells":cells,"damage":unit.power if skill.range>0 else 0,"debuff":effect,"movement":effect=="dash","from":origin,"to":unit.cell})
 return true

static func choose(b,unit: Dictionary) -> bool:
 var available=skills(unit)
 if unit.get("boss",false) and unit.hp*100<=unit.max_hp*65:
  var support=unit.biome+"_support"
  available.erase(support);available.push_front(support)
 for id in available:
  if not ready(b,unit,id):continue
  var skill=SKILLS[id]
  if skill.effect=="intent":
   if cast(b,id):return true
  elif skill.range==0:
   if cast(b,id):return true
  else:
   var targets=b.actors.filter(func(u):return u.side!=unit.side and u.hp>0)
   targets.sort_custom(func(x,y):
    var dx=b.hex_distance(unit.cell,x.cell);var dy=b.hex_distance(unit.cell,y.cell)
    return dx<dy if dx!=dy else str(x.id)<str(y.id))
   for target in targets:
    if cast(b,id,target.id):return true
 return false

static func empower(b,config: Dictionary,difficulty: int):
 var enemies=b.actors.filter(func(u):return u.side==1)
 if enemies.is_empty():return
 var random=RandomNumberGenerator.new();random.seed=int(config.get("seed",71023+difficulty)) ^ 0x53B01
 var unit=enemies[random.randi_range(0,enemies.size()-1)]
 var affix=AFFIXES.keys()[random.randi_range(0,AFFIXES.size()-1)]
 unit.affix=affix
 match affix:
  "vigor":unit.max_hp+=maxi(1,int(ceil(unit.max_hp*0.15)));unit.hp=unit.max_hp
  "brutal":unit.power=mini(20,unit.power+2)
  "iron":unit.armor=unit.get("armor",0)+2
  "swift":unit.speed+=2
  "reach":unit.range+=1
  "warded":
   var current=10+int(unit.get("statuses",{}).get("shield",{}).get("bonus",-10))
   b.put_status(unit,"shield",unit.id,current+4-10)
 b.events.append("敌人强化 · "+unit.name+"："+AFFIXES[affix].name+" · "+AFFIXES[affix].desc)

static func turn_start(b,unit: Dictionary):
 unit.enemy_used=false
 if not unit.has("cooldowns"):unit.cooldowns={}
 if unit.get("affix","")=="mending":unit.hp=mini(unit.max_hp,unit.hp+3)
 if unit.get("affix","")=="warded":
  if not unit.get("statuses",{}).has("shield") or int(unit.statuses.shield.get("bonus",0))< -6:b.put_status(unit,"shield",unit.id,-6)

static func description(unit: Dictionary) -> String:
 var lines=[]
 for id in skills(unit):
  var d=SKILLS[id]
  var remaining=maxi(0,int(unit.get("cooldowns",{}).get(id,0))-int(unit.get("turn_serial",0)))
  var effects={"shield":"自身获得%d护盾"%int(d.get("amount",6)),"recover":"自身恢复%d生命"%int(d.get("amount",8)),"command":"强化至多2名随从下一击+3","intent":"预告危险格，下次自身行动结算","mark":"标记目标，直接受伤+3"}.get(d.effect,"")
  if effects=="":
   effects="攻击%+d基础伤害 · 射程%d"%[int(d.get("bonus",0)),int(d.range)]
   var debuff={"pin":"下次行动点-1","cold":"附寒冷","venom":"附两次毒伤","snare":"下次移动首格+1点","drain":"附耗蓝%d"%int(d.get("drain",3)),"leech":"实际伤害30%回血","dash":"突进至相邻空格","cleave":"至多2名相邻敌人","mark_hit":"附标记"}.get(d.effect,"")
   if debuff!="":effects+=" / "+debuff
   if int(d.get("shield_drain",0))>0:effects+=" / 护盾全挡时仍耗蓝%d"%int(d.shield_drain)
  lines.append(d.name+" · "+effects+" · %d行动点 · 无耗蓝 · 冷却%d次自身行动"%[d.ap,d.cd]+(" · 剩余%d"%remaining if remaining>0 else " · 就绪"))
 return "\n".join(lines)
