extends Node3D
const Jobs=preload("res://game/professions.gd")
const PartyDetails=preload("res://game/party_details.gd")
const Campaign = preload("res://game/campaign.gd")
const Rules = preload("res://game/rules.gd")
const Art = preload("res://game/art.gd")
var art=Art.new()
var portraits=preload("res://game/portraits.gd").new()
var presentation=preload("res://game/combat_presentation.gd").new()
const INK = Color("111c24")
const GOLD = Color("d5b57a")
const CREAM = Color("e4e5dc")
const MUTED = Color("93a5aa")
const TEAL = Color("78c9ba")
const RED = Color("df796b")
var atlas: Control
var selecting_expedition=false
var campaign = Campaign.new()
var battle
var scene_root: Node3D
var ui: Control
var party_menu_open = false
var menu_tab = "角色"
var menu_character = "hero"
var equipment_view_states: Dictionary = {}
var sidebar: VBoxContainer
var footer: VBoxContainer
var top_label: Label
var status_label: Label
var modal: PanelContainer
var page_back: Button
var page_back_action: Callable
var modal_body: VBoxContainer
var camera: Camera3D
var world_party: Node3D
var world_target = Vector3.ZERO
var pending_location = -1
var arrived_location = -1
var selected_ids: Array = []
var extraction_ids: Array = []
var battle_mode = ""
var selected_skill = ""
var ai_clock = 0.0
var resolved = false
var elapsed = 0.0
var pawn_nodes: Array = []
var capture_mode = ""
var capture_clock = 0.0
var capture_done = false
var game_font: Font
var camera_angle = 0.0
var camera_zoom = 23.0
var menu_screen = ""
var session_started = false
var settings_path = "user://ashbound-settings.cfg"
var location_positions = [Vector3(-6,0,1),Vector3(5,0,-4),Vector3(-3,0,-8),Vector3(2,0,-12),Vector3(6,0,4)]
var location_names = ["断桥哨站","遗械坟场","灰巢营地","北岸渡口","废弃驿站"]
var location_desc = ["3 名敌人 · 首次交锋","4 名敌人 · 深入边境","5 名敌人 · 高风险","指定撤离点 · 结算宝物","一次性补给 · 搜索遗物"]

func _ready():
 add_child(portraits)
 add_child(presentation)
 presentation.completed.connect(after_battle_action)
 var fallback=SystemFont.new()
 fallback.font_names=PackedStringArray(["PingFang SC","Noto Sans CJK SC","Microsoft YaHei"])
 game_font=fallback
 var local_font="/System/Library/Fonts/STHeiti Medium.ttc"
 if FileAccess.file_exists(local_font):
  var chinese=FontFile.new()
  chinese.data=FileAccess.get_file_as_bytes(local_font)
  chinese.fallbacks=[fallback]
  game_font=chinese
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--capture-"):capture_mode=arg
 var environment = WorldEnvironment.new()
 var env = Environment.new()
 env.background_mode = Environment.BG_COLOR
 env.background_color = Color("b6c7bc")
 env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color = Color("b9c9c2")
 env.ambient_light_energy = 0.40
 env.fog_enabled=true
 env.fog_light_color=Color("b5c5b9")
 env.fog_density=0.0015
 env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
 environment.environment = env
 add_child(environment)
 var sun = DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-52,-35,0)
 sun.light_color = Color("ffe9bc")
 sun.light_energy = 0.65
 sun.shadow_enabled = true
 add_child(sun)
 camera = Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.far = 200
 add_child(camera)
 scene_root = Node3D.new()
 add_child(scene_root)
 make_ui()
 load_settings()
 if capture_mode != "":
  campaign.save_path="user://ashbound-capture.json"
  if capture_mode!="--capture-menu":campaign.depart()
  if capture_mode in ["--capture-battle","--capture-actions"]:
   battle = campaign.make_battle(["hero","blade","ranger","medic","engineer"],0)
   battle.actors[1].hp = 36
  if capture_mode in ["--capture-shrink","--capture-tide"]:
   battle = campaign.make_battle(["hero","blade","ranger","medic","engineer"],0)
   battle.round_no=3
   if capture_mode=="--capture-tide":
    battle.shrink()
    battle.round_no=4
 if campaign.phase == "battle" and battle==null:campaign.phase="world"
 if battle != null:
  camera_zoom=16.5
  draw_battle()
 else:draw_world()
 refresh_ui()
 if capture_mode=="--capture-atlas":
  campaign.phase="camp"
  refresh_ui()
 if capture_mode=="--capture-route":
  campaign.phase="camp"
  campaign.start_region("border")
  refresh_ui()
 if capture_mode in ["","--capture-menu"]:show_main_menu()
 else:session_started=true
 get_tree().auto_accept_quit=false
 if "--smoke" in OS.get_cmdline_user_args():
  print("SCENE_SMOKE_OK")
  get_tree().create_timer(1.0).timeout.connect(func():get_tree().quit())

func material(color: Color, emission: bool = false) -> Material:
 if not emission:return art.paint(color)
 var m=StandardMaterial3D.new()
 m.albedo_color=color
 m.emission_enabled=true
 m.emission=color
 m.emission_energy_multiplier=0.35
 return m

func mesh_node(mesh: Mesh, pos: Vector3, color: Color, parent: Node3D = null) -> MeshInstance3D:
 var node = MeshInstance3D.new()
 node.mesh = mesh
 node.material_override = material(color)
 node.position = pos
 (scene_root if parent==null else parent).add_child(node)
 return node

func box(pos: Vector3,size: Vector3,color: Color,parent: Node3D = null):
 var mesh = BoxMesh.new()
 mesh.size = size
 return mesh_node(mesh,pos,color,parent)

func cylinder(pos: Vector3,bottom: float,top: float,height: float,color: Color,sides: int = 8,parent: Node3D = null):
 var mesh = CylinderMesh.new()
 mesh.bottom_radius = bottom
 mesh.top_radius = top
 mesh.height = height
 mesh.radial_segments = sides
 return mesh_node(mesh,pos,color,parent)

func sphere(pos: Vector3,size: float,color: Color,parent: Node3D):
 var mesh = SphereMesh.new()
 mesh.radius = size
 mesh.height = size*2
 mesh.radial_segments = 8
 mesh.rings = 4
 return mesh_node(mesh,pos,color,parent)

func label3(text: String,pos: Vector3,color: Color,size: int = 26,parent: Node3D = null):
 var l = Label3D.new()
 l.text = text
 l.font_size = size
 l.font=game_font
 l.pixel_size=0.012
 l.modulate = color
 l.outline_size = 5
 l.outline_modulate = Color("13212a")
 l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 l.no_depth_test = true
 l.position = pos
 (scene_root if parent==null else parent).add_child(l)
 return l

func clear_scene():
 for child in scene_root.get_children():
  scene_root.remove_child(child)
  child.queue_free()
 pawn_nodes = []
 world_party = null

func make_pawn(pos: Vector3,color: Color,kind: String,active: bool = false) -> Node3D:
 var root=art.character(scene_root,pos,color,kind,active,campaign.visual_profile(kind))
 pawn_nodes.append(root)
 return root

func tree_at(pos: Vector3,scale_factor: float):
 return art.tree(scene_root,pos,scale_factor)

