extends SceneTree
const Campaign=preload("res://game/campaign.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func texts(node):
 var result=""
 if node is Label or node is Button:result+=node.text+"\n"
 for child in node.get_children():result+=texts(child)
 return result
func named(node,id):return node.find_child(id,true,false)
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1280,800)
 var s=load("res://game/main.tscn").instantiate();root.add_child(s);await process_frame
 s.set_process(false);s.campaign=Campaign.new("user://management-ui-test.json")
 s.show_party_menu("详情","medic")
 var character=s.campaign.Characters.definition(s.menu_unit("medic"))
 check(character.story not in texts(s.modal),"biography not dumped in primary character page")
 var bio=named(s.modal,"CharacterBiography")
 check(bio!=null,"character biography has explicit detail action")
 if bio!=null:check(bio.text=="" and bio.icon!=null and bio.tooltip_text!="" and bio.accessibility_name!="","detail actions use semantic accessible icon buttons")
 check(named(s.modal,"CharacterMetrics")!=null,"character stats use icon metrics")
 if bio!=null:
  var page=s.modal;var before=s.campaign.to_data()
  bio.pressed.emit()
  check(character.story in texts(s.detail_overlay) and character.effect in texts(s.detail_overlay),"full biography and talent preserved in details")
  s.close_details()
  check(s.modal==page and s.menu_character=="medic" and s.campaign.to_data()==before,"details preserve selected character and campaign")
 s.show_party_menu("技能","hero")
 await process_frame;await process_frame
 check(named(s.modal,"PartyToolbar").size.y<80,"party title stays in a compact horizontal toolbar")
 check(s.modal.get_child(0).get_child(1).size.y<65,"icon tabs and current section remain a single compact row")
 var train=s.modal.find_children("*","Button",true,false).filter(func(entry):return entry.text.begins_with("强化破势") or entry.accessibility_name.begins_with("强化破势"))[0]
 check(train.get_global_rect().end.y<=named(s.modal,"CharacterPageScroll").get_global_rect().end.y,"selected skill training action visible without scrolling")
 s.close_modal();s.campaign.start_region("border");s.campaign.route.setup("border");s.campaign.encounters=["open","open","open"]
 s.campaign.enter_route("0b");s.campaign.silver=1000
 s.show_route_trade()
 var grid=named(s.modal,"ShopGrid")
 check(grid!=null,"shop uses actionable comparison cards")
 if grid!=null:
  var stock=s.campaign.shop_inventory().filter(func(id):return id not in s.Jobs.ALL_SKILLS)
  check(grid.get_child_count()==stock.size(),"shop cards match real stock")
  var id=stock.filter(func(item):return not s.Campaign.Relic.CATALOG.has(item) or s.Campaign.Relic.definition(item).scope=="team")[0]
  var card=named(s.modal,"ShopItem_"+id)
  var before=s.campaign.to_data();var detail=named(card,"ItemDetails")
  check(s.Campaign.GOODS[id].name in detail.tooltip_text,"shop detail identifies the corresponding item")
  for item in stock:
   if item not in s.Jobs.ITEMS and item not in s.Campaign.Relic.CATALOG:
    var book_card=named(s.modal,"ShopItem_"+item)
    var image=book_card.find_children("*","TextureRect",true,false)[0]
    check(image.texture==preload("res://game/compact_ui.gd").icon("book"),"skill book stock uses recognizable book icon")
  detail.pressed.emit();check(s.campaign.to_data()==before,"viewing shop details cannot buy")
  s.close_details()
  var cost=s.campaign.shop_price(id);named(card,"BuyItem").pressed.emit()
  check(s.campaign.silver==1000-cost,"purchase uses actual quoted price")
  check(named(named(s.modal,"ShopItem_"+id),"BuyItem").disabled,"purchased item becomes sold out")
  s.campaign.silver=0;s.show_route_trade()
  for buy in s.modal.find_children("BuyItem","Button",true,false):check(buy.disabled,"unaffordable goods cannot be bought")
 s.campaign.silver=1000;s.campaign.acquire_relic("candle","hero");s.show_route_trade("遗物")
 var echo=named(s.modal,"ShopItem_echo")
 var before_binding=s.campaign.to_data();named(echo,"BuyItem").pressed.emit()
 check("替换并失去：续命烛芯" in texts(s.modal),"binding shows irreversible replacement before payment")
 check(s.campaign.to_data()==before_binding,"opening binding does not spend silver or acquire relic")
 s.navigate_back()
 check(named(s.modal,"ShopItem_sword")==null and named(s.modal,"ShopItem_echo")!=null,"cancel binding retains shop category")
 check(s.campaign.to_data()==before_binding,"cancel binding leaves inventory and money unchanged")
 var quote=s.campaign.shop_price("echo");named(named(s.modal,"ShopItem_echo"),"BuyItem").pressed.emit()
 var bind=s.modal.find_children("*","Button",true,false).filter(func(entry):return entry.text.begins_with("绑定给 沈烬") or entry.accessibility_name.begins_with("绑定给 沈烬"))[0]
 bind.pressed.emit()
 check(s.campaign.personal_relic("hero").id=="echo" and s.campaign.silver==1000-quote,"explicit binding buys and replaces exactly once")
 check(named(named(s.modal,"ShopItem_echo"),"BuyItem").disabled,"bound purchase becomes sold out")
 s.campaign.books=["focus"];s.show_party_menu("技能","medic")
 named(s.modal,"SkillBooks").pressed.emit()
 var learn=s.modal.find_children("*","Button",true,false).filter(func(entry):return "技能书 · 调息 →" in entry.text or "技能书 · 调息 →" in entry.accessibility_name)[0]
 learn.pressed.emit()
 check("focus" in s.menu_unit("medic").learned and "focus" not in s.menu_unit("hero").learned,"book learning affects selected character only")
 check(s.campaign.books.is_empty() and s.menu_character=="medic" and s.menu_tab=="技能","learning consumes one book and returns to selected skill page")
 s.campaign.phase="camp";s.show_party_menu("职业","medic")
 var retrain=s.modal.find_children("*","Button",true,false).filter(func(entry):return entry.text=="转职为 游剑客" or entry.accessibility_name=="转职为 游剑客")[0]
 var money=s.campaign.silver;retrain.pressed.emit()
 check(s.menu_unit("medic").profession=="blade" and s.campaign.silver==money,"profession action uses free camp retraining")
 s.show_party_menu("遗物","hero")
 check("个人 · 已绑定" in texts(s.modal) and "个人 · 需绑定" not in texts(s.modal),"owned personal relics display bound state accurately")
 for id in s.Campaign.Relic.CATALOG:s.campaign.discover_relic(id)
 s.show_relic_catalog()
 var search=named(s.modal,"CatalogSearch");var catalog=named(s.modal,"RelicCatalogGrid")
 check(search!=null and catalog!=null,"catalog exposes search and compact cards")
 if search!=null and catalog!=null:
  check(catalog.get_child_count()<=6,"catalog pages avoid unbounded content")
  var before=s.campaign.to_data();var first=catalog.get_child(0);var page=s.modal
  var first_detail=named(first,"ItemDetails")
  check(s.Campaign.Relic.definition(str(first.name).trim_prefix("CatalogRelic_")).name in first_detail.tooltip_text,"catalog detail identifies the corresponding relic")
  first_detail.pressed.emit();s.close_details()
  check(s.modal==page and s.campaign.to_data()==before,"catalog details preserve list and never acquire relics")
  search.text="百战军册";search.text_submitted.emit(search.text)
  check("百战军册" in texts(s.modal) and named(s.modal,"RelicCatalogGrid").get_child_count()==1,"search finds item beyond first page")
  search=named(s.modal,"CatalogSearch");search.text="不存在的遗物xyz";search.text_submitted.emit(search.text)
  check("没有匹配" in texts(s.modal),"empty catalog result explained")
  s.show_relic_catalog("blood")
  var visited=[];var loops=0
  while loops<30:
   for card in named(s.modal,"RelicCatalogGrid").get_children():visited.append(card.name.trim_prefix("CatalogRelic_"))
   var next=named(s.modal,"CatalogNext")
   if next.disabled:break
   next.pressed.emit();loops+=1
  var expected=s.Campaign.Relic.CATALOG.keys().filter(func(id):return s.Campaign.Relic.definition(id).get("family","")=="blood")
  check(visited.size()==expected.size() and expected.all(func(id):return id in visited),"pagination covers entire selected theme without loss")
  s.show_relic_catalog();visited=[];loops=0
  while loops<30:
   for card in named(s.modal,"RelicCatalogGrid").get_children():visited.append(card.name)
   var next=named(s.modal,"CatalogNext")
   if next.disabled:break
   next.pressed.emit();loops+=1
  check(visited.size()==s.Campaign.Relic.CATALOG.size() and s.Campaign.Relic.CATALOG.keys().all(func(id):return "CatalogRelic_"+id in visited),"all catalog items accessible through pagination")
  s.navigate_back();check(s.menu_tab=="遗物" and s.menu_character=="hero","catalog back returns to selected character relic page")
 s.queue_free();await process_frame
 for suffix in ["",".relics",".achievements"]:DirAccess.remove_absolute("user://management-ui-test.json"+suffix)
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
