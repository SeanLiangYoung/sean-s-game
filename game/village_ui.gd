extends RefCounted
const Story=preload("res://game/village_story.gd")
static func frame(host,parent,pos,size):
 var p=host.panel(parent,pos,size)
 p.add_theme_stylebox_override("panel",host.style(Color(0.07,0.12,0.15,0.93),Color("65736e"),8))
 return p
static func compact_button(host,text: String,action: Callable,accent: bool=false) -> Button:
 var entry=host.button(text,action,accent)
 entry.add_theme_font_size_override("font_size",16)
 entry.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 for state in ["normal","hover","pressed"]:
  var paint=host.style(host.GOLD if accent else Color(0.10,0.18,0.21,0.90),host.GOLD if state!="normal" else Color("526962"),5)
  paint.content_margin_left=12;paint.content_margin_right=12;paint.content_margin_top=8;paint.content_margin_bottom=8
  entry.add_theme_stylebox_override(state,paint)
 return entry
static func render(host,atlas):
 var heading=host.text_label("灰烬行旅  /  归处",25,host.CREAM);heading.position=Vector2(32,22);heading.size=Vector2(650,40);atlas.add_child(heading)
 var message=host.campaign.notice if host.campaign.expedition>0 else "你暂住在赭黄色的小屋。风从荒野吹来。"
 var hint=host.text_label(message,15,Color("e2e0cd"));hint.position=Vector2(34,65);hint.size=Vector2(890,54);atlas.add_child(hint)
 var menu=frame(host,atlas,Vector2.ZERO,Vector2.ZERO)
 menu.name="VillageDock";menu.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 menu.offset_left=24;menu.offset_right=-24;menu.offset_top=-88;menu.offset_bottom=-20
 var actions=HBoxContainer.new();actions.name="VillageActions";actions.add_theme_constant_override("separation",9);menu.add_child(actions)
 host.Compact.metrics(host,actions,[["silver",host.campaign.silver,"银币"],["supply",host.campaign.supplies,"补给"]])
 actions.add_child(compact_button(host,"选择远征",host.depart,true))
 actions.add_child(compact_button(host,"队伍与装备",func():host.show_party_menu("详情")))
 actions.add_child(compact_button(host,"遗物构筑",func():host.show_relic_strategy()))
 actions.add_child(compact_button(host,"旅途见闻",host.show_village_journal))
 var overview=compact_button(host,"村庄全景",host.show_village_overview);overview.name="VillageOverview";actions.add_child(overview)
 actions.add_child(compact_button(host,"保存与菜单",host.show_pause_menu))
 if host.campaign.expedition==0:
  var arrival=compact_button(host,"初来时 · 一碗热汤",func():opening(host))
  arrival.size_flags_horizontal=Control.SIZE_SHRINK_END;arrival.position=Vector2(1160,24);arrival.custom_minimum_size.x=245;atlas.add_child(arrival)
 for id in Story.HOMES:
  var home_id=id;var d=Story.HOMES[id]
  var entry=host.button("访",func():host.show_village_home(home_id))
  entry.name="Door_"+id;entry.add_theme_font_size_override("font_size",15);entry.custom_minimum_size=Vector2(34,30)
  entry.accessibility_name=d.title;entry.tooltip_text=d.title+" · 拜访与修缮"
  for state in ["normal","hover","pressed"]:
   var plaque=host.style(Color(0.08,0.14,0.16,0.72),Color(d.color).lightened(0.25),5)
   plaque.content_margin_left=7;plaque.content_margin_right=7;plaque.content_margin_top=3;plaque.content_margin_bottom=3
   entry.add_theme_stylebox_override(state,plaque)
  var title=host.text_label(d.title,16,host.CREAM);title.name="DoorTitle";title.mouse_filter=Control.MOUSE_FILTER_IGNORE
  title.position=Vector2(-57,35);title.size=Vector2(150,30);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  title.add_theme_stylebox_override("normal",host.style(Color(0.06,0.12,0.14,0.92),Color("6c8177"),4))
  title.hide();entry.add_child(title)
  entry.mouse_entered.connect(func():title.show())
  entry.mouse_exited.connect(func():title.hide())
  entry.focus_entered.connect(func():title.show())
  entry.focus_exited.connect(func():title.hide())
  atlas.add_child(entry)
 update_doors(host,atlas);update_overview(host)
 atlas.visible=not host.village_camera.is_home()
