extends RefCounted
const Jobs=preload("res://game/professions.gd")
const ATTRIBUTES=[["power","攻击"],["range","射程"],["armor","防护"],["speed","速度"],["max_ap","行动点"],["heal_bonus","装备治疗加成"]]
static var icons={}

static func icon(kind: String) -> Texture2D:
 if icons.has(kind):return icons[kind]
 var shapes={
  "sword":'<path d="M22 43L44 9l5 1-1 6-22 30M17 38l15 10M22 44l-8 12"/>',
  "dagger":'<path d="M24 40L43 18l2 10-15 18M19 36l16 14M26 43l-9 11"/>',
  "bow":'<path d="M19 9Q59 32 19 55L25 32Z M13 32h40m-7-6 7 6-7 6"/>',
  "staff":'<path d="M19 56L40 17M32 11l11-6 7 10-11 8Z M28 33l10 5"/>',
  "crossbow":'<path d="M13 16Q35 9 51 39M13 16l38 23M18 51l28-34M17 45l9 8M32 27l10 8"/>',
  "shield":'<path d="M13 12l19-5 19 5v20Q48 47 32 57 16 47 13 32Z M32 10v43M16 29h32"/>',
  "leather":'<path d="M23 9l9 7 9-7 14 12-9 9-4-4 4 29H18l4-29-4 4-9-9Z M26 28h12m-12 9h12m-12 9h12"/>',
  "plate":'<path d="M23 9l9 7 9-7 16 13-10 11-5-5 4 27H18l4-27-5 5L7 22Z M32 19v33M22 34l10 5 10-5M20 46l12 5 12-5"/>',
  "relic":'<path d="M23 9h18l11 20-20 27L12 29Z M23 9l-3 20 12 27 12-27-3-20M12 29h40"/>',
  "empty":'<path d="M17 9H9v8m38-8h8v8M9 47v8h8m30 0h8v-8M23 32h18m-9-9v18"/>'}
 var svg='<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><g fill="none" stroke="#d9bd80" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">'+shapes.get(kind,shapes.empty)+'</g></svg>'
 var image=Image.new()
 image.load_svg_from_string(svg)
 icons[kind]=ImageTexture.create_from_image(image)
 return icons[kind]

static func item_tooltip(id: String) -> String:
 var item=Jobs.ITEMS[id]
 return item.name+" · "+Jobs.SLOTS[item.slot]+"\n"+Jobs.item_description(id)

