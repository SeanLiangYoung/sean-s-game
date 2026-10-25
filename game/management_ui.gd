extends RefCounted
const Compact=preload("res://game/compact_ui.gd")
const Equipment=preload("res://game/equipment_menu.gd")
const PAGE_SIZE=6

static func details(host,parent: Control,title: String,content: String) -> Button:
 var entry=host.details_button(parent,title,content);entry.name="ItemDetails"
 return entry

static func relic_content(host,parent: Control,entry):
 var d=host.Campaign.Relic.definition(entry)
 var bound=entry is Dictionary and entry.get("owner","")!=""
 var scope="全队" if d.scope=="team" else "个人 · 已绑定" if bound else "个人 · 需绑定"
 var charges="持续" if d.uses==0 else "剩余 %d / %d"%[entry.get("remaining",d.uses) if entry is Dictionary else d.uses,d.uses]
 Compact.metrics(host,parent,[["team" if d.scope=="team" else "person",scope,"遗物作用范围"],["relic",charges,"持续生效" if d.uses==0 else "触发次数 · 耗尽损毁"]])
 parent.add_child(host.text_label("收益："+d.benefit,14,host.TEAL))
 parent.add_child(host.text_label("代价："+d.risk,14,host.RED))

static func catalog(host,family: String,query: String,page: int):
 host.open_modal("遗物图鉴 · 已解锁 %d / %d 件"%[host.campaign.discovered_relics.size(),host.Campaign.Relic.CATALOG.size()],"在奖励或商店中见过即可解锁 · 未见过的遗物尚未解锁")
 host.set_page_back(func():host.show_party_menu("遗物",host.menu_character))
 if host.campaign.discovery_save_failed:host.modal_body.add_child(host.text_label("遗物发现记录保存失败，请重试保存后再开始新游戏。",16,host.RED))
 var header=Compact.pin_header(host)
 header.add_child(host.text_label("当前主题 · "+(host.Campaign.Relic.Expansion.SETS[family].name if host.Campaign.Relic.Expansion.SETS.has(family) else "全部"),16,host.GOLD))
 var filters=HFlowContainer.new();filters.name="CatalogFilters";filters.add_theme_constant_override("h_separation",6);header.add_child(filters)
 filters.add_child(Compact.symbolize(host.button("全部",func():host.show_relic_catalog("",query,0),family==""),"all"))
 for id in host.Campaign.Relic.Expansion.SETS:
  var theme_id=id;var theme=host.Campaign.Relic.Expansion.SETS[id]
  filters.add_child(Compact.symbolize(host.button(theme.name,func():host.show_relic_catalog(theme_id,query,0),family==id),{"blood":"blood","hunt":"range","ward":"armor","arcane":"skill","engine":"engine","pilgrim":"life","dusk":"moon","command":"flag"}[id]))
 var search_row=HBoxContainer.new();header.add_child(search_row)
 var search=LineEdit.new();search.name="CatalogSearch";search.placeholder_text="搜索遗物名称 / 效果";search.text=query
 search.size_flags_horizontal=Control.SIZE_EXPAND_FILL;search.custom_minimum_size.y=44;search_row.add_child(search)
 search.text_submitted.connect(func(value):host.show_relic_catalog(family,value,0))
 search_row.add_child(Compact.symbolize(host.button("搜索",func():host.show_relic_catalog(family,search.text,0)),"search"))
 search_row.add_child(Compact.symbolize(host.button("清空",func():host.show_relic_catalog(family,"",0)),"clear"))
 var matches=[];var needle=query.strip_edges().to_lower()
 for id in host.Campaign.Relic.CATALOG:
  if id not in host.campaign.discovered_relics:continue
  var d=host.Campaign.Relic.definition(id)
  if family!="" and d.get("family","")!=family:continue
  if needle!="" and needle not in (d.name+" "+d.benefit+" "+d.risk).to_lower():continue
  matches.append(id)
 var pages=maxi(1,int(ceil(matches.size()/float(PAGE_SIZE))));page=clampi(page,0,pages-1)
 var grid=Compact.grid(host.modal_body,3);grid.name="RelicCatalogGrid"
 for id in matches.slice(page*PAGE_SIZE,(page+1)*PAGE_SIZE):
  var d=host.Campaign.Relic.definition(id)
  var card=Compact.card(host,grid,d.name,Color(d.color),Equipment.icon("relic"));card.get_parent().name="CatalogRelic_"+id
  relic_content(host,card,id)
  details(host,card,d.name+" · 详情",host.Campaign.Relic.description(id))
 if matches.is_empty():host.modal_body.add_child(host.text_label("没有匹配的已解锁遗物，继续探索旅途或更换筛选。",18,host.MUTED))
 var navigation=HBoxContainer.new();navigation.add_theme_constant_override("separation",12);host.modal.get_child(0).add_child(navigation)
 var previous=host.button("上一页",func():host.show_relic_catalog(family,query,page-1));Compact.symbolize(previous,"back");previous.name="CatalogPrevious";previous.disabled=page==0;navigation.add_child(previous)
 var count=host.text_label("第 %d / %d 页 · 匹配 %d 件"%[page+1,pages,matches.size()],16,host.GOLD)
 count.size_flags_horizontal=Control.SIZE_EXPAND_FILL;count.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;navigation.add_child(count)
 var next=host.button("下一页",func():host.show_relic_catalog(family,query,page+1));Compact.symbolize(next,"next");next.name="CatalogNext";next.disabled=page>=pages-1;navigation.add_child(next)

