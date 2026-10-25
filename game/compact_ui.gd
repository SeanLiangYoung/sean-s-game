extends RefCounted
static var icons={}
static func icon(kind: String) -> Texture2D:
 if icons.has(kind):return icons[kind]
 var shapes={
  "rotate_left":'<path d="M8 11a11 11 0 1 1-2 12M8 3v9H1" fill="none" stroke-width="3"/>',
  "rotate_right":'<path d="M24 11A11 11 0 1 0 26 23M24 3v9h7" fill="none" stroke-width="3"/>',
  "zoom_in":'<circle cx="13" cy="13" r="9" fill="none" stroke-width="2"/><path d="m20 20 9 9M13 8v10M8 13h10" fill="none" stroke-width="3"/>',
  "zoom_out":'<circle cx="13" cy="13" r="9" fill="none" stroke-width="2"/><path d="m20 20 9 9M8 13h10" fill="none" stroke-width="3"/>',
  "reset":'<path d="M6 11A12 12 0 1 1 4 22M6 3v9h9M16 9v8l6 3" fill="none" stroke-width="2"/>',
  "unequip":'<circle cx="16" cy="16" r="12" fill="none" stroke-width="2"/><path d="M8 16h16" stroke-width="3"/>',
  "gift":'<path d="M3 12h26v7H3Zm2 7v11h22V19M16 12v18M16 12C0 11 4-2 11 4Zm0 0C32 11 28-2 21 4Z" fill="none" stroke-width="2"/>',
  "menu":'<path d="M4 7h24M4 16h24M4 25h24" fill="none" stroke-width="3"/>',
  "back":'<path d="m21 5-11 11 11 11" fill="none" stroke-width="3"/>',
  "next":'<path d="m11 5 11 11-11 11" fill="none" stroke-width="3"/>',
  "close":'<path d="m7 7 18 18M25 7 7 25" fill="none" stroke-width="3"/>',
  "search":'<circle cx="13" cy="13" r="9" fill="none" stroke-width="3"/><path d="m20 20 9 9" stroke-width="4"/>',
  "clear":'<circle cx="16" cy="16" r="12" fill="none" stroke-width="2"/><path d="m11 11 10 10m0-10-10 10" stroke-width="2"/>',
  "all":'<path d="M3 3h10v10H3ZM19 3h10v10H19ZM3 19h10v10H3ZM19 19h10v10H19Z" fill="none" stroke-width="2"/>',
  "equipment":'<path d="m11 3 5 3 5-3 9 8-6 7-3-3 2 14H9l2-14-3 3-6-7Z" fill="none" stroke-width="2"/>',
  "book":'<path d="M16 7Q9 3 2 6v22q7-3 14 1 7-4 14-1V6q-7-3-14 1Zm0 0v22" fill="none" stroke-width="2"/>',
  "items":'<rect x="6" y="8" width="20" height="22" rx="5" fill="none" stroke-width="2"/><path d="M11 8V3h10v5M6 17h20M12 23h8" fill="none" stroke-width="2"/>',
  "buy":'<path d="M2 3h4l4 19h16l4-14H7M12 27h1m11 0h1" fill="none" stroke-width="3"/><circle cx="13" cy="28" r="2"/><circle cx="24" cy="28" r="2"/>',
  "hire":'<circle cx="12" cy="9" r="5"/><path d="M3 29v-7a9 9 0 0 1 18 0m4-12v12m-6-6h12" fill="none" stroke-width="3"/>',
  "bind":'<path d="m12 19 7-7m-5-5 3-3a7 7 0 0 1 10 10l-5 5a7 7 0 0 1-10 0m6 6-3 3A7 7 0 0 1 5 18l5-5a7 7 0 0 1 10 0" fill="none" stroke-width="3"/>',
  "upgrade":'<path d="M16 29V3m-9 9 9-9 9 9M5 29h22" fill="none" stroke-width="3"/>',
  "learn":'<path d="M16 7Q9 3 2 6v22q7-3 14 1 7-4 14-1V6q-7-3-14 1Zm0 0v22M8 12v9m-4-5h8" fill="none" stroke-width="2"/>',
  "profession":'<path d="m5 28 21-22m-7-3 10 10M4 4l7 1 18 22-3 2L5 11Z" fill="none" stroke-width="3"/>',
  "stats":'<path d="M5 29V17h5v12Zm9 0V10h5v19Zm9 0V3h5v26Z" fill="none" stroke-width="2"/>',
  "blood":'<path d="M16 2C12 9 5 15 5 21a11 11 0 0 0 22 0C27 15 20 9 16 2Z" fill="none" stroke-width="2"/><path d="m10 21 4 4 8-9" fill="none" stroke-width="2"/>',
  "engine":'<path d="m13 2 6 0 1 6 5 2 5 4-3 5-4 0-1 7-6 4-5-4-7-1-2-6 4-4 0-6 6-1Z" fill="none" stroke-width="2"/><circle cx="16" cy="16" r="5" fill="none" stroke-width="2"/>',
  "life":'<path d="M27 3Q2 3 4 20q1 10 13 6Q28 22 27 3ZM4 29l16-17M12 21l-1-7m1 7h8" fill="none" stroke-width="2"/>',
  "moon":'<path d="M24 4A13 13 0 1 0 28 25 13 13 0 0 1 24 4Z" fill="none" stroke-width="2"/>',
  "flag":'<path d="M6 30V3m0 1q5-3 12 0t10 0v14q-4 3-10 0T6 18" fill="none" stroke-width="2"/>',
  "hp":'<path d="M16 27 5 16C-2 5 9-1 16 7 23-1 34 5 27 16Z" transform="translate(0 2)"/>',
  "mp":'<path d="M16 3C12 10 6 15 6 21a10 10 0 0 0 20 0C26 15 20 10 16 3Z"/>',
  "ap":'<path d="m19 2-14 17h10l-2 12 14-18H17Z"/>',
  "range":'<circle cx="16" cy="16" r="10" fill="none" stroke-width="2"/><path d="M16 1v9m0 12v9M1 16h9m12 0h9" fill="none" stroke-width="2"/>',
  "armor":'<path d="m16 3 12 4v9c0 7-8 12-12 14C12 28 4 23 4 16V7Z" fill="none" stroke-width="2"/>',
  "silver":'<circle cx="16" cy="16" r="12" fill="none" stroke-width="3"/><path d="M12 10h8v12h-8Z" fill="none" stroke-width="2"/>',
  "supply":'<rect x="4" y="7" width="24" height="21" rx="4" fill="none" stroke-width="2"/><path d="M12 7V3h8v4M16 11v13m-6-6h12" fill="none" stroke-width="3"/>',
  "move":'<path d="m4 25 7-8 7 1 9-12m-9 0h9v9" fill="none" stroke-width="3"/>',
  "attack":'<path d="m8 25 18-19 2-3-5 1L5 22m-2-5 12 12" fill="none" stroke-width="3"/>',
  "skill":'<path d="m16 2 4 10 11 4-11 4-4 11-4-11L1 16l11-4Z"/>',
  "rest":'<path d="M7 14v10m18-10v10M4 24h24M10 20h12M12 4h11l-10 9h11" fill="none" stroke-width="2"/>',
  "end":'<path d="m6 7 14 9L6 25Zm18 0v18" fill="none" stroke-width="3"/>',
  "relic":'<path d="m16 2 13 12-13 16L3 14Z M3 14h26M10 6l6 24 6-24" fill="none" stroke-width="2"/>',
  "xp":'<path d="m16 2 4 9 10 1-8 7 3 11-9-6-9 6 3-11-8-7 10-1Z" fill="none" stroke-width="2"/>',
  "speed":'<path d="m5 7 10 9L5 25m12-18 10 9-10 9" fill="none" stroke-width="3"/>',
  "person":'<circle cx="16" cy="9" r="5"/><path d="M6 29v-6a10 10 0 0 1 20 0v6Z" fill="none" stroke-width="2"/>',
  "team":'<circle cx="11" cy="9" r="4"/><circle cx="24" cy="11" r="3"/><path d="M3 28v-7a8 8 0 0 1 16 0v7m2-11a6 6 0 0 1 9 5v6" fill="none" stroke-width="2"/>',
  "info":'<circle cx="16" cy="16" r="13" fill="none" stroke-width="2"/><path d="M16 14v10M16 7v3" fill="none" stroke-width="3"/>'}
 var colors={"hp":"#83c9b0","mp":"#96baf0","ap":"#e4bd72"}
 var color=colors.get(kind,"#dfc58d")
 var svg='<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><g fill="'+color+'" stroke="'+color+'" stroke-linejoin="round" stroke-linecap="round">'+shapes.get(kind,shapes.info)+'</g></svg>'
 var img=Image.new();img.load_svg_from_string(svg)
 icons[kind]=ImageTexture.create_from_image(img)
 return icons[kind]