func draw_world():
 clear_scene()
 camera_zoom = 28
 camera_angle = 0
 box(Vector3(0,-0.65,-3),Vector3(160,1,160),Color("364c43"))
 box(Vector3(0,-1.25,-3),Vector3(160,0.5,160),Color("263a36"))
 art.grass(scene_root,4481,1400,Vector2(14,15))
 art.grass(scene_root,4482,6500,Vector2(79,76))
 # Meandering roads and a cold river provide readable landmarks.
 for z in range(-13,10):
  var x = sin(z*0.24)*1.7
  box(Vector3(x,-0.12,z),Vector3(2.2,0.05,1.15),Color("8a8167"))
 for x in range(-80,81):
  var z = -10.5+sin(x*0.28)*1.2
  box(Vector3(x,-0.02,z),Vector3(1.1,0.06,2),Color("4e8590"))
 for z in range(-12,-8):box(Vector3(2,0.07,z),Vector3(2.3,0.12,0.6),Color("8b7152"))
 var rng = RandomNumberGenerator.new()
 rng.seed = 4481
 for i in range(445):
  var pos = Vector3(rng.randf_range(-13.5,13.5),0,rng.randf_range(-18,12)) if i<85 else Vector3(rng.randf_range(-60,60),0,rng.randf_range(-60,54))
  if i>=85 and absf(pos.x)<14 and pos.z>-19 and pos.z<13:continue
  if absf(pos.x)<3 or location_positions.any(func(p):return p.distance_to(pos)<2.5):continue
  if i%4 == 0:
   var rock = cylinder(pos+Vector3(0,0.22,0),rng.randf_range(0.3,0.8),0.15,rng.randf_range(0.5,1.1),Color("77807a"),5)
   rock.rotation_degrees.z=rng.randf_range(-15,15)
  else:tree_at(pos,rng.randf_range(0.65,1.1))
 # Southern camp: cloth tents, supply crates and a warm fire.
 for x in [-2.0,2.0]:
  cylinder(Vector3(x,0.65,7),1.15,0,1.5,Color("b29a72"),4)
  box(Vector3(x+0.7,0.25,8.2),Vector3(0.6,0.5,0.6),Color("755f45"))
 cylinder(Vector3(0,0.13,7),0.6,0.6,0.16,Color("504a3c"),8)
 cylinder(Vector3(0,0.5,7),0.28,0,0.8,Color("e9a355"),6)
 label3("南境营地",Vector3(0,2.1,7.6),GOLD,32)
 label3("灰  潮  边  境",Vector3(-7,0.12,-15),Color("b3c1b0"),50)
 for i in range(5):
  var p = location_positions[i]
  var col = RED if i<3 else TEAL
  if i<3 and campaign.encounters[i] != "open":col=MUTED.darkened(0.3)
  cylinder(p+Vector3(0,0.04,0),1.2,1.2,0.1,col.darkened(0.35),32)
  if i==0:
   for x in [-0.65,0.65]:box(p+Vector3(x,0.75,0),Vector3(0.5,1.5,0.5),Color("a69e85"))
   box(p+Vector3(0,1.5,0),Vector3(2,0.3,0.5),Color("8e8c77"))
  elif i==1:
   for j in range(3):
    var ruin=box(p+Vector3(j*0.5-0.5,0.4,-0.2*j),Vector3(0.4,0.8+j*0.35,0.6),Color("788485"))
    ruin.rotation_degrees.z=15*j
  elif i==2:
   cylinder(p+Vector3(0,0.7,0),1,0,1.6,Color("975c4b"),4)
   box(p+Vector3(1,0.9,0),Vector3(0.06,1.8,0.06),Color("71624d"))
   box(p+Vector3(1.3,1.5,0),Vector3(0.6,0.35,0.08),RED)
  elif i==3:
   for x in [-0.7,0.7]:box(p+Vector3(x,1,0),Vector3(0.15,2,0.15),Color("9d9177"))
   box(p+Vector3(0,2,0),Vector3(1.7,0.2,0.2),TEAL)
  else:
   box(p+Vector3(0,0.45,0),Vector3(1.3,0.9,1),Color("9a927c"))
   cylinder(p+Vector3(0,1.15,0),1,0,0.7,Color("626c66"),4)
  var suffix = ""
  if i<3 and campaign.encounters[i]=="cleared":suffix=" · 已清剿"
  if i<3 and campaign.encounters[i]=="failed":suffix=" · 已失守"
  if i==4 and campaign.event_used:suffix=" · 已搜索"
  label3(location_names[i]+suffix,p+Vector3(0,2.5,0),col,28)
 world_party = make_pawn(Vector3(campaign.world_position[0],0,campaign.world_position[1]),GOLD,"hero",true)
 world_target = world_party.position
 update_camera()

func cell_position(cell: Vector2i) -> Vector3:
 return Vector3(sqrt(3.0)*(cell.x+cell.y*0.5)*0.78,0,1.5*cell.y*0.78)

func draw_battle():
 clear_scene()
 art.landscape(scene_root,battle.radius)
 art.tide(scene_root,battle.radius,battle.round_no>=2)
 var a = battle.active()
 for cell in battle.cells():
  var p = cell_position(cell)
  var col = Color("859358") if (cell.x-cell.y)%2==0 else Color("7d8c54")
  var distance = battle.hex_distance(cell,Vector2i.ZERO)
  var warning = battle.round_no in [2,3,4,5,6,7,8,9] and distance==battle.radius
  if warning:col=Color("a59663")
  if cell in battle.obstacles:col=Color("8b8b68")
  if not a.is_empty() and a.side==0 and battle.outcome=="" and battle_mode=="move":
   var path = battle.path_to(a.cell,cell)
   if not path.is_empty() and path.size()<=a.ap:col=Color("7b9b78")
  if not a.is_empty() and a.side==0 and battle_mode in ["attack","skill","item"]:
   var target=battle.unit_at(cell)
   if target_allowed(target):col=TEAL if target.side==0 else RED
   if target_cell_allowed(cell):col=TEAL
  if not a.is_empty() and a.cell==cell:col=Color("abac6e")
  cylinder(p+Vector3(0,-0.075,0),0.765,0.765,0.025,col,6)
  art.ring(scene_root,p+Vector3(0,-0.057,0),0.765,Color("62765b"),0.012)
  if warning:
   art.ring(scene_root,p+Vector3(0,-0.045,0),0.755,Color("d6a268"),0.045)
  if cell in battle.obstacles:
   art.rock(scene_root,p+Vector3(0,0.22,0),Vector3(0.85,0.65,0.75),Color("b1ae92"))
   art.rock(scene_root,p+Vector3(0.27,0.02,0.15),Vector3(0.35,0.28,0.4),Color("a2a58b"))
 for trap in battle.traps:
  var p=cell_position(trap.cell)
  art.ring(scene_root,p+Vector3(0,0.04,0),0.42,GOLD,0.06)
  label3("机关",p+Vector3(0,0.26,0),GOLD,18)
 for u in battle.actors:
  if u.hp<=0:continue
  var col = Color("b46555") if u.side==1 else Color("6eaaa5")
  if u.id=="hero":col=Color("c4a56b")
  if u.id=="medic":col=Color("9db68b")
  var root = make_pawn(cell_position(u.cell),col,u.id,not a.is_empty() and a.id==u.id)
  label3(u.name,Vector3(0,1.93,0),CREAM,23,root)
  var state=battle.status_text(u)
  if state!="":label3(state,Vector3(0,2.42,0),GOLD,15,root)
  box(Vector3(0,1.66,0),Vector3(0.85,0.06,0.05),Color("283536"),root)
  var width=0.85*float(u.hp)/u.max_hp
  var fill=box(Vector3((width-0.85)/2,1.67,0.015),Vector3(0.85,0.065,0.06),RED if u.side==1 else TEAL,root)
  fill.name="HealthFill"
  fill.scale.x=maxf(0.01,width/0.85)
  if not a.is_empty() and a.side==0 and u.side==1 and battle.hex_distance(a.cell,u.cell)<=a.range:
   label3("◆",Vector3(0,2.25,0),RED,22,root)
 update_camera()

func update_camera():
 var center=Vector3(1.0,0,-2.5) if battle==null else Vector3(-1.0,0,0)
 var dist=24.0
 camera.position=center+Vector3(sin(camera_angle)*dist,27,cos(camera_angle)*dist)
 camera.size=camera_zoom
 camera.look_at(center)

func style(bg: Color,border: Color=Color.TRANSPARENT,radius: int=10) -> StyleBoxFlat:
 var s=StyleBoxFlat.new()
 s.bg_color=bg
 s.border_color=border
 s.set_border_width_all(1 if border.a>0 else 0)
 s.set_corner_radius_all(radius)
 s.content_margin_left=18
 s.content_margin_right=18
 s.content_margin_top=14
 s.content_margin_bottom=14
 return s

func text_label(text: String,size: int=18,color: Color=CREAM) -> Label:
 var l=Label.new()
 l.text=text
 l.add_theme_font_size_override("font_size",size)
 l.add_theme_color_override("font_color",color)
 l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 return l

func button(text: String,action: Callable,accent: bool=false) -> Button:
 var b=Button.new()
 b.text=text
 b.custom_minimum_size=Vector2(0,44)
 b.add_theme_font_size_override("font_size",17)
 b.add_theme_color_override("font_color",INK if accent else CREAM)
 b.add_theme_stylebox_override("normal",style(GOLD if accent else Color("263942"),Color("4b6267"),6))
 b.add_theme_stylebox_override("hover",style(GOLD.lightened(0.15) if accent else Color("3a535a"),GOLD,6))
 b.add_theme_stylebox_override("pressed",style(Color("64877f"),TEAL,6))
 b.add_theme_stylebox_override("disabled",style(Color("1d2b32"),Color("35444a"),6))
 b.add_theme_color_override("font_disabled_color",Color("687b80"))
 b.pressed.connect(action)
 return b