static func trade(host,category: String=""):
 var shop=host.campaign.at_node("shop")
 var state=host.get_meta("trade_filter",{})
 if state.get("node","")!=host.campaign.route.current:state={"node":host.campaign.route.current,"category":"全部"}
 if category!="":state.category=category
 host.set_meta("trade_filter",state)
 host.open_modal("行路商店" if shop else "佣兵营地","返回路线后可继续选择分支 · 离开节点后不能返回")
 var header=Compact.pin_header(host)
 Compact.metrics(host,header,[["silver",host.campaign.silver,"银币"],["supply",host.campaign.supplies,"补给"],["team","%d / 10"%host.campaign.roster.size(),"队伍人数上限"]],"ShopBalance")
 if not shop:
  hire(host);return
 var bar=HFlowContainer.new();bar.add_theme_constant_override("h_separation",8);header.add_child(bar)
 for label in ["全部","装备","遗物","物品"]:
  var filter=label;bar.add_child(Compact.symbolize(host.button(label,func():host.show_route_trade(filter),state.category==label),{"全部":"all","装备":"equipment","遗物":"relic","物品":"items"}[label]))
 details(host,bar,"交易规则","每件商品每处限购一次；本次远征首次购买遗物优惠15银币，后续按原价。个人遗物需要选择佩戴者并确认替换。")
 header.add_child(host.text_label(state.category,16,host.GOLD))
 var grid=Compact.grid(host.modal_body,2);grid.name="ShopGrid"
 var count=0
 for id in host.campaign.shop_inventory():
  if id in host.Jobs.ALL_SKILLS:continue
  var kind="装备" if host.Jobs.ITEMS.has(id) else "遗物" if host.Campaign.Relic.CATALOG.has(id) else "物品"
  if state.category!="全部" and kind!=state.category:continue
  count+=1
  var item_id=id;var good=host.Campaign.GOODS[id];var quote=host.campaign.shop_price(id)
  var texture=Equipment.icon(host.Jobs.ITEMS[id].kind) if kind=="装备" else Equipment.icon("relic") if kind=="遗物" else Compact.icon("book")
  var card=Compact.card(host,grid,good.name,host.GOLD,texture);card.get_parent().name="ShopItem_"+id
  if kind=="遗物":
   host.campaign.discover_relic(id)
   relic_content(host,card,id)
  elif kind=="装备":
   var item=host.Jobs.ITEMS[id]
   card.add_child(host.text_label(host.Jobs.SLOTS[item.slot]+" · %d档"%item.tier,14,host.MUTED))
   Compact.metrics(host,card,[["attack",item.power,"装备攻击"],["armor",item.armor,"装备防护"],["range",item.get("range",0),"装备武器射程；护甲/副手不改变武器射程"]])
  else:card.add_child(host.text_label(good.desc,14,host.TEAL))
  var actions=HBoxContainer.new();card.add_child(actions);details(host,actions,good.name+" · 详情",good.desc)
  var reason="已售罄" if host.campaign.route.current+":"+id in host.campaign.purchases else "银币不足" if host.campaign.silver<quote else ""
  var buy=host.button(("购买 · %d 银币"%quote) if reason=="" else reason+" · %d银币"%quote,func():
   if host.Campaign.Relic.CATALOG.has(item_id) and host.Campaign.Relic.definition(item_id).scope=="personal":host.show_relic_binding(item_id)
   elif host.campaign.buy(item_id):host.refresh_ui();host.show_route_trade(),reason=="")
  Compact.symbolize(buy,"buy","购买 "+good.name+" · %d银币"%quote+(" · "+reason if reason!="" else ""),str(quote))
  if reason!="":card.add_child(host.text_label(reason,14,host.MUTED))
  buy.name="BuyItem";buy.disabled=reason!="";buy.size_flags_horizontal=Control.SIZE_EXPAND_FILL;actions.add_child(buy)
 if count==0:host.modal_body.add_child(host.text_label("此分类暂无商品。",17,host.MUTED))
 var exit=Compact.symbolize(host.button("继续旅途",host.close_modal),"next");host.primary_action(exit);exit.size_flags_horizontal=Control.SIZE_SHRINK_END

