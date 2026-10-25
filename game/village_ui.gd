extends RefCounted
const Story=preload("res://game/village_story.gd")
static func frame(host,parent,pos,size):
 var p=host.panel(parent,pos,size)
 p.add_theme_stylebox_override("panel",host.style(Color(0.07,0.12,0.15,0.93),Color("65736e"),8))
 return p
static func render(host,atlas):
 var heading=host.text_label("灰烬行旅  /  归处",29,host.CREAM);heading.position=Vector2(42,27);heading.size=Vector2(650,46);atlas.add_child(heading)
 var hint=host.text_label("风从荒野吹来。屋子都有自己的颜色。",16,Color("e2e0cd"));hint.position=Vector2(44,76);hint.size=Vector2(720,30);atlas.add_child(hint)
 var menu=frame(host,atlas,Vector2(1152,28),Vector2(250,0))
 var actions=VBoxContainer.new();actions.name="VillageActions";actions.add_theme_constant_override("separation",9);menu.add_child(actions)
 actions.add_child(host.text_label("屋檐下",22,host.GOLD))
 host.Compact.metrics(host,actions,[["silver",host.campaign.silver,"银币"],["supply",host.campaign.supplies,"补给"]])
 actions.add_child(host.button("选择远征",host.depart,true))
 actions.add_child(host.button("队伍与装备",func():host.show_party_menu("详情")))
 actions.add_child(host.button("遗物构筑",func():host.show_relic_strategy()))
 actions.add_child(host.button("旅途见闻 · %d"%host.campaign.story_state.seen.size(),host.show_village_journal))
 if host.campaign.expedition==0:actions.add_child(host.button("初来时 · 一碗热汤",func():opening(host)))
 actions.add_child(host.button("保存与菜单",host.show_pause_menu))
 var caption=host.text_label("点击屋旁门牌，拜访或帮忙修缮。\n远征归来后，有余力照顾一间屋子。",14,host.MUTED);actions.add_child(caption)
 var note=frame(host,atlas,Vector2(42,803),Vector2(1065,64))
 var message=host.campaign.notice if host.campaign.expedition>0 else "你暂住在那间赭黄色的小屋。先熟悉这里，再决定往哪里去。"
 note.add_child(host.text_label(message,16,host.CREAM))
 for id in Story.HOMES:
  var home_id=id;var d=Story.HOMES[id]
  var unit=host.campaign.roster.filter(func(u):return u.id==d.resident)
  var dead=id=="memory" or (not unit.is_empty() and unit[0].hp<=0)
  var entry=host.button(d.title,func():host.show_village_home(home_id))
  entry.name="Door_"+id;entry.add_theme_font_size_override("font_size",14);entry.custom_minimum_size=Vector2(138,30)
  for state in ["normal","hover","pressed"]:
   var plaque=host.style(Color(0.08,0.14,0.16,0.87),Color("9f9c7c") if state!="normal" else Color("63716b"),4)
   plaque.content_margin_left=9;plaque.content_margin_right=9;plaque.content_margin_top=5;plaque.content_margin_bottom=5
   entry.add_theme_stylebox_override(state,plaque)
  var pos=host.camera.unproject_position(d.pos+Vector3(0,0,2.7))
  entry.position=pos-Vector2(69,-6)
  entry.tooltip_text="房屋仍替主人保留" if dead else "拜访 · "+d.title
  if Story.available_home_fragment(host.campaign.story_state,id,host.campaign.expedition)!="":entry.text="· "+entry.text
  atlas.add_child(entry)
static func home(host,id: String):
 if host.campaign.phase!="camp" or not Story.HOMES.has(id):return
 var d=Story.HOMES[id];var learned=host.campaign.read_home(id)
 var unit=host.campaign.roster.filter(func(u):return u.id==d.resident)
 var dead=id=="memory" or (not unit.is_empty() and unit[0].hp<=0)
 host.open_modal(d.title,"门扣和窗框都被人照料着。" if dead else "屋外有风，屋里还留着暖意。")
 host.modal.get_parent().color=Color(0.03,0.07,0.09,0.42)
 host.modal.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 host.modal.position=Vector2(285,120);host.modal.size=Vector2(850,640)
 host.modal.add_theme_stylebox_override("panel",host.style(Color(0.06,0.11,0.14,0.97),Color("6b7d78"),10))
 host.set_page_back(host.close_modal)
 if not unit.is_empty() and unit[0].hp<=0:
  host.modal_body.add_child(host.text_label("%s没有回来。门牌还在，邻居把屋前扫干净了。"%unit[0].name,21,host.CREAM))
  host.modal_body.add_child(host.text_label("他的屋子仍替他保留着。",17,host.MUTED))
 else:
  if learned=="":
   learned=("return_" if "return_"+id in host.campaign.story_state.seen else "home_")+id
  var fragment=Story.fragment(learned)
  host.modal_body.add_child(host.text_label(fragment.title,25,host.GOLD))
  host.modal_body.add_child(host.text_label(fragment.text,21,host.CREAM))
  host.modal_body.add_child(host.text_label("—— "+fragment.source,15,host.MUTED))
 var line="屋角多了一块新木板，窗框也重新上了色。" if id in host.campaign.story_state.repaired else "有余力时，可以用邻居留下的木料补一处破损。"
 host.modal_body.add_child(host.text_label(line,17,host.TEAL))
 var can_repair=host.campaign.expedition>int(host.campaign.story_state.repair_expedition) and id not in host.campaign.story_state.repaired
 var repair=host.button("帮忙修缮 · 本次归来的一份余力" if can_repair else "已修缮" if id in host.campaign.story_state.repaired else "远征归来后再来帮忙",func():
  if host.campaign.repair_home(id):
   host.draw_world();host.refresh_ui();host.show_village_home(id))
 repair.disabled=not can_repair;host.modal_body.add_child(repair)
 host.modal_body.add_child(host.text_label("不消耗银币或补给；每次远征后可照顾一间尚未修缮的屋子。",14,host.MUTED))
 host.modal_body.add_child(host.button("走回村中",func():host.close_modal();host.refresh_ui(),true))
static func journal(host):
 host.open_modal("旅途见闻","只记下亲眼所见、亲耳所闻。")
 host.set_page_back(host.close_modal)
 if host.campaign.story_state.seen.is_empty():host.modal_body.add_child(host.text_label("还没有记下什么。去看看那些有颜色的屋子吧。",20))
 for id in host.campaign.story_state.seen:
  var entry=Story.fragment(id)
  host.modal_body.add_child(host.button(entry.title+" · "+entry.source+"  ›",func():host.show_details(entry.title,entry.text)))
 host.modal_body.add_child(host.button("合上手记",host.close_modal,true))
static func opening(host):
 var entry=Story.fragment("arrival")
 host.campaign.discover_story("arrival");host.campaign.save_game()
 host.open_modal(entry.title,"荒野尽头，一点颜色。")
 host.menu_screen="arrival"
 host.set_page_back(Callable())
 host.modal_body.add_child(host.text_label(entry.text,23))
 host.modal_body.add_child(host.button("放下行李 · 走进村庄",func():host.close_modal();host.refresh_ui(),true))