func panel(parent: Control,pos: Vector2,size: Vector2) -> PanelContainer:
 var p=PanelContainer.new()
 p.position=pos
 p.size=size
 p.add_theme_stylebox_override("panel",style(Color(0.06,0.10,0.13,0.96),Color("3a4d51")))
 parent.add_child(p)
 return p

func make_ui():
 var layer=CanvasLayer.new()
 add_child(layer)
 ui=Control.new()
 ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
 layer.add_child(ui)
 var theme=Theme.new()
 theme.default_font=game_font
 ui.theme=theme
 var header=panel(ui,Vector2(22,18),Vector2(1396,72))
 var row=HBoxContainer.new()
 row.add_theme_constant_override("separation",24)
 header.add_child(row)
 var title=text_label("灰烬行旅",29,GOLD)
 title.custom_minimum_size.x=165
 title.autowrap_mode=TextServer.AUTOWRAP_OFF
 row.add_child(title)
 var subtitle=text_label("A S H B O U N D  /  玩法原型",14,MUTED)
 subtitle.autowrap_mode=TextServer.AUTOWRAP_OFF
 row.add_child(subtitle)
 top_label=text_label("",18)
 top_label.autowrap_mode=TextServer.AUTOWRAP_OFF
 top_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 top_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
 row.add_child(top_label)
 row.add_child(button("菜单 · Esc",show_pause_menu))
 var side=panel(ui,Vector2(22,106),Vector2(288,620))
 var scroll=ScrollContainer.new()
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 side.add_child(scroll)
 sidebar=VBoxContainer.new()
 sidebar.add_theme_constant_override("separation",10)
 sidebar.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 scroll.add_child(sidebar)
 var bottom=panel(ui,Vector2(330,742),Vector2(1088,138))
 footer=VBoxContainer.new()
 footer.add_theme_constant_override("separation",9)
 bottom.add_child(footer)
 var small=panel(ui,Vector2(22,742),Vector2(288,138))
 var info=VBoxContainer.new()
 small.add_child(info)
 info.add_child(text_label("边境生存手册",17,GOLD))
 info.add_child(text_label("选择地点推进 · 战斗先选行动\nEsc 打开菜单 / 取消选择",14,MUTED))
 status_label=text_label("",17)
 status_label.add_theme_stylebox_override("normal",style(Color(0.06,0.10,0.13,0.85),Color.TRANSPARENT,7))
 status_label.position=Vector2(340,114)
 status_label.size=Vector2(1040,65)
 status_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 ui.add_child(status_label)

func empty_children(node: Node):
 for child in node.get_children():
  node.remove_child(child)
  child.queue_free()

func separator(parent: Control):
 var h=HSeparator.new()
 h.modulate=Color("4b6267")
 parent.add_child(h)

func refresh_ui():
 if battle==null and is_instance_valid(world_party):
  preload("res://game/character_visual.gd").apply_loadout(world_party,campaign.visual_profile("hero"))
 refresh_atlas()
 empty_children(sidebar)
 empty_children(footer)
 var navigation=HBoxContainer.new()
 navigation.add_theme_constant_override("separation",4)
 sidebar.add_child(navigation)
 for tab in ["角色","装备","物品","遗物"]:
  var section=tab
  var entry=button(tab,func():show_party_menu(section))
  entry.add_theme_font_size_override("font_size",14)
  var compact=style(Color("263942"),Color("4b6267"),5)
  compact.content_margin_left=8
  compact.content_margin_right=8
  entry.add_theme_stylebox_override("normal",compact)
  entry.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  navigation.add_child(entry)
 separator(sidebar)
 top_label.text="第 %d 次远征    ·    银币 %d    ·    补给 %d"%[campaign.expedition,campaign.silver,campaign.supplies]
 if battle==null:
  sidebar.add_child(text_label("佣兵团 · %d / 10"%campaign.roster.filter(func(u):return u.hp>0).size(),23,GOLD))
  sidebar.add_child(text_label("最多 5 人出战，其余留守。\n阵亡永久失去；团长死亡则游戏结束。",14,MUTED))
  for u in campaign.roster:
   var character_id=u.id
   sidebar.add_child(character_card(u,func():show_party_menu("角色",character_id)))
  separator(sidebar)
  sidebar.add_child(text_label("远征宝物  %d    永久收藏  %d"%[campaign.relics.size(),campaign.collection.size()],15,GOLD))
  for id in campaign.relics:
   for reward in Campaign.REWARDS:
    if reward.id==id:sidebar.add_child(text_label("◆ "+reward.name,14,TEAL))
  if campaign.phase=="camp":
   status_label.text="南境营地  /  幸存者休整完毕，准备下一次远征。"
   footer.add_child(text_label("走进边境，带着战利品活着回来。",22,GOLD))
   var row=HBoxContainer.new()
   footer.add_child(row)
   row.add_child(button("开始远征  →",depart,true))
   if not campaign.snapshot.is_empty():row.add_child(button("读取远征前存档",show_restore))
  else:
   status_label.text=campaign.notice
   footer.add_child(text_label("远征路线  /  点击地标前往，抵达后交互",18,GOLD))
   var row=HBoxContainer.new()
   row.add_theme_constant_override("separation",8)
   footer.add_child(row)
   for i in range(5):
    var index=i
    var b=button(location_names[i],func():travel_to(index))
    b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    if i<3 and campaign.encounters[i]!="open":b.disabled=true
    row.add_child(b)
   var supply=button("使用补给",func():
    if campaign.use_supply():refresh_ui())
   supply.disabled=campaign.supplies<=0
   sidebar.add_child(supply)
   sidebar.add_child(button("读取远征前存档",show_restore))
 else:
  top_label.text="第 %d / %d 回合    ·    安全半径 %d    ·    速度顺序行动"%[battle.round_no,battle.round_limit,battle.radius]
  var a=battle.active()
  sidebar.add_child(text_label("独立战场",24,GOLD))
  sidebar.add_child(text_label(location_names[campaign.current_encounter] if campaign.current_encounter>=0 else "边境遭遇",16,MUTED))
  var command_slot=VBoxContainer.new()
  command_slot.name="ActionCommands"
  command_slot.add_theme_constant_override("separation",7)
  sidebar.add_child(command_slot)
  sidebar.add_child(text_label("行动顺序",16,GOLD))
  for j in range(battle.order.size()):
   var u=battle.actors[battle.order[j]]
   if u.hp<=0:continue
   var prefix="▶ " if j==battle.order_index else "    "
   sidebar.add_child(text_label(prefix+u.name+"  ·  "+str(u.hp)+" HP",16,RED if u.side==1 else (GOLD if j==battle.order_index else CREAM)))
  separator(sidebar)
  sidebar.add_child(text_label("灰潮将至",18,GOLD))
  sidebar.add_child(text_label("橙色边缘将在下次收缩时失效。\n未撤离者强制位移，损失 20% 最大生命；无处可退则死亡。",14,MUTED))
  sidebar.add_child(text_label("第 3 / 5 / 7 / 9 回合结束收缩\n第 10 回合结束未获胜：全员死亡",14,RED))
  separator(sidebar)
  var logs=battle.events.slice(maxi(0,battle.events.size()-4))
  for log in logs:sidebar.add_child(text_label(log,13,MUTED))
  var is_player=not a.is_empty() and a.side==0 and battle.outcome==""
  if not a.is_empty():
   status_label.text="%s  /  %s    生命 %d/%d    法力 %d/%d    行动点 %d/%d"%[a.name,a.role,a.hp,a.max_hp,a.mp,a.max_mp,a.ap,a.get("max_ap",4)]
  render_action_menu(is_player)
  sidebar.add_child(button("放弃战斗…",show_surrender))

func character_card(unit: Dictionary,action: Callable,selected: bool=false,status: String="") -> Button:
 var state="已阵亡" if unit.hp<=0 else status
 var title="%s\n%s"%[unit.name,unit.role]
 if state!="":title+="  /  "+state
 var card=button(title+"\n生命 %d/%d   法力 %d/%d"%[unit.hp,unit.max_hp,unit.mp,unit.max_mp],action,selected)
 card.name="CharacterCard_"+unit.id
 card.icon=portraits.portrait(unit.id,campaign.visual_profile(unit.id))
 card.expand_icon=true
 card.clip_text=true
 card.add_theme_constant_override("icon_max_width",64)
 card.add_theme_constant_override("h_separation",12)
 card.add_theme_font_size_override("font_size",14)
 card.alignment=HORIZONTAL_ALIGNMENT_LEFT
 card.custom_minimum_size=Vector2(220,88)
 card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 card.tooltip_text="%s · %s\n%s"%[unit.name,unit.role,"已阵亡 · 无法出战" if unit.hp<=0 else "点击查看或选择角色"]
 if unit.hp<=0:card.modulate=Color("8d9399")
 return card