static func update_doors(host,atlas):
 var bounds=host.get_viewport().get_visible_rect()
 var safe=Rect2(Vector2(24,110),Vector2(bounds.size.x-48,bounds.size.y-225))
 for entry in atlas.get_children():
  if not entry is Button or not entry.name.begins_with("Door_"):continue
  var id=String(entry.name).trim_prefix("Door_")
  var d=Story.HOMES[id]
  var door=d.pos+Vector3(0,1.1,1.8).rotated(Vector3.UP,deg_to_rad(float(d.angle)))
  var pos=host.camera.unproject_position(door)
  entry.position=pos-Vector2(17,15)
  entry.visible=not host.camera.is_position_behind(door) and safe.has_point(pos)
static func update_overview(host):
 if not is_instance_valid(host.atlas) or not host.atlas.village_mode:return
 var button=host.atlas.find_child("VillageOverview",true,false)
 if button!=null:button.text="回到村中" if host.village_camera.view=="overview" else "村庄全景"
static func home(host,id: String):
 if host.campaign.phase!="camp" or not Story.HOMES.has(id):return
 var d=Story.HOMES[id];var learned=host.campaign.read_home(id)
 var unit=host.campaign.roster.filter(func(u):return u.id==d.resident)
 var dead=id=="memory" or (not unit.is_empty() and unit[0].hp<=0)
 host.open_modal(d.title,"门扣和窗框都被人照料着。" if dead else "屋外有风，屋里还留着暖意。")
 host.modal.get_parent().color=Color(0.03,0.07,0.09,0.08)
 host.modal.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
 host.modal.offset_left=-505;host.modal.offset_right=-24;host.modal.offset_top=76;host.modal.offset_bottom=-28
 host.modal.add_theme_stylebox_override("panel",host.style(Color(0.06,0.11,0.14,0.97),Color("6b7d78"),10))
 host.set_page_back(host.close_modal)
 host.village_camera.set_view(host,id)
 if is_instance_valid(host.atlas):host.atlas.hide()
 if not unit.is_empty() and unit[0].hp<=0:
  host.modal_body.add_child(host.text_label("%s没有回来。门牌还在，邻居把屋前扫干净了。"%unit[0].name,21,host.CREAM))
  host.modal_body.add_child(host.text_label("他的屋子仍替他保留着。",17,host.MUTED))
 else:
  if learned=="":
   learned=("return_" if "return_"+id in host.campaign.story_state.seen else "home_")+id
  var fragment=Story.fragment(learned)
  host.modal_body.add_child(host.text_label(fragment.title,25,host.GOLD))
  host.modal_body.add_child(host.text_label(fragment.text,19,host.CREAM))
  host.modal_body.add_child(host.text_label("—— "+fragment.source,15,host.MUTED))
 var line="屋角多了一块新木板，窗框也重新上了色。" if id in host.campaign.story_state.repaired else "有余力时，可以用邻居留下的木料补一处破损。"
 host.modal_body.add_child(host.text_label(line,17,host.TEAL))
 var can_repair=host.campaign.expedition>int(host.campaign.story_state.repair_expedition) and id not in host.campaign.story_state.repaired
 var repair=host.button("帮忙修缮" if can_repair else "已修缮" if id in host.campaign.story_state.repaired else "远征归来后再来帮忙",func():
  if host.campaign.repair_home(id):
   host.draw_world();host.refresh_ui();host.show_village_home(id))
 repair.disabled=not can_repair;host.modal_body.add_child(repair)
 host.modal_body.add_child(host.text_label("不消耗银币或补给；每次远征后可照顾一间尚未修缮的屋子。",14,host.MUTED))
 var back=host.button("走回村中",func():host.close_modal();host.refresh_ui(),true)
 host.primary_action(back)
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
