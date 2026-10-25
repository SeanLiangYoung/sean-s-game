extends RefCounted
# Local testimony, never an omniscient explanation. These IDs are save data.
const HOMES={
 "lodger":{"title":"借住的小屋","resident":"hero","color":"c58c45","pos":Vector3(-6,0,5),"angle":12.0},
 "blade":{"title":"阿凌的红屋","resident":"blade","color":"ac554c","pos":Vector3(-8,0,-1),"angle":8.0},
 "ranger":{"title":"鸦的蓝屋","resident":"ranger","color":"4e8f9f","pos":Vector3(-5,0,-7),"angle":-8.0},
 "medic":{"title":"白芷的绿屋","resident":"medic","color":"78965c","pos":Vector3(2,0,-7),"angle":7.0},
 "engineer":{"title":"砾的黄屋","resident":"engineer","color":"d1aa54","pos":Vector3(8,0,-2),"angle":-12.0},
 "shield":{"title":"岳峙的白屋","resident":"warden","color":"c1beb1","pos":Vector3(7,0,5),"angle":-8.0},
 "memory":{"title":"阿禾的蓝门","resident":"","color":"6583a8","pos":Vector3(0,0,7),"angle":0.0}}
const HOME_LINES={
 "lodger":["暂住","屋内的声音","“被褥晒过了。门有点紧，抬一下再关。”\n桌上放着半碗热汤。你把从故乡带出来的行李放在床脚，没有打开。"],
 "blade":["留一截线","阿凌","“袖口又开了。你那件也给我，线还有。”\n她把针夹在唇间，腾出手把窗边的椅子挪给你。"],
 "ranger":["旧路","鸦","“往北的兽径，以前到河边就断了。最近对岸也全是脚印。”\n他把一张用旧的地图压在石头底下，拿起门后的弓。"],
 "medic":["药架","白芷","“上层那包别动，是给隔壁留的。”\n她把余下的药分成更小的几份。门外晾着洗净的绷带，颜色已经泛黄。"],
 "engineer":["半桶漆","砾","“自己的屋顶还漏着呢。”\n他嘴上这样说，手里却在削给阿禾家补窗用的木条。墙角那半桶蓝漆已经结了皮。"],
 "shield":["明天的份","岳峙","“锅里还有。吃完把盖子盖好。”\n他在一块木片上记明天要领的粮，划掉一个数，停了一会儿，又写回去。"],
 "memory":["主人不在","门边的邻居","“阿禾住这儿。你找他？”\n对方把松动的门扣重新拧紧。\n“他过世好几年了。下雨前得把这边修好。”"]}
const RETURN_LINES={
 "lodger":["行李架","屋门口","你离开的这几天，有人在床边钉了一个架子。\n下面留着一张纸：“别都放地上，会受潮。”"],
 "blade":["不够的床位","阿凌","“昨晚又来了两个人。我让他们先挤一晚。”\n她数了数墙上的外衣。\n“再来人……得和大家商量。粮食没多出来。”"],
 "ranger":["幼兽的脚印","鸦","“里面夹着小的脚印。它们把窝也搬出来了。”\n他用指尖量了量泥里的凹痕，没有接着往下说。"],
 "medic":["空屋里的药","白芷","“他以前总忘记来拿，我就送过去。”\n她把药包放进阿禾家的旧木匣，又带走上一包。\n“知道用不上。顺路看看屋子。”"],
 "engineer":["借来的钉子","砾","“东边那几户也在找木料。先别答应把整车都给他们。”\n他挑出几枚直钉递给你。\n“这点够修门。剩下的，我们自己要过冬。”"],
 "shield":["照旧叫它","岳峙","“从阿禾家左边过去，井就在后头。”\n他见你迟疑，补了一句：\n“我们一直这么叫。”"],
 "memory":["门牌背面","补窗时发现的字","门牌背面写着歪斜的几行字，像是给修屋人的叮嘱：\n“左边那扇窗留个缝。天晴时，让屋里透透气。”"]}