func close_modal():
 party_menu_open=false
 if is_instance_valid(modal):
  var shade=modal.get_parent()
  ui.remove_child(shade)
  shade.queue_free()
 modal=null
 page_back=null
 page_back_action=Callable()
 menu_screen=""

func open_modal(title: String,subtitle: String):
 close_modal()
 var shade=ColorRect.new()
 shade.color=Color("111c24")
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 ui.add_child(shade)
 modal=panel(shade,Vector2.ZERO,Vector2.ZERO)
 modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 modal.add_theme_stylebox_override("panel",style(INK,Color.TRANSPARENT,0))
 var page_frame=VBoxContainer.new()
 modal.add_child(page_frame)
 var scroll=ScrollContainer.new()
 scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 page_frame.add_child(scroll)
 modal_body=VBoxContainer.new()
 modal_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 modal_body.add_theme_constant_override("separation",14)
 scroll.add_child(modal_body)
 page_back_action=close_modal
 page_back=button("‹ 返回",navigate_back)
 page_back.name="PageBack"
 page_back.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
 page_frame.add_child(page_back)
 page_frame.move_child(page_back,0)
 modal_body.add_child(text_label(title,29,GOLD))
 modal_body.add_child(text_label(subtitle,17,MUTED))
 separator(modal_body)

func navigate_back():
 if is_instance_valid(page_back) and not page_back.disabled and page_back_action.is_valid():
  page_back_action.call()

func set_page_back(action: Callable):
 page_back_action=action
 page_back.disabled=not action.is_valid()

func depart():
 if campaign.phase=="camp":
  selecting_expedition=true
  refresh_atlas()
  return
 if campaign.depart():
  session_started=true
  set_game_hud_visible(true)
  close_modal()
  pending_location=-1
  arrived_location=-1
  draw_world()
  refresh_ui()

func travel_to(index: int):
 if campaign.phase!="world" or battle!=null or is_instance_valid(modal):return
 if index<3 and campaign.encounters[index]!="open":return
 if index==4 and campaign.event_used:
  campaign.notice="驿站已经搜索过了。"
  refresh_ui()
  return
 pending_location=index
 arrived_location=-1
 world_target=location_positions[index]+Vector3(0,0,1.4)
 campaign.notice="正在前往 "+location_names[index]+"…"
 refresh_ui()

func arrive(index: int):
 arrived_location=index
 if index<3:show_deploy(index)
 elif index==3:show_extract()
 else:
  campaign.visit_event()
  draw_world()
  refresh_ui()

func show_deploy(index: int):
 selected_ids=[]
 for u in campaign.roster:
  if u.hp>0 and selected_ids.size()<5:selected_ids.append(u.id)
 render_deploy(index)

func render_deploy(index: int):
 open_modal("部署队伍  /  %s"%location_names[index],"选择 1—5 人。留守队员不会因本场战败死亡；团长可以留守。")
 modal_body.add_child(text_label(location_desc[index]+"   ·   10 回合期限   ·   灰潮收缩",16,RED))
 var deployment_grid=GridContainer.new()
 deployment_grid.columns=2
 deployment_grid.add_theme_constant_override("h_separation",12)
 deployment_grid.add_theme_constant_override("v_separation",10)
 modal_body.add_child(deployment_grid)
 for u in campaign.roster:
  if u.hp<=0:continue
  var id=u.id
  var b=character_card(u,func():
   if id in selected_ids:selected_ids.erase(id)
   elif selected_ids.size()<5:selected_ids.append(id)
   render_deploy(index),id in selected_ids,"已出战" if id in selected_ids else "留守")
  deployment_grid.add_child(b)
 var hero=campaign.roster.filter(func(u):return u.id=="hero")[0]
 var preview=Jobs.aura_for(campaign.character_stats(hero.id))
 modal_body.add_child(text_label("主角光环："+preview+(" · 上阵生效" if "hero" in selected_ids else " · 主角留守，本场不生效"),16,GOLD if "hero" in selected_ids else MUTED))
 var count=selected_ids.size()
 var start=button("出战 %d / 5 人  →"%count,func():begin_battle(index),true)
 start.disabled=count==0
 modal_body.add_child(start)
 modal_body.add_child(button("暂不交战",close_modal))

func begin_battle(index: int):
 var b=campaign.make_battle(selected_ids,index)
 if b==null:
  status_label.text=campaign.notice
  if is_instance_valid(modal):modal_body.add_child(text_label(campaign.notice,17,RED))
  return
 battle=b
 camera_zoom=16.5
 resolved=false
 battle_mode=""
 close_modal()
 draw_battle()
 refresh_ui()

func player_rest(kind: String):
 if battle==null or battle.active().is_empty() or battle.active().side!=0 or is_instance_valid(modal):return
 perform_battle_action("rest_"+kind)

func perform_battle_action(action: String,target=null) -> bool:
 if battle==null or presentation.busy or battle.outcome!="" or is_instance_valid(modal):return false
 var actor=battle.active()
 if actor.is_empty() or (action!="enemy" and actor.side!=0):return false
 var before=battle.actors.duplicate(true)
 var actor_id=actor.id
 var previous=actor.duplicate(true)
 var path: Array=[]
 var enemy_paths={}
 if action=="move":path=battle.path_to(actor.cell,target)
 if action=="enemy":
  for cell in battle.cells():enemy_paths[cell]=battle.path_to(actor.cell,cell)
 var used_skill=selected_skill if selected_skill!="" else battle.default_skill(actor)
 var accepted=false
 match action:
  "move":accepted=battle.move_to(target)
  "attack":accepted=battle.attack(target)
  "skill":accepted=battle.cast(target,used_skill)
  "rest_hp":accepted=battle.rest("hp")
  "rest_mp":accepted=battle.rest("mp")
  "end":accepted=battle.end_action()
  "item":
   if campaign.supplies>0:
    accepted=battle.use_medicine(target)
    if accepted:campaign.supplies-=1
  "enemy":
   var event_count=battle.events.size()
   battle.enemy_step()
   accepted=battle.events.size()!=event_count
   action="rest_hp"
   if actor.cell!=previous.cell:
    action="move"
    path=enemy_paths.get(actor.cell,[])
   else:
    for unit in battle.actors:
     var old=before.filter(func(u):return u.id==unit.id)[0]
     if unit.id!=actor_id and unit.hp<old.hp:action="attack";break
 if not accepted:return false
 if action=="move":
  var actual=path.find(actor.cell)
  if actual>=0:path=path.slice(0,actual+1)
 presentation.skill_effect=Jobs.SKILLS.get(used_skill,{}).get("effect","") if action=="skill" else ""
 presentation.skill_id=used_skill if action=="skill" else ""
 presentation.skill_target=target if action=="skill" else null
 presentation.start(self,before,battle.actors.duplicate(true),actor_id,action,path,str(target) if target is String else "")
 # Keep the old HUD values until the visible action lands; prevent every button callback.
 for node in footer.find_children("*","Button",true,false):node.disabled=true
 for node in sidebar.find_children("*","Button",true,false):node.disabled=true
 return true

func after_battle_action():
 battle_mode=""
 selected_skill=""
 draw_battle()
 refresh_ui()
 ai_clock=0
 if battle.outcome!="" and not resolved:
  resolved=true
  var result=battle.outcome
  campaign.resolve_battle(battle)
  if result=="victory":show_reward()
  elif result=="gameover":show_gameover()
  else:
   open_modal("出战队伍覆灭","仅有留守队员生还。该遭遇已失守，本次远征无法再次挑战。")
   set_page_back(Callable())
   for u in battle.actors:
    if u.side==0:modal_body.add_child(text_label("† "+u.name,19,RED))
   modal_body.add_child(button("由幸存者继续远征",return_world,true))

func return_world():
 close_modal()
 battle=null
 pending_location=-1
 arrived_location=-1
 draw_world()
 refresh_ui()