static func hire(host):
 var grid=Compact.grid(host.modal_body,2);grid.name="RecruitGrid"
 var candidates=host.campaign.recruit_candidates()
 for i in candidates.size():
  var index=i;var id=candidates[i];var d=host.Campaign.Characters.CATALOG[id]
  var card=Compact.card(host,grid,d.name+" · "+host.Jobs.JOBS[d.job].name,host.GOLD,host.portraits.portrait(id,host.Campaign.Characters.create(id)))
  card.add_child(host.text_label("天赋 · "+d.talent,15,host.TEAL))
  details(host,card,d.name+" · 人物与天赋",d.story+"\n\n"+d.talent+"："+d.effect+"\n\n遗物搭配："+d.relics)
  var existing=host.campaign.roster.any(func(u):return u.get("character_id","")==id)
  var reason="已在佣兵团中" if existing else "队伍已满" if host.campaign.roster.size()>=10 else "银币不足" if host.campaign.silver<55 else ""
  var entry=host.button("招募 · 55 银币" if reason=="" else reason,func():
   if host.campaign.hire(index):host.refresh_ui();host.show_route_trade(),reason=="")
  Compact.symbolize(entry,"hire","招募 "+d.name+" · 55银币"+(" · "+reason if reason!="" else ""),"55")
  if reason!="":card.add_child(host.text_label(reason,14,host.MUTED))
  entry.disabled=not host.campaign.can_hire(i);card.add_child(entry)
 var exit=Compact.symbolize(host.button("继续旅途",host.close_modal),"next");host.primary_action(exit);exit.size_flags_horizontal=Control.SIZE_SHRINK_END

static func owned_relics(host,parent: Control,effects_only: bool):
 var pools=[host.campaign.relics,host.campaign.collection] if host.battle==null else [host.battle.relic_state,[]]
 var applicable=[]
 for pool in pools:
  for entry in pool:
   var d=host.Campaign.Relic.definition(entry)
   if d.scope=="team" or (entry is Dictionary and entry.owner==host.menu_character):applicable.append(entry)
 var resonance=host.details_button(parent,"当前角色共鸣 · "+host.menu_unit(host.menu_character).name,host.Campaign.Relic.resonance_description(applicable))
 resonance.name="ResonanceDetails"
 var grid=Compact.grid(parent,2);grid.name="OwnedRelics"
 for pool_index in pools.size():
  for entry in pools[pool_index]:
   var d=host.Campaign.Relic.definition(entry)
   if effects_only and d.scope=="personal" and (not entry is Dictionary or entry.owner!=host.menu_character):continue
   var card=Compact.card(host,grid,d.name,Color(d.color),Equipment.icon("relic"))
   var source="永久收藏" if pool_index==1 else "本次远征" if host.battle==null else "本场持有"
   card.add_child(host.text_label(source+(" · 佩戴者："+host.menu_unit(entry.owner).name if d.scope=="personal" and entry is Dictionary else ""),14,host.MUTED))
   relic_content(host,card,entry)
   details(host,card,d.name+" · 效果与触发详情",host.Campaign.Relic.description(entry)+"\n\n"+host.relic_instance_status(entry))
 if grid.get_child_count()==0:parent.add_child(host.text_label("暂无生效遗物。探索并安全撤离可积累收藏。",16,host.MUTED))
 if effects_only and host.menu_unit(host.menu_character).hp<=0:parent.add_child(host.text_label("角色已阵亡，无法享受战斗效果。",15,host.RED))

static func binding(host,id: String,reward_index: int):
 var d=host.Campaign.Relic.definition(id)
 host.open_modal("绑定个人遗物 · "+d.name,"绑定后不能卸下或转交 · 替换会永久失去旧遗物")
 host.set_page_back(func():
  if reward_index>=0:host.show_reward()
  else:host.show_route_trade())
 var header=Compact.pin_header(host)
 relic_content(host,header,id)
 details(host,header,"完整触发与共鸣",host.Campaign.Relic.description(id))
 var cost=host.campaign.shop_price(id) if reward_index<0 else 0
 if reward_index<0:Compact.metrics(host,header,[["silver","本次 %d / 持有 %d"%[cost,host.campaign.silver],"确认绑定时扣款"]])
 var grid=Compact.grid(host.modal_body,2)
 for unit in host.campaign.roster:
  if unit.hp<=0:continue
  var owner_id=unit.id;var old=host.campaign.personal_relic(owner_id)
  var card=Compact.card(host,grid,unit.name+" · "+unit.role,host.GOLD,host.portraits.portrait(unit.id,host.campaign.visual_profile(unit.id)))
  card.add_child(host.text_label("空遗物栏" if old.is_empty() else "替换并失去："+host.Campaign.Relic.definition(old).name,15,host.TEAL if old.is_empty() else host.RED))
  var reason="银币不足" if reward_index<0 and host.campaign.silver<cost else ""
  var bind=host.button("绑定给 "+unit.name+" · 接受收益与代价"+(" · "+reason if reason!="" else ""),func():
   if reward_index>=0:
    if host.campaign.choose_reward(reward_index,owner_id):host.return_world()
   elif host.campaign.buy(id,owner_id):host.refresh_ui();host.show_route_trade(),reason=="")
  Compact.symbolize(bind,"bind")
  if reason!="":card.add_child(host.text_label(reason,14,host.MUTED))
  bind.add_theme_font_size_override("font_size",15);bind.disabled=reason!="";card.add_child(bind)
