extends Node3D
const Campaign = preload("res://game/campaign.gd")
const Rules = preload("res://game/rules.gd")
const Art = preload("res://game/art.gd")
var art=Art.new()
var presentation=preload("res://game/combat_presentation.gd").new()
const INK = Color("111c24")
const GOLD = Color("d5b57a")
const CREAM = Color("e4e5dc")
const MUTED = Color("93a5aa")
const TEAL = Color("78c9ba")
const RED = Color("df796b")
var campaign = Campaign.new()
var battle
var scene_root: Node3D
var ui: Control
var sidebar: VBoxContainer
var footer: VBoxContainer
var top_label: Label
var status_label: Label
var modal: PanelContainer
var modal_body: VBoxContainer
var camera: Camera3D
var world_party: Node3D
var world_target = Vector3.ZERO
var pending_location = -1
var arrived_location = -1
var selected_ids: Array = []
var extraction_ids: Array = []
var battle_mode = "move"
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
var location_positions = [Vector3(-6,0,1),Vector3(5,0,-4),Vector3(-3,0,-8),Vector3(2,0,-12),Vector3(6,0,4)]
var location_names = ["断桥哨站","遗械坟场","灰巢营地","北岸渡口","废弃驿站"]
var location_desc = ["3 名敌人 · 首次交锋","4 名敌人 · 深入边境","5 名敌人 · 高风险","指定撤离点 · 结算宝物","一次性补给 · 搜索遗物"]

func _ready():
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
 if capture_mode != "":
  campaign.save_path="user://ashbound-capture.json"
  campaign.depart()
  if capture_mode == "--capture-battle":
   battle = campaign.make_battle(["hero","blade","ranger","medic","engineer"],0)
   battle.actors[1].hp = 36
  if capture_mode in ["--capture-shrink","--capture-tide"]:
   battle = campaign.make_battle(["hero","blade","ranger","medic","engineer"],0)
   battle.round_no=3
   if capture_mode=="--capture-tide":
    battle.shrink()
    battle.round_no=4
 if capture_mode == "":campaign.load_game()
 if campaign.phase == "battle" and battle==null:campaign.phase="world"
 if battle != null:
  camera_zoom=16.5
  draw_battle()
 else:draw_world()
 refresh_ui()
 if campaign.phase == "reward":show_reward()
 elif campaign.phase == "gameover":show_gameover()
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
 var root=art.character(scene_root,pos,color,kind,active)
 pawn_nodes.append(root)
 return root

func tree_at(pos: Vector3,scale_factor: float):
 return art.tree(scene_root,pos,scale_factor)