func show_reward():
 open_modal("战斗胜利  /  战利品三选一","宝物在远征中立即生效。安全撤离时最多带回两件，其余换成银币。")
 set_page_back(Callable())
 for i in range(campaign.choices.size()):
  var index=i
  var reward=campaign.choices[i]
  var p=PanelContainer.new()
  p.add_theme_stylebox_override("panel",style(Color("23363c"),Color(reward.color)))
  modal_body.add_child(p)
  var content=VBoxContainer.new()
  p.add_child(content)
  content.add_child(text_label(reward.name,22,Color(reward.color)))
  content.add_child(text_label(reward.desc,16))
  content.add_child(button("选择此奖励",func():
   if campaign.choose_reward(index):return_world(),true))

func show_extract():
 extraction_ids=[]
 for i in range(mini(2,campaign.relics.size())):extraction_ids.append(i)
 render_extract()

func render_extract():
 open_modal("抵达北岸渡口  /  安全撤离","最多选择 2 件远征宝物永久保留。其余每件兑换 25 银币；阵亡队员不会复活。")
 if campaign.relics.is_empty():modal_body.add_child(text_label("本次尚未获得宝物。已有资源仍会保留。",19))
 for i in range(campaign.relics.size()):
  var index=i
  var id=campaign.relics[i]
  for reward in Campaign.REWARDS:
   if reward.id==id:
    modal_body.add_child(button(("☑ " if i in extraction_ids else "□ ")+reward.name+"  /  "+reward.desc,func():
     if index in extraction_ids:extraction_ids.erase(index)
     elif extraction_ids.size()<2:extraction_ids.append(index)
     render_extract()))
 modal_body.add_child(button("保留 %d 件宝物，结束远征"%extraction_ids.size(),func():
  if campaign.extract(extraction_ids):
   close_modal()
   draw_world()
   refresh_ui(),true))
 modal_body.add_child(button("继续留在野外",close_modal))

func show_gameover():
 open_modal("行旅止于此  /  团长阵亡","没有获救，也没有死亡豁免。这段远征已经结束。")
 set_page_back(Callable())
 modal_body.add_child(text_label("你可以读取远征前的存档，重新规划路线与出战队伍。",20))
 modal_body.add_child(button("读取远征前存档",restore,true))
 modal_body.add_child(button("重新开始游戏",new_game))

func show_restore():
 open_modal("读取远征前存档？","本次远征的进度将回退，包括战利品、死亡和遭遇结果。")
 modal_body.add_child(button("确认读取",restore,true))
 modal_body.add_child(button("继续当前进度",close_modal))

func restore():
 if campaign.restore_snapshot():
  close_modal()
  battle=null
  pending_location=-1
  arrived_location=-1
  draw_world()
  refresh_ui()

func new_game():
 var fresh=Campaign.new(campaign.save_path)
 if not fresh.save_game():
  show_main_menu("无法创建存档，请检查本地存储空间或目录权限。原存档已保留。")
  return
 campaign=fresh
 enter_campaign()

func set_game_hud_visible(value: bool):
 for child in ui.get_children():
  if is_instance_valid(modal) and child==modal.get_parent():continue
  child.visible=value

func saved_campaign():
 var saved=Campaign.new(campaign.save_path)
 return saved if saved.load_game() else null

func show_main_menu(message: String=""):
 session_started=false
 open_modal("灰烬行旅", "A S H B O U N D   /   穿越灰潮，带同伴归来")
 menu_screen="main"
 set_page_back(Callable())
 set_game_hud_visible(false)
 var saved=saved_campaign()
 var summary="暂无存档 · 开始一段新的旅途"
 if saved!=null:
  var phases={"camp":"南境营地","world":"灰潮边境","reward":"待领取战利品","gameover":"团长阵亡 · 可回退远征"}
  summary="第 %d 次远征 · %s · 银币 %d"%[saved.expedition,phases.get(saved.phase,""),saved.silver]
  var data=JSON.parse_string(FileAccess.get_file_as_string(campaign.save_path))
  if data.get("saved_at","") is String and data.get("saved_at","")!="":summary+="\n保存于 "+data.saved_at
 elif FileAccess.file_exists(campaign.save_path):summary="存档无法读取 · 开始新游戏前会再次确认"
 modal_body.add_child(text_label(summary,17,MUTED))
 if message!="":modal_body.add_child(text_label(message,17,RED))
 modal_body.add_child(button("开始游戏",request_new_game,saved==null))
 var resume=button("继续游戏",continue_game,saved!=null)
 resume.disabled=saved==null
 modal_body.add_child(resume)
 modal_body.add_child(button("设置",func():show_settings(true)))
 modal_body.add_child(button("退出游戏",func():get_tree().quit()))

func request_new_game():
 if not FileAccess.file_exists(campaign.save_path):
  new_game()
  return
 open_modal("开始新的旅途？","新游戏将覆盖当前存档，包括队伍、装备与远征进度。")
 menu_screen="new"
 set_page_back(show_main_menu)
 modal_body.add_child(button("确认开始 · 覆盖存档",new_game,true))
 modal_body.add_child(button("取消 · 返回主菜单",show_main_menu))

func enter_campaign():
 close_modal()
 session_started=true
 set_game_hud_visible(true)
 battle=null
 pending_location=-1
 arrived_location=-1
 ai_clock=0
 resolved=false
 draw_world()
 refresh_ui()
 if campaign.phase=="reward":show_reward()
 elif campaign.phase=="gameover":show_gameover()

func continue_game() -> bool:
 var saved=saved_campaign()
 if saved==null:
  show_main_menu("无法读取存档。文件可能损坏，当前进度未被替换。")
  return false
 campaign=saved
 enter_campaign()
 return true

func show_pause_menu(message: String=""):
 if presentation.busy or not session_started:return
 # Mandatory reward/game-over/deployment dialogs keep their own flow.
 if is_instance_valid(modal) and menu_screen=="":return
 open_modal("旅途菜单", "游戏已暂停。战斗中读档将回到开战前。")
 menu_screen="pause"
 if message!="":modal_body.add_child(text_label(message,18,TEAL))
 modal_body.add_child(button("返回游戏",close_modal,true))
 var save=button("保存游戏"+(" · 战斗中不可用" if battle!=null else ""),manual_save)
 save.disabled=battle!=null
 modal_body.add_child(save)
 modal_body.add_child(button("设置",func():show_settings(false)))
 modal_body.add_child(button("返回主菜单",request_main_menu))

func manual_save():
 if battle!=null:return
 var success=campaign.save_game()
 show_pause_menu("游戏已保存。" if success else "保存失败，请检查本地存储空间与目录权限。")

func request_main_menu():
 open_modal("返回主菜单？", "本场战斗进度不会保存；继续游戏将回到开战前。" if battle!=null else "返回前会保存当前旅途进度。")
 menu_screen="return"
 set_page_back(show_pause_menu)
 modal_body.add_child(button("确认返回主菜单",return_to_main_menu,true))
 modal_body.add_child(button("取消 · 返回旅途菜单",show_pause_menu))

func return_to_main_menu():
 if presentation.busy:return
 if battle==null and session_started and not campaign.save_game():
  show_pause_menu("保存失败，已保留当前游戏。请检查存储空间后重试。")
  return
 battle=null
 pending_location=-1
 arrived_location=-1
 show_main_menu()

func show_settings(from_main: bool):
 open_modal("设置", "显示与操作偏好会保存在本机。")
 menu_screen="settings"
 var fullscreen=CheckButton.new()
 fullscreen.text="全屏显示"
 fullscreen.button_pressed=DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN
 fullscreen.toggled.connect(func(enabled):
  DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED))
 modal_body.add_child(fullscreen)
 var settings_status=text_label("地图使用固定视距，无需缩放。",17,MUTED)
 modal_body.add_child(settings_status)
 set_page_back(func():
  if not save_settings():
   settings_status.text="设置保存失败，请检查本地存储空间。"
   return
  if from_main:show_main_menu()
  else:show_pause_menu())
 modal_body.add_child(button("返回",navigate_back))

func load_settings():
 var config=ConfigFile.new()
 if config.load(settings_path)!=OK:return
 var fullscreen=config.get_value("display","fullscreen",false)
 if fullscreen is bool:
  DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func save_settings() -> bool:
 var config=ConfigFile.new()
 config.set_value("display","fullscreen",DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN)
 return config.save(settings_path)==OK

func _notification(what):
 if what==NOTIFICATION_WM_CLOSE_REQUEST:
  if session_started and battle==null and not campaign.save_game():
   if is_instance_valid(modal):
    modal_body.add_child(text_label("保存失败，已保留当前游戏。请检查存储空间后再退出。",17,RED))
   else:show_pause_menu("保存失败，已保留当前游戏。请先保存后再退出。")
   return
  get_tree().quit()

