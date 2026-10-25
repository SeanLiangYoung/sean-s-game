extends RefCounted
const Jobs=preload("res://game/professions.gd")
const ATTRIBUTES=[["power","攻击"],["range","射程"],["armor","防护"],["speed","速度"],["max_ap","行动点"],["heal_bonus","装备治疗加成"],["skill_power","伤害战技"],["trap_power","机关伤害"],["shield_power","护盾吸收"],["mark_power","标记增伤"],["mana_power","法力支援"],["kill_mp","击杀回蓝"]]
static var icons={}

static func icon(kind: String) -> Texture2D:
 if icons.has(kind):return icons[kind]
 var shapes={
  "sword":'<path fill="#e4edf3" d="M26 39L47 7l8-2-1 9-23 30Z"/><path stroke="#8aabbc" d="M29 39L50 11"/><path fill="#deb35c" d="M20 32l17 13-4 5-17-13Z"/><path stroke="#b97b45" stroke-width="7" d="M24 43l-9 12"/><circle fill="#edc36c" cx="12" cy="57" r="4"/>',
  "dagger":'<path fill="#d3f0e8" d="M25 34L49 17l-8 23-10 4Z"/><path fill="#73b9b0" d="M28 37l17-14-14 21Z"/><path stroke="#d6a660" stroke-width="6" d="M20 32l16 15"/><path stroke="#965f49" stroke-width="8" d="M25 43l-9 10"/><circle fill="#d6a660" cx="13" cy="56" r="4"/>',
  "bow":'<path stroke="#dba05d" stroke-width="6" d="M18 8Q61 32 18 56"/><path stroke="#f4e0b2" d="M18 8l8 24-8 24"/><path stroke="#e8eef0" stroke-width="3" d="M10 32h45"/><path fill="#e8eef0" d="M47 25l11 7-11 7Z"/><path stroke="#865c3b" stroke-width="7" d="M40 27v10"/>',
  "staff":'<path stroke="#b88a53" stroke-width="7" d="M17 56L39 20"/><path fill="#c5a661" d="M28 17l5-12 15 3 6 13-16 9Z"/><path fill="#79e3b0" d="M33 17l4-9 8 3 4 9-10 5Z"/><path stroke="#e0ffdc" d="M38 12l-1 6"/><path stroke="#eed293" stroke-width="4" d="M25 37l8 4M22 43l8 4"/>',
  "crossbow":'<path stroke="#a77f53" stroke-width="9" d="M17 54L43 18"/><path fill="#9ab9c8" d="M11 13l15-3 27 23-1 15-10-12-15-12Z"/><path stroke="#e0d9b7" d="M11 13l41 35"/><path stroke="#d9e9ef" stroke-width="3" d="M22 46L49 9"/><path fill="#d9e9ef" d="M44 9l10-5-2 12Z"/><path fill="#d3a158" d="M24 36l9 7-7 9-9-7Z"/>',
  "shield":'<path fill="#b9834c" stroke="#dce0cf" stroke-width="4" d="M12 13l20-6 20 6v18Q49 48 32 58 15 48 12 31Z"/><path stroke="#704a34" d="M23 14v31M41 14v31"/><path stroke="#cfd5c5" stroke-width="5" d="M14 29h36M32 10v43"/><circle fill="#e7cf8e" cx="32" cy="29" r="7"/>',
  "leather":'<path fill="#bb8050" stroke="#e3b884" d="M22 8l10 7 10-7 14 14-10 10-4-5 4 29H18l4-29-4 5L8 22Z"/><path fill="#704936" d="M26 12l6 8 6-8-2 36h-8Z"/><path stroke="#e3ba82" stroke-width="3" d="M27 27h10M27 34h10M27 41h10"/><path stroke="#543e31" stroke-width="6" d="M19 48h26"/><rect fill="#ebc271" x="28" y="45" width="9" height="7"/>',
  "plate":'<path fill="#b9d3e3" stroke="#e5f0f6" d="M21 8l11 6 11-6 15 15-11 12-5-6 4 27H18l4-27-5 6L6 23Z"/><path fill="#658aab" d="M32 16l10-5 1 26-11 9-11-9 1-26Z"/><path fill="#9dbfd5" d="M32 16v30l-11-9 1-26Z"/><path stroke="#e4c982" stroke-width="3" d="M22 36l10 7 10-7M19 48h26"/><path fill="#d6e6ef" d="M7 23l12-11 3 12-8 6ZM57 23L45 12l-3 12 8 6Z"/>',
  "relic":'<path fill="#b78ce9" stroke="#e2c5ff" d="M22 9h20l13 20-23 28L9 29Z"/><path fill="#7753ad" d="M9 29h46L32 57Z"/><path fill="#e1b9ff" d="M22 9l-3 20h26L42 9Z"/><path stroke="#f6e9ff" d="M22 9l-3 20 13 28 13-28-3-20M9 29h46"/>'}
 var colors={"sword":"#314c63","dagger":"#284f49","bow":"#59452f","staff":"#285044","crossbow":"#3b4a5c","shield":"#574731","leather":"#584130","plate":"#344e68","relic":"#47375e"}
 var empty=kind.begins_with("empty_")
 var type=kind.trim_prefix("empty_") if empty else kind
 var art=shapes.get(type,'<path stroke="#8d9b9f" stroke-width="3" d="M20 32h24M32 20v24"/>')
 var svg='<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><rect x="1" y="1" width="62" height="62" rx="10" fill="'+(colors.get(type,"#263942") if not empty else "#1c2b34")+'" stroke="#65777c"/><g fill="none" stroke="#27343d" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" opacity="'+("0.28" if empty else "1")+'">'+art+'</g></svg>'
 var image=Image.new()
 image.load_svg_from_string(svg)
 icons[kind]=ImageTexture.create_from_image(image)
 return icons[kind]

