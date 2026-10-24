extends RefCounted
# Positive and negative effects share one lifetime; no activation switch exists.
const CATALOG={
 "ember":{"name":"余烬徽印","scope":"team","uses":0,"benefit":"全队攻击与直接伤害战技 +4","risk":"战斗与补给的生命恢复减少25%","mods":{"damage":4,"healing_pct":-25},"color":"#ec9a5c"},
 "spring":{"name":"旧世泉核","scope":"team","uses":0,"benefit":"全队休息每点行动额外恢复2%生命与法力","risk":"每次受伤额外承受2点伤害","mods":{"rest_hp":0.02,"rest_mp":0.02,"taken":2},"color":"#80c7b2"},
 "lens":{"name":"测绘透镜","scope":"team","uses":0,"benefit":"获取时获得30银币","risk":"全队速度 -1；收藏不重复发放银币","mods":{"speed":-1},"color":"#97b7df"},
 "banner":{"name":"裂甲战旗","scope":"team","uses":0,"benefit":"全队攻击与直接伤害战技 +8","risk":"全队防护 -3，负防护会增加受伤","mods":{"damage":8,"armor":-3},"color":"#ec9a5c"},
 "bastion":{"name":"沉铁壁垒","scope":"team","uses":0,"benefit":"全队防护 +4","risk":"全队速度 -3","mods":{"armor":4,"speed":-3},"color":"#97b7df"},
 "hourglass":{"name":"逆流沙漏","scope":"team","uses":0,"benefit":"全队每次行动的行动点 +1","risk":"全队攻击与直接伤害战技 -4","mods":{"max_ap":1,"damage":-4},"color":"#dbbf78"},
 "mist":{"name":"远望雾灯","scope":"team","uses":0,"benefit":"全队普通攻击射程 +1","risk":"生命休息每点行动的恢复比例降低2%","mods":{"range":1,"rest_hp":-0.02},"color":"#80c7b2"},
 "echo":{"name":"回响棱镜","scope":"personal","uses":6,"trigger":"有敌方目标存活且法力足够时，直接伤害战技追加8点伤害（每次施法一次）","benefit":"直接伤害战技追加8点伤害","risk":"触发额外消耗3法力；法力不足则不触发","mods":{},"color":"#b4a1d1"},
 "candle":{"name":"续命烛芯","scope":"personal","uses":1,"trigger":"受到致命伤害时","benefit":"抵挡一次致命伤害，保留1生命","risk":"触发耗尽佩戴者全部法力","mods":{},"color":"#dbbf78"},
 "chalice":{"name":"噬血圣杯","scope":"personal","uses":8,"trigger":"佩戴者击杀敌人且生命未满时","benefit":"击杀恢复12生命","risk":"生命休息每点行动的恢复比例降低3%","mods":{"rest_hp":-0.03},"color":"#ec9a5c"},
 "thorn":{"name":"荆棘王冠","scope":"personal","uses":0,"benefit":"攻击与直接伤害战技 +6","risk":"每次受伤额外承受3点伤害","mods":{"damage":6,"taken":3},"color":"#ec9a5c"},
 "prism":{"name":"慈悲裂晶","scope":"personal","uses":8,"trigger":"治疗战技有效恢复生命时","benefit":"治疗战技恢复量 +12","risk":"每次治疗战技额外消耗3法力","mods":{"heal":12,"heal_mp":3},"color":"#80c7b2"},
 "fang":{"name":"饥渴獠牙","scope":"personal","uses":10,"trigger":"直接攻击或直接伤害战技命中时，每个目标一次","benefit":"该次伤害 +10","risk":"每次触发自身失去2生命，可能致命","mods":{},"color":"#ec9a5c"},
 "tide":{"name":"枯潮瓶","scope":"personal","uses":6,"trigger":"休息恢复法力且实际有恢复时","benefit":"法力休息每点行动额外恢复5%","risk":"生命休息每点行动的恢复比例降低4%","mods":{"rest_mp":0.05,"rest_hp":-0.04},"color":"#97b7df"},
 "shell":{"name":"碎誓甲壳","scope":"personal","uses":8,"trigger":"受到非零生命伤害时","benefit":"该次生命伤害减少10，最低0","risk":"速度 -2","mods":{"speed":-2},"color":"#97b7df"}
}
static func id_of(entry) -> String:
 return entry if entry is String else str(entry.get("id",""))
static func definition(entry) -> Dictionary:
 return CATALOG.get(id_of(entry),{})
static func description(entry) -> String:
 var d=definition(entry)
 if d.is_empty():return "未知遗物"
 return ("全队遗物" if d.scope=="team" else "个人遗物 · 每人限1件")+"\n收益："+d.benefit+"\n代价："+d.risk+"\n"+("持续生效" if d.uses==0 else "触发："+d.trigger+" · %d次后损毁"%d.uses)
static func instance(id: String,uid: int,owner: String="") -> Dictionary:
 return {"id":id,"uid":uid,"owner":owner,"remaining":CATALOG[id].uses if CATALOG[id].uses>0 else -1}
static func rewards() -> Array:
 var result=[]
 for id in CATALOG:
  var d=CATALOG[id]
  result.append({"id":id,"name":d.name,"type":"relic","desc":description(id),"color":d.color})
 return result