const REGIONAL={
 "border":[["越过河的兽径","断桥边的猎人","“以前在北坡才见得到。现在连小的都过河了。”\n泥里挤着大小不同的足印，朝同一个方向去。"],["新立的界桩","古道旁","旧兽径被一排新木桩截断。桩后是刚翻过的土，桩前散着被踩碎的蛋壳。"],["搬走的巢","哨站背坡","石缝里留着干草和半截咬断的绳。你翻过那片山坡，看见更远处有人在围田。"]],
 "wood":[["空树洞","林间","树洞里还有毛，草窝却已经冷了。猎人说去年这里不能靠近，今年一路都没听到动静。"],["借一条路","林边的争执","“你们的车压坏了水沟。”\n“另一条路已经灰了。我们只剩这条。”\n两个人隔着坏掉的木栅站着。"],["搬家的痕迹","林地尽头","旧巢边连幼兽常啃的树皮也被剥了下来。向南的泥路上，车辙和兽足印重叠。"]],
 "waste":[["降下来的箱子","商队伙计","“头一回下来，箱子里装的都是土。还以为他们拿土换粮。”\n他把空袋翻过来，拍了拍底。"],["一袋旧土","被遗落的木箱","箱内的土结成硬块，夹着枯死的细根。箱盖反复描着一块悬石的轮廓，没有文字。"],["开垦者的账","商路残页","“水桶两只，锄头三把。种子欠一袋。”\n后面的几页全是划掉的地名。最末一行写着：“再往南试。”"]],
 "frost":[["不再上去","山路上的遗民","“上头那间屋子朝东。早上不用点灯。”\n他看了一会儿天，问你能不能匀一副手套。"],["田留在上面","守着行李的人","“下来的时候还没收。想着很快就能回去。”\n行李最底下压着一把镰刀，刀柄磨得发亮。"],["冻住的窗框","山隘旧营","窗框被当作雪橇底板，蓝漆在接地的一侧磨没了。上面用小字刻着几个人的身高。"]],
 "marsh":[["最后一口井","取水的人","“昨天还在这儿。”\n他指着塌下去的井沿，提起只有薄薄一层泥水的桶。"],["同一块高地","沼泽边","一边铺着人的睡席，一边是新压倒的芦苇窝。它们都退到了这块尚未发灰的高地。"],["分水","营地留下的刻痕","木桶上刻着一道道分量。有人在最后一道旁边又划了一条，更低。桶底藏着一只小碗。"]],
 "ruins":[["仰头的人","遗城外围","老人抬头看着悬石。他说不出那里从前叫什么，只说家里的门也是朝东开的。"],["两处灰线","残墙上的记号","有人把地面的灰线抄在墙上，旁边另一张纸画着悬石的边缘。两个日期之间，只隔了几天。"],["带回去的颜色","倒塌的住处","墙下压着几只密封的漆罐。开封的一罐已经干了，罐沿留下蓝色指印。你想起村里那扇总有人修的门。"]]}
static func initial_state() -> Dictionary:
 return {"seen":[],"repaired":[],"repair_expedition":0}
static func all_ids() -> Array:
 var ids=["arrival"]
 for home in HOMES:ids.append("home_"+home);ids.append("return_"+home);ids.append("absence_"+home)
 for region in REGIONAL:
  for suffix in ["approach","trace","after"]:ids.append(region+"_"+suffix)
 return ids
static func valid_state(state) -> bool:
 if not state is Dictionary:return false
 if not state.get("seen") is Array or not state.get("repaired") is Array:return false
 for pair in [[state.seen,all_ids()],[state.repaired,HOMES.keys()]]:
  var unique=[]
  for id in pair[0]:
   if not id is String or id not in pair[1] or id in unique:return false
   unique.append(id)
 var value=state.get("repair_expedition")
 return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=1000000 and float(value)==floor(float(value))
static func fragment(id: String) -> Dictionary:
 if id=="arrival":return {"id":id,"title":"一碗热汤","source":"初来时","text":"村里的火烧到屋顶时，你从北边逃了出来。\n你记得兽群冲过栅栏的声音，之后的路却断断续续。\n\n荒野尽头露出几间有颜色的屋子。有人放下手里的木板，把你领进门。\n“先坐。汤还热着。”"}
 var line=[]
 if id.begins_with("absence_"):
  var home_id=id.trim_prefix("absence_")
  if not HOMES.has(home_id):return {}
  return {"id":id,"title":HOMES[home_id].title+" · 留下的住处","source":"归来后","text":"这次，屋子里没有人应声。
邻居把门前扫干净，松动的窗扣也重新钉好了。
门牌没有换过。"}
 if id.begins_with("home_"):line=HOME_LINES.get(id.trim_prefix("home_"),[])
 elif id.begins_with("return_"):line=RETURN_LINES.get(id.trim_prefix("return_"),[])
 else:
  for region in REGIONAL:
   var index=[region+"_approach",region+"_trace",region+"_after"].find(id)
   if index>=0:line=REGIONAL[region][index];break
 if line.is_empty():return {}
 return {"id":id,"title":line[0],"source":line[1],"text":line[2]}
static func available_home_fragment(state: Dictionary,home: String,expedition: int) -> String:
 if not HOMES.has(home):return ""
 if "home_"+home not in state.seen:return "home_"+home
 if expedition>0 and "return_"+home not in state.seen:return "return_"+home
 return ""
static func route_fragment(region: String,depth: int,boss: bool) -> String:
 if not REGIONAL.has(region):return ""
 return region+("_after" if boss else "_trace" if depth>=3 else "_approach")