static func metrics(host,parent: Control,values: Array,node_name: String=""):
 var row=HBoxContainer.new();row.name=node_name if node_name!="" else "Metrics"
 row.add_theme_constant_override("separation",12);parent.add_child(row)
 for value in values:
  var chip=HBoxContainer.new();chip.add_theme_constant_override("separation",4)
  chip.tooltip_text=value[2];row.add_child(chip)
  var image=TextureRect.new();image.texture=icon(value[0]);image.custom_minimum_size=Vector2(20,20)
  image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  image.mouse_filter=Control.MOUSE_FILTER_PASS;chip.add_child(image)
  var label=host.text_label(str(value[1]),15);label.autowrap_mode=TextServer.AUTOWRAP_OFF
  label.mouse_filter=Control.MOUSE_FILTER_PASS;chip.add_child(label)
 return row

static func pin_header(host) -> VBoxContainer:
 var header=VBoxContainer.new();header.name="PageSummary";header.add_theme_constant_override("separation",10)
 var frame=host.modal.get_child(0);frame.add_child(header);frame.move_child(header,1)
 for node in host.modal_body.get_children():
  host.modal_body.remove_child(node);header.add_child(node)
 return header

static func grid(parent: Control,columns: int=2) -> GridContainer:
 var result=GridContainer.new();result.columns=columns
 result.add_theme_constant_override("h_separation",12);result.add_theme_constant_override("v_separation",12)
 result.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(result)
 return result

