extends RefCounted
const Relic=preload("res://game/relics.gd")
const TACTICS={
 "blood":"用输出换取吸血续航；留意半血窗口。吸血依赖实际生命伤害，额外承伤与自伤仍可能致命。",
 "hunt":"先标记，再让队友集火；把首次命中留给关键目标，击杀返还的行动点用于追击或撤回。",
 "ward":"先建立护盾，再让前排接敌。护盾耗尽后，依赖护盾的减伤和输出条件也会消失。",
 "arcane":"把法力留给关键伤害战技；用休息与支援衔接下一轮，避免在普通敌人上耗尽资源。",
 "engine":"提前布设机关，引导敌人经过；机关需要位置和行动点，缩圈前安排好退路。",
 "pilgrim":"利用治疗与行动开始恢复维持续航；恢复需要时间，仍须在十回合期限内主动推进。",
 "dusk":"让输出手短暂离开友军一格范围，再收割残血；脱离保护前确认敌方射程。",
 "command":"用标记和集火安排全队行动顺序；把首次命中交给关键目标，休息前先确认是否还能完成击杀。"}
const TRACES={
 "blood":"磨损的边角缠着旧绷带。有人把它贴身收了很久。",
 "hunt":"背面刻着几道辨认风向的记号，最下面添了一个回家的箭头。",
 "ward":"原来的挂绳断过，后来的人用窗帘上的布条重新系好。",
 "arcane":"细小的字挤在边缘，像是有人借着最后一点灯火写下的。",
 "engine":"修补处用了两种不同的金属。它曾被人拆开，又认真装了回去。",
 "pilgrim":"有人把它和一只空药瓶放在一起，包布洗得发白。",
 "dusk":"布套里夹着半张住址，纸上的房屋被涂成蓝色。",
 "command":"旧持有者在底部刻了几个人的名字，后来又补上一个。"}
static func applicable(entries: Array,owner: String) -> Array:
 var result=[];var seen=[]
 for entry in entries:
  var id=Relic.id_of(entry);var d=Relic.definition(id)
  if d.is_empty() or id in seen or (entry is Dictionary and entry.get("remaining",-1)==0):continue
  if d.scope=="personal" and (not entry is Dictionary or entry.get("owner","")!=owner):continue
  seen.append(id);result.append(entry)
 return result
static func tactic(family: String) -> String:
 return TACTICS.get(family,"")
static func lore(id: String) -> String:
 var d=Relic.definition(id)
 if d.is_empty():return ""
 var personal_traces={"ward_1":"灯罩上有一个补过的小洞。提手被磨得发亮，像是每晚都有人提着它绕村走一圈。","hunt_2":"旗边补着不同颜色的布，其中一块还留着旧窗帘的花纹。","blood_6":"戒指内侧刻着两个人的名字，后刻的那个更浅。","ember":"徽印背面粘着炭灰。原来的主人曾拿它压住炉门边翘起的铁皮。","spring":"外壳有三道水位线，最低的一道旁边刻着一只小碗。","lens":"皮套里夹着一张只画了几间房子的地图，路口旁写着：这里还能住。"}
 if personal_traces.has(id):return personal_traces[id]
 return TRACES.get(d.get("family",""),"表面的磨痕深浅不一。它曾属于别人，也曾跟着那个人走过一段路。")
static func compare(entries: Array,id: String,owner: String) -> Dictionary:
 var d=Relic.definition(id)
 var result={"before":{},"after":{},"activated":[],"lost":[],"replaced":"","requires_owner":false,"text":""}
 if d.is_empty():return result
 if d.scope=="personal" and owner=="":
  result.requires_owner=true;result.text="选择佩戴者后，查看共鸣变化；替换会失去旧个人遗物。";return result
 var current=applicable(entries,owner)
 var next=entries.duplicate(true)
 if d.scope=="personal":
  for i in range(next.size()-1,-1,-1):
   var entry=next[i]
   if Relic.definition(entry).get("scope","")=="personal" and entry is Dictionary and entry.get("owner","")==owner:
    result.replaced=Relic.id_of(entry);next.remove_at(i)
 next.append(Relic.instance(id,2147483647,owner if d.scope=="personal" else ""))
 result.before=Relic.resonance_counts(current)
 result.after=Relic.resonance_counts(applicable(next,owner))
 var family=d.get("family","");var lines=[]
 if family!="":
  var set_data=Relic.Expansion.SETS[family];var old=int(result.before.get(family,0));var count=int(result.after.get(family,0))
  lines.append("%s共鸣 %d → %d / 4"%[set_data.name,old,count])
  for threshold in [2,4]:
   if old<threshold and count>=threshold:
    result.activated.append(threshold);lines.append("激活%d件：%s"%[threshold,set_data.two_desc if threshold==2 else set_data.four_desc])
  if count<4 and result.activated.is_empty():lines.append("再获%d件同主题可达%d件"%[(2 if count<2 else 4)-count,2 if count<2 else 4])
 for old_family in result.before:
  for threshold in [2,4]:
   if result.before[old_family]>=threshold and result.after.get(old_family,0)<threshold:
    result.lost.append(threshold);lines.append("失去%s%d件共鸣"%[Relic.Expansion.SETS[old_family].name,threshold])
 if lines.is_empty():lines.append("独立效果 · 不计入主题共鸣")
 result.text="\n".join(lines)
 return result