func show_surrender():
 if presentation.busy:return
 open_modal("放弃本场战斗？","按超时失败处理：所有出战队员死亡；主角参战则游戏结束。")
 modal_body.add_child(button("确认放弃，出战者全部死亡",func():
  close_modal()
  battle.round_no=battle.round_limit
  battle.order_index=battle.order.size()-1
  battle.finish_turn()
  after_battle_action()))
 modal_body.add_child(button("返回战斗",close_modal,true))

func ground_position(screen_pos: Vector2) -> Vector3:
 var origin=camera.project_ray_origin(screen_pos)
 var dir=camera.project_ray_normal(screen_pos)
 if absf(dir.y)<0.001:return Vector3.ZERO
 return origin+dir*(-origin.y/dir.y)

func _unhandled_input(event):
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE and battle!=null and battle_mode!="" and not is_instance_valid(modal):
  cancel_action()
  get_viewport().set_input_as_handled()
  return
 if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT and battle!=null and not is_instance_valid(modal):
  cancel_action()
  get_viewport().set_input_as_handled()
  return
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
  if presentation.busy:return
  if is_instance_valid(modal):navigate_back()
  else:show_pause_menu()
  get_viewport().set_input_as_handled()
  return
 if is_instance_valid(modal) or presentation.busy:return
 if event is InputEventKey and event.pressed:
  if event.keycode==KEY_Q:camera_angle-=0.15;update_camera()
  if event.keycode==KEY_E:camera_angle+=0.15;update_camera()
 if event is InputEventMouseButton and event.pressed:
  if event.button_index!=MOUSE_BUTTON_LEFT:return
  var p=ground_position(event.position)
  if battle==null:
   if campaign.phase!="world" or campaign.route.region!="":return
   for i in range(location_positions.size()):
    if p.distance_to(location_positions[i])<2:
     travel_to(i)
     return
   world_target=Vector3(clampf(p.x,-13,13),0,clampf(p.z,-16,11))
   pending_location=-1
  elif battle.outcome=="" and battle.active().side==0:
   var nearest=Vector2i(999,999)
   var best=1.1
   for cell in battle.cells():
    var distance=cell_position(cell).distance_to(p)
    if distance<best:nearest=cell;best=distance
   if battle_mode in ["attack","skill","item"] and not (battle_mode=="skill" and Jobs.SKILLS.get(selected_skill,{}).get("target","")=="cell"):
    var model_distance=30.0
    for unit in battle.actors:
     if unit.hp<=0:continue
     var screen=camera.unproject_position(cell_position(unit.cell)+Vector3(0,0.75,0))
     var distance=screen.distance_to(event.position)
     if distance<model_distance:
      model_distance=distance
      nearest=unit.cell
   if nearest.x==999:return
   var target=battle.unit_at(nearest)
   var accepted=false
   if battle_mode=="move":accepted=perform_battle_action("move",nearest)
   elif battle_mode=="skill" and Jobs.SKILLS.get(selected_skill,{}).get("target","")=="cell":accepted=perform_battle_action("skill",nearest)
   elif not target.is_empty():
    if battle_mode=="attack":accepted=perform_battle_action("attack",target.id)
    elif battle_mode in ["skill","item"]:accepted=perform_battle_action(battle_mode,target.id)
   if not accepted:status_label.text="无法执行：检查行动点、法力、射程与目标阵营。"

func _process(delta):
 elapsed+=delta
 if presentation.busy:
  presentation.advance(delta)
  return
 for i in range(pawn_nodes.size()):
  var pawn=pawn_nodes[i]
  if is_instance_valid(pawn):
   var body=pawn.get_node_or_null("Body")
   if body!=null and body.find_child("AnimationPlayer",true,false)==null:body.position.y=sin(elapsed*2.1+i*0.8)*0.012
 if battle==null and campaign.phase=="world" and campaign.route.region=="" and world_party!=null and not is_instance_valid(modal):
  var delta_pos=world_target-world_party.position
  if delta_pos.length()>0.06:
   if not world_party.get_meta("walking",false):
    preload("res://game/character_visual.gd").play(world_party,"move")
    world_party.set_meta("walking",true)
   world_party.get_node("Body").rotation.y=atan2(delta_pos.x,delta_pos.z)+world_party.get_meta("forward_offset",0.0)
   world_party.position=world_party.position.move_toward(world_target,delta*4)
   campaign.world_position=[world_party.position.x,world_party.position.z]
  else:
   if world_party.get_meta("walking",false):
    preload("res://game/character_visual.gd").play(world_party,"idle")
    world_party.set_meta("walking",false)
  if delta_pos.length()<=0.06 and pending_location>=0:
   var index=pending_location
   pending_location=-1
   campaign.save_game()
   arrive(index)
 if battle!=null and battle.outcome=="" and not is_instance_valid(modal) and battle.active().side==1:
  ai_clock+=delta
  if ai_clock>=0.6:
   ai_clock=0
   perform_battle_action("enemy")
 if capture_mode!="" and not capture_done:
  capture_clock+=delta
  if capture_clock>2.5:
   capture_done=true
   capture_image()

func capture_image():
 await RenderingServer.frame_post_draw
 var image=get_viewport().get_texture().get_image()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
 var filename="battle" if battle!=null else "world"
 if capture_mode=="--capture-menu":filename="menu"
 if capture_mode=="--capture-atlas":filename="atlas"
 if capture_mode=="--capture-route":filename="route"
 if capture_mode=="--capture-actions":filename="actions"
 if capture_mode=="--capture-shrink":filename="shrink"
 if capture_mode=="--capture-tide":filename="tide"
 var path="res://artifacts/"+filename+".png"
 image.save_png(path)
 print("CAPTURE_READY ",ProjectSettings.globalize_path(path))
 get_tree().quit()

func menu_unit(character_id: String) -> Dictionary:
 if battle!=null:
  for actor in battle.actors:
   if actor.id==character_id:return actor
 for unit in campaign.roster:
  if unit.id==character_id:return unit
 return campaign.roster[0]

func detail_section(parent: Control,title: String):
 separator(parent)
 parent.add_child(text_label(title,20,GOLD))

func show_party_menu(tab: String="详情",character_id: String=""):
 if tab=="角色":tab="详情"
 menu_tab=tab
 if character_id!="":menu_character=character_id
 var unit=menu_unit(menu_character)
 menu_character=unit.id
 open_modal("佣兵团档案", "选择同伴 · 查看详情 · 整理装备与技能")
 party_menu_open=true
 var frame=modal.get_child(0)
 var original_scroll=frame.get_child(1)
 frame.remove_child(original_scroll)
 frame.add_theme_constant_override("separation",10)
 for heading in modal_body.get_children():
  modal_body.remove_child(heading)
  frame.add_child(heading)
 original_scroll.queue_free()
 var tabs=HBoxContainer.new()
 frame.add_child(tabs)
 for section in ["详情","装备","技能","职业","物品","遗物"]:
  var target=section
  var entry=button(section,func():show_party_menu(target),section==tab)
  entry.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  tabs.add_child(entry)
 var columns=HBoxContainer.new()
 columns.size_flags_vertical=Control.SIZE_EXPAND_FILL
 columns.add_theme_constant_override("separation",16 if tab=="装备" else 24)
 frame.add_child(columns)
 var roster_scroll=ScrollContainer.new()
 roster_scroll.name="CharacterRosterScroll"
 roster_scroll.custom_minimum_size.x=320
 roster_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 columns.add_child(roster_scroll)
 var roster_list=VBoxContainer.new()
 roster_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 roster_list.add_theme_constant_override("separation",8)
 roster_scroll.add_child(roster_list)
 roster_list.add_child(text_label("队伍成员  /  %d 人"%campaign.roster.size(),16,GOLD))
 for member in campaign.roster:
  var id=member.id
  var current=menu_unit(id)
  var entry=character_card(current,func():show_party_menu(menu_tab,id),id==menu_character)
  entry.add_theme_font_size_override("font_size",16)
  roster_list.add_child(entry)
 if tab=="装备":
  var preview=preload("res://game/equipment_preview.gd").new()
  preview.font=game_font
  columns.add_child(preview)
  preview.show_character(unit.id,campaign.visual_profile(unit.id),equipment_view_states.get(unit.id,{}))
  var preview_id=unit.id
  preview.view_changed.connect(func(state):equipment_view_states[preview_id]=state)
 var right=VBoxContainer.new()
 right.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 right.add_theme_constant_override("separation",12)
 columns.add_child(right)
 var header=HBoxContainer.new()
 header.add_theme_constant_override("separation",18)
 right.add_child(header)
 var portrait=TextureRect.new()
 portrait.texture=portraits.portrait(unit.id,campaign.visual_profile(unit.id))
 portrait.custom_minimum_size=Vector2(80,80) if tab=="装备" else Vector2(112,112)
 portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 header.add_child(portrait)
 var identity=VBoxContainer.new()
 identity.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 identity.alignment=BoxContainer.ALIGNMENT_CENTER
 header.add_child(identity)
 identity.add_child(text_label(unit.name+"  /  "+unit.role,26,GOLD))
 identity.add_child(text_label("身份："+unit.identity+" · "+tab,16,TEAL))
 identity.add_child(text_label("已阵亡 · 无法出战" if unit.hp<=0 else ("正在战场 · 实时状态" if battle!=null and battle.find_actor(unit.id)!={} else "存活 · 可参与远征"),15,RED if unit.hp<=0 else MUTED))
 var page_scroll=ScrollContainer.new()
 page_scroll.name="CharacterPageScroll"
 page_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
 page_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 right.add_child(page_scroll)
 var details=VBoxContainer.new()
 details.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 details.add_theme_constant_override("separation",10)
 page_scroll.add_child(details)
 modal_body=details
 if tab=="详情":PartyDetails.role_page(self,details,unit)
 elif tab=="装备":PartyDetails.equipment_page(self,details,unit)
 elif tab=="技能":PartyDetails.skills_page(self,details,unit)
 elif tab=="职业":PartyDetails.profession_page(self,details,unit)
 elif tab=="物品":
  detail_section(details,"队伍共享物品")
  details.add_child(text_label("银币  %d"%campaign.silver,22,GOLD))
  details.add_child(text_label("补给  × %d"%campaign.supplies,22,TEAL))
  details.add_child(text_label("消耗 1 份补给，为所有存活队员恢复 30% 最大生命与法力。只能在野外使用。",17))
  var supply=button("使用一份补给",func():
   if campaign.use_supply():
    refresh_ui()
    show_party_menu("物品"))
  supply.disabled=campaign.phase!="world" or battle!=null or campaign.supplies<=0
  details.add_child(supply)
 else:
  detail_section(details,"遗物与永久收藏")
  details.add_child(text_label("远征携带 %d 件 · 永久收藏 %d 件\n同类加成不叠加，全队共享。"%[campaign.relics.size(),campaign.collection.size()],17,MUTED))
  show_relic_details(details,false)
 separator(frame)
 frame.add_child(button("关闭菜单 · 返回旅途",close_modal))