static func card(host,parent: Control,title: String,tint: Color,texture: Texture2D=null) -> VBoxContainer:
 var panel=PanelContainer.new();panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var padding=host.style(Color("203239"),tint.darkened(0.45),8)
 padding.content_margin_left=12;padding.content_margin_right=12;padding.content_margin_top=10;padding.content_margin_bottom=10
 panel.add_theme_stylebox_override("panel",padding);parent.add_child(panel)
 var body=VBoxContainer.new();body.add_theme_constant_override("separation",7);panel.add_child(body)
 var row=HBoxContainer.new();row.add_theme_constant_override("separation",8);body.add_child(row)
 if texture!=null:
  var image=TextureRect.new();image.texture=texture;image.custom_minimum_size=Vector2(32,32)
  image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;row.add_child(image)
 var label=host.text_label(title,19,tint);label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(label)
 return body


static func symbolize(entry: Button,kind: String,label: String="",visible_text: String="") -> Button:
 var meaning=entry.text if label=="" else label
 entry.text=visible_text;entry.icon=icon(kind)
 entry.tooltip_text=meaning;entry.accessibility_name=meaning;entry.accessibility_description=meaning
 entry.custom_minimum_size=Vector2(maxf(48,entry.custom_minimum_size.x),44)
 entry.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
 entry.expand_icon=false;entry.add_theme_constant_override("icon_max_width",32)
 entry.alignment=HORIZONTAL_ALIGNMENT_CENTER
 entry.add_theme_color_override("icon_disabled_color",Color(0.55,0.55,0.55,0.8))
 for state in ["normal","hover","pressed","disabled"]:
  var padding=entry.get_theme_stylebox(state).duplicate()
  padding.content_margin_left=8;padding.content_margin_right=8;padding.content_margin_top=6;padding.content_margin_bottom=6
  entry.add_theme_stylebox_override(state,padding)
 if entry.get_theme_stylebox("normal") is StyleBoxFlat and entry.get_theme_stylebox("normal").bg_color==Color("d5b57a"):
  entry.add_theme_color_override("icon_normal_color",Color("14232c"));entry.add_theme_color_override("icon_hover_color",Color("14232c"));entry.add_theme_color_override("icon_focus_color",Color("14232c"))
 return entry

static func detail_kind(title: String) -> String:
 if "人物" in title:return "person"
 if "属性" in title or "角色基础" in title:return "stats"
 if "共鸣" in title or "遗物" in title:return "relic"
 if "技能" in title or "天赋" in title or "效果" in title:return "book"
 if "幸存" in title:return "team"
 return "info"