static func overview(entries: Array,roster: Array) -> Array:
 var result=[]
 for unit in roster:
  if unit.hp<=0:continue
  var counts=Relic.resonance_counts(applicable(entries,unit.id));var lines=[]
  for family in counts:
   var d=Relic.Expansion.SETS[family];var n=int(counts[family])
   lines.append("%s %d/4 · %s"%[d.name,n,"2件与4件已激活" if n>=4 else "2件已激活" if n>=2 else "尚差1件激活"])
  result.append({"owner":unit.id,"name":unit.name,"counts":counts,"text":"\n".join(lines) if not lines.is_empty() else "尚未形成主题；独立遗物仍按自身效果生效。"})
 return result
static func show(host):
 host.open_modal("遗物构筑","先看谁能生效，再决定下一件。")
 host.set_page_back(host.close_modal)
 var entries=host.campaign.relics+host.campaign.collection if host.battle==null else host.battle.relic_state
 var team=entries.filter(func(e):return Relic.definition(e).get("scope","")=="team")
 var counts=Relic.resonance_counts(applicable(team,""))
 var header=host.text_label("全队共同底座",22,host.GOLD);host.modal_body.add_child(header)
 if counts.is_empty():host.modal_body.add_child(host.text_label("还没有主题组合。远征奖励会提供延续与转向的选择。",17,host.MUTED))
 for family in counts:
  var d=Relic.Expansion.SETS[family]
  var card=host.Compact.card(host,host.modal_body,"%s · 全队基础 %d/4"%[d.name,counts[family]],host.TEAL)
  card.add_child(host.text_label(tactic(family),17))
  host.details_button(card,"2件 / 4件规则",d.two_desc+"\n"+d.four_desc)
 host.modal_body.add_child(host.text_label("各人的实际组合",22,host.GOLD))
 var grid=host.Compact.grid(host.modal_body,2)
 for summary in overview(entries,host.campaign.roster):
  var card=host.Compact.card(host,grid,summary.name,host.GOLD)
  card.add_child(host.text_label(summary.text,17))
  var personal=applicable(entries,summary.owner).filter(func(e):return Relic.definition(e).scope=="personal")
  if not personal.is_empty():card.add_child(host.text_label("个人："+Relic.definition(personal[0]).name,15,host.TEAL))
  var risks=[]
  for entry in applicable(entries,summary.owner):risks.append(Relic.definition(entry).name+"："+Relic.definition(entry).risk)
  if not risks.is_empty():host.details_button(card,"这套组合的代价", "\n".join(risks))
 host.modal_body.add_child(host.button("整理遗物与查看图鉴",func():host.show_party_menu("遗物")))
 host.modal_body.add_child(host.button("返回旅途",host.close_modal,true))
static func reward_hint(host,id: String) -> String:
 var d=Relic.definition(id);var entries=host.campaign.relics+host.campaign.collection
 if d.scope=="personal":return compare(entries,id,"").text
 var family=d.get("family","")
 if family=="":return "独立效果 · 不计入主题共鸣"
 var team=entries.filter(func(e):return Relic.definition(e).get("scope","")=="team")
 var base=compare(team,id,"");var set_data=Relic.Expansion.SETS[family]
 var lines=["全队底座 · %s %d → %d / 4"%[set_data.name,base.before.get(family,0),base.after.get(family,0)]]
 for threshold in [2,4]:
  var names=[]
  for unit in host.campaign.roster:
   if unit.hp<=0:continue
   if threshold in compare(entries,id,unit.id).activated:names.append(unit.name)
  if not names.is_empty():
   lines.append("%s：激活%d件 · %s"%["、".join(names),threshold,set_data.two_desc if threshold==2 else set_data.four_desc])
 if lines.size()==1:lines.append("暂无新增共鸣 · 个人组合见构筑页")
 return "\n".join(lines)