static func compact_icon_padding(button: Button):
 for state in ["normal","hover","pressed","disabled"]:
  var box=button.get_theme_stylebox(state).duplicate()
  box.content_margin_top=4;box.content_margin_bottom=4
  button.add_theme_stylebox_override(state,box)

static func item_tooltip(id: String) -> String:
 var item=Jobs.ITEMS[id]
 return item.name+" · "+Jobs.SLOTS[item.slot]+"\n"+Jobs.item_description(id)

static func page(host,parent: Control,unit: Dictionary):
 var editable=host.campaign.phase in ["camp","world"] and host.battle==null and unit.hp>0
 var stats=host.campaign.character_stats(unit.id)
 parent.add_theme_constant_override("separation",6)
 parent.add_child(host.text_label("基础装备 · 低 / 中 / 高三档\n同类型属性一致，仅数值提高；流派效果来自遗物。",14,host.MUTED))
 attributes(host,parent,unit,stats)
 if not stats.adaptation.is_empty():parent.add_child(host.text_label("；".join(stats.adaptation),14,host.GOLD))

 if not editable:parent.add_child(host.text_label("当前只能查看装备",14,host.MUTED))
 var slots=VBoxContainer.new();slots.name="EquipmentSlots";slots.add_theme_constant_override("separation",8);parent.add_child(slots)
 var choices=VBoxContainer.new();choices.name="EquipmentChoices";choices.add_theme_constant_override("separation",8)
 for slot in Jobs.SLOTS:
  var slot_id=slot
  var index=host.campaign.equipped_index(unit.id,slot)
  var item=Jobs.ITEMS[host.campaign.equipment[index].id] if index>=0 else {}
  var entry=host.button(Jobs.SLOTS[slot]+"   ·   "+(item.name if index>=0 else "空置")+"    ›",func():show_choices(host,choices,unit,slot_id,editable))
  entry.expand_icon=false
  entry.name="EquipmentSlot_"+slot;entry.icon=icon(item.kind if index>=0 else {"mainhand":"empty_sword","offhand":"empty_shield","armor":"empty_plate"}[slot])
  entry.custom_minimum_size.y=76;entry.alignment=HORIZONTAL_ALIGNMENT_LEFT
  compact_icon_padding(entry)
  entry.add_theme_constant_override("h_separation",16)
  entry.add_theme_constant_override("icon_max_width",64)
  entry.tooltip_text=item_tooltip(host.campaign.equipment[index].id) if index>=0 else Jobs.SLOTS[slot]+"尚未装备\n点击选择对应类型的装备"
  slots.add_child(entry)
 var relic=host.campaign.personal_relic(unit.id)
 if host.battle!=null:
  var current=host.battle.relic_state.filter(func(r):return r.owner==unit.id)
  relic=current[0] if not current.is_empty() else {}
 var relic_button=host.button("遗物栏   ·   "+(host.Campaign.Relic.definition(relic).name if not relic.is_empty() else "空置"),func():host.show_details("个人遗物栏",host.Campaign.Relic.description(relic)+"\n"+host.relic_instance_status(relic) if not relic.is_empty() else "空遗物栏。获得个人遗物后可绑定；不能卸下或转交，替换失去旧遗物。"))
 relic_button.expand_icon=false;relic_button.icon=icon("empty_relic" if relic.is_empty() else "relic");relic_button.alignment=HORIZONTAL_ALIGNMENT_LEFT;relic_button.custom_minimum_size.y=76
 compact_icon_padding(relic_button)
 relic_button.add_theme_constant_override("h_separation",16)
 relic_button.add_theme_constant_override("icon_max_width",64)
 relic_button.tooltip_text=(host.Campaign.Relic.description(relic)+"\n"+host.relic_instance_status(relic)+"\n" if not relic.is_empty() else "获得个人遗物时可绑定给此角色。\n")+"独立栏位，至多1件；不能卸下或转交，替换会失去旧遗物。"
 slots.add_child(relic_button)
 parent.add_child(choices)
 if not host.campaign.trial_equipment_claimed:
  var claim=host.button("领取职业试用装备（旧档一次）",func():
   if host.campaign.claim_trial_equipment():host.show_party_menu("装备",unit.id))
  preload("res://game/compact_ui.gd").symbolize(claim,"gift")
  claim.disabled=host.campaign.phase!="camp" or host.battle!=null;parent.add_child(claim)