func show_relic_details(parent: Control,effects_only: bool):
 var found=false
 for reward in Campaign.REWARDS:
  if reward.type!="relic" or reward.id not in campaign.active_relics():continue
  if effects_only and reward.id=="lens":continue
  found=true
  var source="永久收藏" if reward.id in campaign.collection else "本次远征"
  parent.add_child(text_label("◆ "+reward.name+"  ·  "+source,17,TEAL))
  var description=reward.desc
  if reward.id=="lens":description="拾取时已获得 30 银币；收藏后不重复发放，无战斗属性加成。"
  parent.add_child(text_label(description+(" · 阵亡角色无法享受战斗效果" if effects_only and menu_unit(menu_character).hp<=0 else ""),15,MUTED))
 if not found:parent.add_child(text_label("暂无生效的战斗遗物。" if effects_only else "暂无遗物。探索边境并安全撤离，可积累永久收藏。",16,MUTED))

func refresh_atlas():
 if is_instance_valid(atlas):
  ui.remove_child(atlas)
  atlas.queue_free()
 atlas=null
 if battle!=null or (campaign.phase!="camp" and campaign.route.region==""):return
 atlas=preload("res://game/atlas.gd").new()
 atlas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 atlas.route=campaign.route
 atlas.route_mode=campaign.phase!="camp"
 ui.add_child(atlas)
 var heading=text_label("灰烬行旅  /  世界地图" if campaign.phase=="camp" else "远征路线  /  "+region_name(),30,GOLD)
 heading.position=Vector2(65,55)
 heading.size=Vector2(850,50)
 atlas.add_child(heading)
 var subtitle=text_label("选择地图地点，开启新的远征" if selecting_expedition else ("整备佣兵团，规划下一段旅途" if campaign.phase=="camp" else "仅显示前方两步 · 选择分支后无法回头"),18,CREAM)
 subtitle.position=Vector2(66,110)
 subtitle.size=Vector2(850,45)
 atlas.add_child(subtitle)
 var menu=panel(atlas,Vector2(1140,55),Vector2(255,310))
 var entries=VBoxContainer.new()
 entries.add_theme_constant_override("separation",10)
 menu.add_child(entries)
 entries.add_child(text_label("佣兵团行囊",23,GOLD))
 entries.add_child(text_label("银币 %d · 补给 %d"%[campaign.silver,campaign.supplies],17))
 entries.add_child(button("队伍与装备",func():show_party_menu("角色")))
 entries.add_child(button("技能与技能书",func():show_party_menu("技能")))
 entries.add_child(button("保存与菜单",show_pause_menu))
 if campaign.phase=="camp":entries.add_child(button("选择远征",depart,true))
 var note=text_label(campaign.notice,18,CREAM)
 note.position=Vector2(66,790)
 note.size=Vector2(1000,60)
 atlas.add_child(note)
 if campaign.phase=="camp":
  for region in Campaign.Route.REGIONS:
   var region_id=region.id
   var entry=button("◆ "+region.name,func():show_region(region_id),selecting_expedition)
   entry.position=region.pos*Vector2(1350,900)-Vector2(85,0)
   entry.custom_minimum_size=Vector2(180,55)
   atlas.add_child(entry)
  var legend=text_label("灰潮边境       苍翠林海       赤砂荒原\n大陆上的每个地点，都通向一段独立远征。",18,CREAM)
  legend.position=Vector2(66,700)
  legend.size=Vector2(900,70)
  atlas.add_child(legend)
 else:
  for n in campaign.route.visible_nodes():
   var node_id=n.id
   var entry=button(node_title(n.kind),func():select_route_node(node_id),n.id==campaign.route.current)
   entry.position=atlas.node_position(n)-Vector2(70,24)
   entry.custom_minimum_size=Vector2(140,48)
   entry.disabled=n.id not in campaign.route.available() and n.id!=campaign.route.current
   atlas.add_child(entry)
  var hint=text_label("战斗 · 事件 · 补给 · 商店 · 雇佣兵营地 · 撤离\n暗色地点尚未到达；走过的另一条分支会消失。",17,CREAM)
  hint.position=Vector2(66,690)
  hint.size=Vector2(1000,75)
  atlas.add_child(hint)
 # Map covers the older exploration HUD, while modal dialogs remain above it.
 if is_instance_valid(modal):ui.move_child(modal.get_parent(),-1)

func region_name() -> String:
 for r in Campaign.Route.REGIONS:
  if r.id==campaign.route.region:return r.name
 return "灰潮边境"

func node_title(kind: String) -> String:
 return {"battle":"交战","event":"未知事件","supply":"补给","shop":"商店","hire":"佣兵营地","extract":"安全撤离"}.get(kind,kind)

func show_region(id: String):
 for r in Campaign.Route.REGIONS:
  if r.id!=id:continue
  open_modal(r.name,r.desc+"\n五段分支路线 · 渐进揭示 · 成功撤离才能带回遗物")
  modal_body.add_child(text_label("区域采用不同节点排列；当前共用边境战场与敌人配置。",17,MUTED))
  modal_body.add_child(button("确认出发",func():
   if campaign.start_region(id):
    close_modal()
    selecting_expedition=false
    pending_location=-1
    refresh_ui(),true))
  modal_body.add_child(button("返回世界地图",close_modal))

func select_route_node(id: String):
 if id!=campaign.route.current:
  if not campaign.enter_route(id):return
  refresh_ui()
 var n=campaign.route.node(id)
 if n.kind=="battle" and not campaign.route.completed:show_deploy(int(n.encounter))
 elif n.kind=="extract":show_extract()
 elif n.kind in ["shop","hire"]:show_route_trade()