func draw_world():
 clear_scene()
 camera_zoom = 28
 camera_angle = 0
 box(Vector3(0,-0.65,-3),Vector3(29,1,34),Color("364c43"))
 box(Vector3(0,-1.25,-3),Vector3(29,0.5,34),Color("263a36"))
 art.grass(scene_root,4481,1400,Vector2(14,15))
 # Meandering roads and a cold river provide readable landmarks.
 for z in range(-13,10):
  var x = sin(z*0.24)*1.7
  box(Vector3(x,-0.12,z),Vector3(2.2,0.05,1.15),Color("8a8167"))
 for x in range(-14,15):
  var z = -10.5+sin(x*0.28)*1.2
  box(Vector3(x,-0.02,z),Vector3(1.1,0.06,2),Color("4e8590"))
 for z in range(-12,-8):box(Vector3(2,0.07,z),Vector3(2.3,0.12,0.6),Color("8b7152"))
 var rng = RandomNumberGenerator.new()
 rng.seed = 4481
 for i in range(85):
  var pos = Vector3(rng.randf_range(-13.5,13.5),0,rng.randf_range(-18,12))
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
  if not a.is_empty() and a.cell==cell:col=Color("abac6e")
  cylinder(p+Vector3(0,-0.075,0),0.765,0.765,0.025,col,6)
  art.ring(scene_root,p+Vector3(0,-0.057,0),0.765,Color("62765b"),0.012)
  if warning:
   art.ring(scene_root,p+Vector3(0,-0.045,0),0.755,Color("d6a268"),0.045)
  if cell in battle.obstacles:
   art.rock(scene_root,p+Vector3(0,0.22,0),Vector3(0.85,0.65,0.75),Color("b1ae92"))
   art.rock(scene_root,p+Vector3(0.27,0.02,0.15),Vector3(0.35,0.28,0.4),Color("a2a58b"))
 for u in battle.actors:
  if u.hp<=0:continue
  var col = Color("b46555") if u.side==1 else Color("6eaaa5")
  if u.id=="hero":col=Color("c4a56b")
  if u.id=="medic":col=Color("9db68b")
  var root = make_pawn(cell_position(u.cell),col,u.id,not a.is_empty() and a.id==u.id)
  label3(u.name,Vector3(0,1.93,0),CREAM,23,root)
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
 info.add_child(text_label("点击地面移动 · 点击地标交互\n滚轮缩放 · Q / E 旋转视角",14,MUTED))
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
 empty_children(sidebar)
 empty_children(footer)
 top_label.text="第 %d 次远征    ·    银币 %d    ·    补给 %d"%[campaign.expedition,campaign.silver,campaign.supplies]
 if battle==null:
  sidebar.add_child(text_label("佣兵团 · %d / 10"%campaign.roster.filter(func(u):return u.hp>0).size(),23,GOLD))
  sidebar.add_child(text_label("最多 5 人出战，其余留守。\n阵亡永久失去；团长死亡则游戏结束。",14,MUTED))
  for u in campaign.roster:
   var row=VBoxContainer.new()
   sidebar.add_child(row)
   row.add_child(text_label(u.name+"  /  "+u.role,17,CREAM if u.hp>0 else RED))
   row.add_child(text_label("生命 %d / %d   法力 %d / %d"%[u.hp,u.max_hp,u.mp,u.max_mp] if u.hp>0 else "已阵亡 · 无法出战",13,MUTED))
   var hp=ProgressBar.new()
   hp.custom_minimum_size.y=5
   hp.max_value=u.max_hp
   hp.value=u.hp
   hp.show_percentage=false
   var fill_style=style(TEAL,Color.TRANSPARENT,2)
   var back_style=style(Color("293a41"),Color.TRANSPARENT,2)
   for bar_style in [fill_style,back_style]:
    bar_style.content_margin_left=0
    bar_style.content_margin_right=0
    bar_style.content_margin_top=0
    bar_style.content_margin_bottom=0
   hp.add_theme_stylebox_override("fill",fill_style)
   hp.add_theme_stylebox_override("background",back_style)
   row.add_child(hp)
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
   status_label.text="%s  /  %s    生命 %d/%d    法力 %d/%d    行动点 %d/4"%[a.name,a.role,a.hp,a.max_hp,a.mp,a.max_mp,a.ap]
  footer.add_child(text_label("选择行动，再点击格子或角色。青色格可移动，◆ 标记普通攻击射程内敌人。" if is_player else "敌方正在行动…",16,GOLD))
  var row=HBoxContainer.new()
  row.add_theme_constant_override("separation",9)
  footer.add_child(row)
  for item in [["移动 · 1点/格","move"],["攻击 · 2点","attack"],["战技 · 3点 / 8蓝","skill"]]:
   var mode=item[1]
   var b=button(("● " if battle_mode==mode else "")+item[0],func():
    if presentation.busy:return
    battle_mode=mode
    draw_battle()
    refresh_ui())
   b.disabled=not is_player
   row.add_child(b)
  var hp=button("休息 · 回血 +%d"%battle.rest_amount("hp"),func():player_rest("hp"))
  var mp=button("休息 · 回蓝 +%d"%battle.rest_amount("mp"),func():player_rest("mp"))
  hp.disabled=not is_player
  mp.disabled=not is_player
  row.add_child(hp)
  row.add_child(mp)
  sidebar.add_child(text_label("战技：医者治疗友军，其余角色攻击敌人；射程 3 格。",13,TEAL))
  sidebar.add_child(button("放弃战斗…",show_surrender))