static func show_choices(host,parent: Control,unit: Dictionary,slot: String,editable: bool):
 for child in parent.get_children():parent.remove_child(child);child.queue_free()
 host.detail_section(parent,Jobs.SLOTS[slot]+" · 可选装备")
 var scroll=host.modal.find_child("CharacterPageScroll",true,false)
 if scroll!=null:scroll.ensure_control_visible.call_deferred(parent)
 var count=0
 for i in host.campaign.equipment.size():
  var index=i
  var data=host.campaign.equipment[i]
  var item=Jobs.ITEMS[data.id]
  if item.slot!=slot:continue
  count+=1
  var owner="背包中"
  for member in host.campaign.roster:
   if member.id==data.owner:owner=member.name+"装备中"
  var entry=host.button(item.name+" · "+owner,func():confirm_change(host,unit,slot,index))
  entry.expand_icon=false
  entry.name="EquipmentChoice_"+str(i);entry.icon=icon(item.kind);entry.alignment=HORIZONTAL_ALIGNMENT_LEFT
  entry.add_theme_constant_override("h_separation",16)
  entry.add_theme_constant_override("icon_max_width",64);entry.custom_minimum_size.y=76
  compact_icon_padding(entry)
  entry.tooltip_text=item_tooltip(data.id);entry.disabled=not editable or data.owner==unit.id
  parent.add_child(entry)
 if count==0:parent.add_child(host.text_label("暂无此类装备，可从商店或战利品获得。",15,host.MUTED))
 if host.campaign.equipped_index(unit.id,slot)>=0:
  var remove=host.button("卸下当前"+Jobs.SLOTS[slot],func():confirm_change(host,unit,slot,-1))
  preload("res://game/compact_ui.gd").symbolize(remove,"unequip","卸下当前"+Jobs.SLOTS[slot]+" · 退回背包")
  remove.name="EquipmentRemove_"+slot;remove.disabled=not editable;parent.add_child(remove)

static func show_changes(host,parent: Control,before: Dictionary,after: Dictionary):
 for pair in ATTRIBUTES:
  var delta=int(after[pair[0]])-int(before[pair[0]])
  var label=host.text_label("%s   %d → %d   %s"%[pair[1],before[pair[0]],after[pair[0]],("(+%d)"%delta if delta>0 else "(%d)"%delta) if delta!=0 else "持平"],17,host.TEAL if delta>0 else (host.RED if delta<0 else host.MUTED))
  label.name="StatChange_"+pair[0];parent.add_child(label)
 parent.add_child(host.text_label("职业适应："+("；".join(after.adaptation) if not after.adaptation.is_empty() else "无装备增益或惩罚"),15,host.GOLD))

static func confirm_change(host,unit: Dictionary,slot: String,index: int):
 var old=host.campaign.equipped_index(unit.id,slot)
 var before=host.campaign.character_stats(unit.id)
 var preview=host.campaign.equipment.duplicate(true)
 if old>=0:preview[old].owner=""
 if index>=0:preview[index].owner=unit.id
 var after=host.campaign.stats_for(unit,preview)
 var dialog=ConfirmationDialog.new();dialog.name="EquipmentConfirmation";dialog.title="确认装备变更 · "+unit.name
 dialog.ok_button_text="确认替换" if index>=0 else "确认卸下";dialog.cancel_button_text="取消"
 dialog.min_size=Vector2i(540,460)
 var scroll=ScrollContainer.new();scroll.custom_minimum_size=Vector2(510,390)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;dialog.add_child(scroll)
 var content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 content.add_theme_constant_override("separation",8);scroll.add_child(content)
 content.add_child(host.text_label(Jobs.SLOTS[slot]+"："+(Jobs.ITEMS[host.campaign.equipment[old].id].name if old>=0 else "空置")+" → "+(Jobs.ITEMS[host.campaign.equipment[index].id].name if index>=0 else "空置"),20,host.GOLD))
 if old>=0:content.add_child(host.text_label("原装备将放回队伍背包。",14,host.MUTED))
 show_changes(host,content,before,after)

 if index>=0:
  var owner=host.campaign.equipment[index].owner
  for member in host.campaign.roster:
   if member.id==owner and owner!=unit.id:
    content.add_child(host.text_label("将从 "+member.name+" 转交，对方的"+Jobs.SLOTS[slot]+"将空置：",16,host.GOLD))
    var owner_changes=VBoxContainer.new();owner_changes.name="PreviousOwnerChanges";content.add_child(owner_changes)
    show_changes(host,owner_changes,host.campaign.character_stats(owner),host.campaign.stats_for(member,preview))

 dialog.confirmed.connect(func():
  if host.battle!=null or unit.hp<=0:return
  var success=host.campaign.equip_item(index,unit.id) if index>=0 else host.campaign.unequip_item(unit.id,slot)
  if success:host.refresh_ui();host.show_party_menu("装备",unit.id)
  dialog.queue_free())
 dialog.canceled.connect(dialog.queue_free)
 host.add_child(dialog);dialog.popup_centered()