func show_route_trade():
 var shop=campaign.at_node("shop")
 open_modal("行路商店" if shop else "雇佣兵营地","银币 %d · 离开后不能返回；可以关闭窗口继续选择路线。"%campaign.silver)
 if shop:
  for id in Campaign.GOODS:
   var item_id=id
   var good=Campaign.GOODS[id]
   modal_body.add_child(text_label(good.name+" · "+good.desc,18))
   var entry=button("购买 · %d 银币"%good.price,func():
    if campaign.buy(item_id):
     refresh_ui()
     show_route_trade())
   entry.disabled=campaign.silver<good.price or campaign.route.current+":"+id in campaign.purchases
   modal_body.add_child(entry)
 else:
  for i in range(2):
   var index=i
   modal_body.add_child(text_label("林鸦 · 荒原猎手 · 生命52 / 法力24 · 攻击17 · 射程3" if i==0 else "青禾 · 行医者 · 生命54 / 法力40 · 攻击12 · 治疗战技",17))
   var entry=button("招募 · 55 银币",func():
    if campaign.hire(index):
     refresh_ui()
     show_route_trade())
   entry.disabled=campaign.silver<55 or campaign.roster.size()>=10 or campaign.route.current+":"+str(i) in campaign.recruits
   modal_body.add_child(entry)
  modal_body.add_child(text_label("队伍档案 %d / 10"%campaign.roster.size(),16,MUTED))
 modal_body.add_child(button("继续旅途",close_modal))

func select_action(mode: String):
 if battle==null or presentation.busy or battle.outcome!="" or battle.active().is_empty() or battle.active().side!=0:return
 battle_mode=mode
 if mode!="skill":selected_skill=""
 elif selected_skill=="":selected_skill=battle.default_skill(battle.active())
 draw_battle()
 refresh_ui()

func select_skill(id: String):
 if battle==null or id not in battle.available_skills(battle.active()):return
 selected_skill=id
 select_action("skill")

func target_cell_allowed(cell: Vector2i) -> bool:
 return battle!=null and battle_mode=="skill" and Jobs.SKILLS.get(selected_skill,{}).get("target","")=="cell" and battle.can_cast(selected_skill,cell)

func cancel_action():
 if presentation.busy:return
 select_action("")

func target_allowed(target: Dictionary) -> bool:
 if battle==null or target.is_empty() or target.hp<=0:return false
 var a=battle.active()
 if a.is_empty():return false
 var distance=battle.hex_distance(a.cell,target.cell)
 if battle_mode=="attack":return target.side!=a.side and distance<=a.range
 if battle_mode=="skill":return battle.can_cast(selected_skill,target.id)
 if battle_mode=="item":return target.side==0 and distance<=3 and (target.hp<target.max_hp or target.mp<target.max_mp)
 return false

func action_button(parent: Control,label_text: String,mode: String,reason: String=""):
 var selected=battle_mode==mode or (mode=="skills" and battle_mode=="skill") or (mode=="items" and battle_mode=="item")
 var entry=button(("▶ " if selected else "")+label_text,func():select_action(mode),selected)
 entry.alignment=HORIZONTAL_ALIGNMENT_LEFT
 entry.add_theme_font_size_override("font_size",16)
 entry.disabled=reason!="" or presentation.busy
 entry.tooltip_text=reason
 if reason!="":entry.text+=" · "+reason
 parent.add_child(entry)
 return entry

func render_action_menu(is_player: bool):
 var slot=sidebar.get_node("ActionCommands")
 var a=battle.active()
 if a.is_empty():return
 slot.add_child(text_label(a.name+" · "+a.role,23,GOLD))
 slot.add_child(text_label("生命 %d/%d · 法力 %d/%d\n行动点 %d / %d · 防护%d"%[a.hp,a.max_hp,a.mp,a.max_mp,a.ap,a.get("max_ap",4),a.get("armor",0)],16,CREAM))
 slot.add_child(text_label("主角光环："+battle.aura_description(),14,TEAL))
 var states=battle.status_text(a)
 if states!="":slot.add_child(text_label(states,14,GOLD))
 if battle_mode=="skill" and Jobs.SKILLS.has(selected_skill):
  var skill=Jobs.SKILLS[selected_skill]
  slot.add_child(text_label(skill.name+" · %d点 / %d法力 · 射程%d"%[skill.ap,skill.mp,skill.range]+"\n"+skill.desc,15,TEAL))
 var waiting="敌方行动中" if not is_player else ""
 if presentation.busy:waiting="行动播放中"
 var ap2=waiting if waiting!="" else ("需2行动点" if a.ap<2 else "")
 var item_reason=ap2 if ap2!="" else ("补给不足" if campaign.supplies<=0 else "")
 if battle_mode in ["","move","attack","skill","item"]:
  action_button(slot,"移动 · 1点/格","move",waiting if waiting!="" else ("行动点不足" if a.ap<1 else ""))
  var attack_reason=ap2
  if attack_reason=="" and not battle.actors.any(func(u):return u.hp>0 and u.side!=a.side and battle.hex_distance(a.cell,u.cell)<=a.range):attack_reason="无射程内敌人"
  action_button(slot,"普通攻击 · 2点","attack",attack_reason)
  action_button(slot,"技能 →","skills",waiting)
  action_button(slot,"物品 →","items",waiting)
  action_button(slot,"休息 →","rest",waiting)
  var end=button("结束行动",func():perform_battle_action("end"))
  end.disabled=waiting!=""
  slot.add_child(end)
 elif battle_mode=="skills":
  slot.add_child(text_label("选择技能 · 每次行动各限用一次",18,GOLD))
  for skill_id in battle.available_skills(a):
   var id=skill_id
   var skill=Jobs.SKILLS[id]
   var reason=waiting
   if reason=="" and id in a.get("used_skills",[]):reason="本次已用"
   if reason=="" and a.ap<skill.ap:reason="行动点不足"
   if reason=="" and a.mp<skill.mp:reason="法力不足"
   if reason=="":
    var has_target=false
    if skill.target=="cell":has_target=battle.cells().any(func(cell):return battle.can_cast(id,cell))
    else:has_target=battle.actors.any(func(u):return battle.can_cast(id,u.id))
    if not has_target:reason="无合法目标"
   var entry=button(skill.name+" · %d点 / %d法力"%[skill.ap,skill.mp]+(" · "+reason if reason!="" else ""),func():select_skill(id))
   entry.disabled=reason!=""
   slot.add_child(entry)
   slot.add_child(text_label(skill.desc+" · 射程%d"%skill.range,14,TEAL))
  for id in a.get("learned",[]):
   if id in ["fury","focus"]:slot.add_child(text_label(Campaign.GOODS[id].name+"（被动）",14,TEAL))
 elif battle_mode=="items":
  slot.add_child(text_label("选择物品",19,GOLD))
  if item_reason=="" and not battle.actors.any(func(u):return u.side==0 and u.hp>0 and battle.hex_distance(a.cell,u.cell)<=3 and (u.hp<u.max_hp or u.mp<u.max_mp)):item_reason="无须恢复的友军"
  action_button(slot,"战地补给 ×%d · 2点"%campaign.supplies,"item",item_reason)
  slot.add_child(text_label("消耗1份补给，为射程3内一名存活友军恢复30%生命与法力。",15,TEAL))
 elif battle_mode=="rest":
  slot.add_child(text_label("休息并结束行动",19,GOLD))
  for kind in ["hp","mp"]:
   var resource=kind
   var gain=battle.rest_amount(kind)
   var entry=button(("恢复生命" if kind=="hp" else "恢复法力")+" +%d"%gain,func():player_rest(resource))
   entry.disabled=waiting!="" or gain<=0
   if gain<=0:entry.text+=" · 已满"
   slot.add_child(entry)
  slot.add_child(text_label("消耗剩余全部行动点；恢复后轮到下一人。",14,MUTED))
 if battle_mode!="":
  var cancel=button("取消 / 返回 · Esc",cancel_action)
  cancel.disabled=presentation.busy
  slot.add_child(cancel)
 separator(slot)
 var hints={"":"请选择左侧角色指令。","move":"选择青色可达格移动 · 每格1行动点","attack":"选择红色格上的敌人 · 普通攻击消耗2行动点","skills":"从左侧选择技能，再选择目标。","skill":"选择高亮目标施放技能；机关选择空格","items":"从左侧选择物品，再选择友军。","item":"选择高亮友军使用补给 · 2行动点 / 1份补给","rest":"在左侧选择恢复生命或法力。"}
 footer.add_child(text_label(hints.get(battle_mode,"") if is_player else "敌方正在行动，请等待。",21,GOLD))
 footer.add_child(text_label("当前："+a.name+" · 行动点 %d/%d · 生命 %d/%d · 法力 %d/%d"%[a.ap,a.get("max_ap",4),a.hp,a.max_hp,a.mp,a.max_mp],17))
 if battle_mode!="":footer.add_child(text_label("Esc / 鼠标右键取消选择，不消耗资源。",15,MUTED))