static func page(host,parent: Control,unit: Dictionary):
 var editable=host.campaign.phase in ["camp","world"] and host.battle==null and unit.hp>0
 var stats=host.campaign.character_stats(unit.id)
 host.detail_section(parent,"当前人物属性")
 parent.add_child(host.text_label("生命 %d/%d   法力 %d/%d"%[unit.hp,unit.max_hp,unit.mp,unit.max_mp],16))
 parent.add_child(host.text_label("攻击 %d   防护 %d   速度 %d\n射程 %d   行动点 %d   装备治疗 +%d"%[stats.power,stats.armor,stats.speed,stats.range,stats.max_ap,stats.heal_bonus],17,host.TEAL))
 if not stats.adaptation.is_empty():parent.add_child(host.text_label("；".join(stats.adaptation),14,host.GOLD))
 if unit.profession=="hero":parent.add_child(host.text_label("主角光环："+Jobs.aura_for(stats),14,host.TEAL))
 parent.add_child(host.text_label("点击栏位选择同类装备 · 悬浮图标查看效果" if editable else "当前只能查看装备 · 悬浮图标查看效果",14,host.MUTED))
 var slots=VBoxContainer.new();slots.name="EquipmentSlots";slots.add_theme_constant_override("separation",8);parent.add_child(slots)
 var choices=VBoxContainer.new();choices.name="EquipmentChoices";choices.add_theme_constant_override("separation",8)
 for slot in Jobs.SLOTS:
  var slot_id=slot
  var index=host.campaign.equipped_index(unit.id,slot)
  var item=Jobs.ITEMS[host.campaign.equipment[index].id] if index>=0 else {}
  var entry=host.button(Jobs.SLOTS[slot]+"   ·   "+(item.name if index>=0 else "空置")+"    ›",func():show_choices(host,choices,unit,slot_id,editable))
  entry.expand_icon=true
  entry.name="EquipmentSlot_"+slot;entry.icon=icon(item.kind if index>=0 else "empty")
  entry.custom_minimum_size.y=56;entry.alignment=HORIZONTAL_ALIGNMENT_LEFT
  entry.add_theme_constant_override("icon_max_width",36)
  entry.tooltip_text=item_tooltip(host.campaign.equipment[index].id) if index>=0 else Jobs.SLOTS[slot]+"尚未装备\n点击选择对应类型的装备"
  slots.add_child(entry)
 var relic=host.campaign.personal_relic(unit.id)
 if host.battle!=null:
  var current=host.battle.relic_state.filter(func(r):return r.owner==unit.id)
  relic=current[0] if not current.is_empty() else {}
 var relic_button=host.button("遗物   ·   "+(host.Campaign.Relic.definition(relic).name if not relic.is_empty() else "空置"),func():pass)
 relic_button.expand_icon=true;relic_button.icon=icon("relic");relic_button.alignment=HORIZONTAL_ALIGNMENT_LEFT;relic_button.custom_minimum_size.y=56
 relic_button.add_theme_constant_override("icon_max_width",36)
 relic_button.tooltip_text=(host.Campaign.Relic.description(relic)+"\n"+host.relic_instance_status(relic)+"\n" if not relic.is_empty() else "获得个人遗物时可绑定给此角色。\n")+"独立栏位，至多1件；不能卸下或转交，替换会失去旧遗物。"
 slots.add_child(relic_button)
 parent.add_child(choices)
 if not host.campaign.trial_equipment_claimed:
  var claim=host.button("领取职业试用装备（旧档一次）",func():
   if host.campaign.claim_trial_equipment():host.show_party_menu("装备",unit.id))
  claim.disabled=host.campaign.phase!="camp" or host.battle!=null;parent.add_child(claim)

static func show_choices(host,parent: Control,unit: Dictionary,slot: String,editable: bool):
 for child in parent.get_children():parent.remove_child(child);child.queue_free()
 host.detail_section(parent,Jobs.SLOTS[slot]+" · 可选装备")
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
  entry.expand_icon=true
  entry.name="EquipmentChoice_"+str(i);entry.icon=icon(item.kind);entry.alignment=HORIZONTAL_ALIGNMENT_LEFT
  entry.add_theme_constant_override("icon_max_width",40);entry.custom_minimum_size.y=54
  entry.tooltip_text=item_tooltip(data.id);entry.disabled=not editable or data.owner==unit.id
  parent.add_child(entry)
 if count==0:parent.add_child(host.text_label("暂无此类装备，可从商店或战利品获得。",15,host.MUTED))
 if host.campaign.equipped_index(unit.id,slot)>=0:
  var remove=host.button("卸下当前"+Jobs.SLOTS[slot],func():confirm_change(host,unit,slot,-1))
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
 var after=Jobs.stats(unit,preview)
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
 if unit.profession=="hero":content.add_child(host.text_label("光环："+Jobs.aura_for(before)+" → "+Jobs.aura_for(after),15,host.TEAL))
 if index>=0:
  var owner=host.campaign.equipment[index].owner
  for member in host.campaign.roster:
   if member.id==owner and owner!=unit.id:
    content.add_child(host.text_label("将从 "+member.name+" 转交，对方的"+Jobs.SLOTS[slot]+"将空置：",16,host.GOLD))
    var owner_changes=VBoxContainer.new();owner_changes.name="PreviousOwnerChanges";content.add_child(owner_changes)
    show_changes(host,owner_changes,host.campaign.character_stats(owner),Jobs.stats(member,preview))
    if member.profession=="hero":content.add_child(host.text_label("主角光环："+Jobs.aura_for(Jobs.stats(member,preview)),15,host.TEAL))
 dialog.confirmed.connect(func():
  if host.battle!=null or unit.hp<=0:return
  var success=host.campaign.equip_item(index,unit.id) if index>=0 else host.campaign.unequip_item(unit.id,slot)
  if success:host.refresh_ui();host.show_party_menu("装备",unit.id)
  dialog.queue_free())
 dialog.canceled.connect(dialog.queue_free)
 host.add_child(dialog);dialog.popup_centered()