static func attributes(host,parent: Control,unit: Dictionary,stats: Dictionary):
 var compact=preload("res://game/compact_ui.gd")
 parent.add_child(host.text_label("当前人物属性",18,host.GOLD))
 compact.metrics(host,parent,[["hp","%d/%d"%[unit.hp,unit.max_hp],"生命"],["mp","%d/%d"%[unit.mp,unit.max_mp],"法力"]])
 compact.metrics(host,parent,[["attack",stats.power,"攻击"],["armor",stats.armor,"防护"],["skill",stats.heal_bonus,"治疗加成"]])
 compact.metrics(host,parent,[["speed",stats.speed,"速度"],["range",stats.range,"普攻射程"],["ap",stats.max_ap,"行动点"]])
 var lines=[]
 for pair in ATTRIBUTES:lines.append(pair[1]+"："+str(stats[pair[0]]))
 if stats.get("rest_mp",0)!=0:lines.append("休息回蓝/点：%+d%%"%int(round(stats.rest_mp*100)))
 host.details_button(parent,"完整属性", "\n".join(lines))

static func character_sheet(host,columns: Control,unit: Dictionary):
 var sheet=VBoxContainer.new();sheet.name="CharacterEquipmentSheet";sheet.size_flags_horizontal=Control.SIZE_EXPAND_FILL;sheet.add_theme_constant_override("separation",12);columns.add_child(sheet)
 sheet.add_child(host.text_label(unit.name+"  /  "+unit.role,26,host.GOLD))
 sheet.add_child(host.text_label(unit.identity+" · "+Jobs.JOBS[unit.profession].specialty,15,host.TEAL))
 var scroll=ScrollContainer.new();scroll.name="CharacterPageScroll";scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;sheet.add_child(scroll)
 var content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",12);scroll.add_child(content)
 var body=HBoxContainer.new();body.add_theme_constant_override("separation",18);content.add_child(body)
 var stats=VBoxContainer.new();stats.custom_minimum_size.x=230;stats.add_theme_constant_override("separation",7);body.add_child(stats)
 page(host,stats,unit)
 var slots=stats.get_node("EquipmentSlots");stats.remove_child(slots)
 var choices=stats.get_node("EquipmentChoices");stats.remove_child(choices);content.add_child(choices)
 var stage=HBoxContainer.new();stage.name="EquipmentSlots";stage.size_flags_horizontal=Control.SIZE_EXPAND_FILL;stage.add_theme_constant_override("separation",8);body.add_child(stage)
 var left=VBoxContainer.new();left.custom_minimum_size.x=76;left.add_theme_constant_override("separation",18);stage.add_child(left)
 var preview=preload("res://game/equipment_preview.gd").new();preview.font=host.game_font;preview.custom_minimum_size.y=420;preview.size_flags_horizontal=Control.SIZE_EXPAND_FILL;stage.add_child(preview)
 preview.show_character(unit.id,host.campaign.visual_profile(unit.id),host.equipment_view_states.get(unit.id,{}))
 var id=unit.id;preview.view_changed.connect(func(state):host.equipment_view_states[id]=state)
 var right=VBoxContainer.new();right.custom_minimum_size.x=76;right.add_theme_constant_override("separation",18);stage.add_child(right)
 var index=0
 for entry in slots.get_children():
  slots.remove_child(entry)
  var rail=left if index<2 else right
  rail.add_child(entry)
  var caption=entry.text.split("   ·   ")
  entry.text="";entry.alignment=HORIZONTAL_ALIGNMENT_CENTER;entry.custom_minimum_size=Vector2(76,76)
  rail.add_child(host.text_label(caption[0],14,host.GOLD))
  var item_name=caption[1].replace("    ›","") if caption.size()>1 else ""
  var label=host.text_label(item_name,13,host.MUTED);label.custom_minimum_size.x=76;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;rail.add_child(label)
  index+=1
 slots.free()
 host.modal_body=content