func close_modal():
 if is_instance_valid(modal):
  var shade=modal.get_parent()
  ui.remove_child(shade)
  shade.queue_free()
 modal=null

func open_modal(title: String,subtitle: String):
 close_modal()
 var shade=ColorRect.new()
 shade.color=Color(0.02,0.04,0.06,0.83)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 ui.add_child(shade)
 modal=panel(shade,Vector2(380,150),Vector2(830,580))
 var scroll=ScrollContainer.new()
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 modal.add_child(scroll)
 modal_body=VBoxContainer.new()
 modal_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 modal_body.add_theme_constant_override("separation",14)
 scroll.add_child(modal_body)
 modal_body.add_child(text_label(title,29,GOLD))
 modal_body.add_child(text_label(subtitle,17,MUTED))
 separator(modal_body)

func depart():
 if campaign.depart():
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
 for u in campaign.roster:
  if u.hp<=0:continue
  var id=u.id
  var b=button(("☑  " if id in selected_ids else "□  ")+"%s / %s    生命 %d/%d    法力 %d/%d"%[u.name,u.role,u.hp,u.max_hp,u.mp,u.max_mp],func():
   if id in selected_ids:selected_ids.erase(id)
   elif selected_ids.size()<5:selected_ids.append(id)
   render_deploy(index))
  modal_body.add_child(b)
 var count=selected_ids.size()
 var start=button("出战 %d / 5 人  →"%count,func():begin_battle(index),true)
 start.disabled=count==0
 modal_body.add_child(start)
 modal_body.add_child(button("暂不交战",close_modal))

func begin_battle(index: int):
 var b=campaign.make_battle(selected_ids,index)
 if b==null:return
 battle=b
 camera_zoom=16.5
 resolved=false
 battle_mode="move"
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
 var accepted=false
 match action:
  "move":accepted=battle.move_to(target)
  "attack":accepted=battle.attack(target)
  "skill":accepted=battle.cast(target)
  "rest_hp":accepted=battle.rest("hp")
  "rest_mp":accepted=battle.rest("mp")
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
 presentation.start(self,before,battle.actors.duplicate(true),actor_id,action,path)
 # Keep the old HUD values until the visible action lands; prevent every button callback.
 for node in footer.find_children("*","Button",true,false):node.disabled=true
 for node in sidebar.find_children("*","Button",true,false):node.disabled=true
 return true

func after_battle_action():
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
 campaign=Campaign.new()
 campaign.save_game()
 close_modal()
 battle=null
 draw_world()
 refresh_ui()

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
 if is_instance_valid(modal) or presentation.busy:return
 if event is InputEventKey and event.pressed:
  if event.keycode==KEY_Q:camera_angle-=0.15;update_camera()
  if event.keycode==KEY_E:camera_angle+=0.15;update_camera()
 if event is InputEventMouseButton and event.pressed:
  if event.button_index==MOUSE_BUTTON_WHEEL_UP:
   camera_zoom=clampf(camera_zoom-1,11,36);update_camera();return
  if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
   camera_zoom=clampf(camera_zoom+1,11,36);update_camera();return
  if event.button_index!=MOUSE_BUTTON_LEFT:return
  var p=ground_position(event.position)
  if battle==null:
   if campaign.phase!="world":return
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
   if battle_mode in ["attack","skill"]:
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
   elif not target.is_empty():
    if battle_mode=="attack":accepted=perform_battle_action("attack",target.id)
    else:accepted=perform_battle_action("skill",target.id)
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
 if battle==null and campaign.phase=="world" and world_party!=null and not is_instance_valid(modal):
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
 if capture_mode=="--capture-shrink":filename="shrink"
 if capture_mode=="--capture-tide":filename="tide"
 var path="res://artifacts/"+filename+".png"
 image.save_png(path)
 print("CAPTURE_READY ",ProjectSettings.globalize_path(path))
 get_tree().quit()
