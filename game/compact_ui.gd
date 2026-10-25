extends RefCounted
static var icons={}
static func icon(kind: String) -> Texture2D:
 if icons.has(kind):return icons[kind]
 var shapes={
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
