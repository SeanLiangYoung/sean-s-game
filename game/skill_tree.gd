extends VBoxContainer
# Profession definitions own the graph; selection is presentation state only.
const Jobs=preload("res://game/professions.gd")
var host
var unit: Dictionary
var profession: String
var selected: String
var content: VBoxContainer

class SkillGlyph extends Control:
 var kind: String
 var tint: Color
 func _draw():
  var c=size/2
  draw_circle(c,21,Color(tint,0.10))
  draw_arc(c,21,0,TAU,40,Color(tint,0.45),1.0,true)
  match kind:
   "heal":
    draw_line(c+Vector2(-11,0),c+Vector2(11,0),tint,5,true)
    draw_line(c+Vector2(0,-11),c+Vector2(0,11),tint,5,true)
   "guard","cleanse":
    draw_polyline(PackedVector2Array([c+Vector2(-11,-12),c+Vector2(11,-12),c+Vector2(10,4),c+Vector2(0,14),c+Vector2(-10,4),c+Vector2(-11,-12)]),tint,2,true)
    draw_line(c+Vector2(0,-7),c+Vector2(0,7),tint,2,true)
   "mark","sniper":
    draw_arc(c,11,0,TAU,32,tint,2,true)
    draw_circle(c,3,tint)
    for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:draw_line(c+direction*8,c+direction*16,tint,2,true)
   "trap","bomb":
    draw_colored_polygon(PackedVector2Array([c+Vector2(0,-15),c+Vector2(13,0),c+Vector2(0,15),c+Vector2(-13,0)]),Color(tint,0.25))
    draw_arc(c,10,0,TAU,6,tint,2,true)
    draw_circle(c,4,tint)
   _:
    draw_colored_polygon(PackedVector2Array([c+Vector2(11,-15),c+Vector2(7,-2),c+Vector2(-3,7),c+Vector2(-7,3),c+Vector2(2,-8)]),tint)
    draw_line(c+Vector2(-11,0),c+Vector2(0,11),tint,3,true)
    draw_line(c+Vector2(-5,6),c+Vector2(-12,13),tint,3,true)

class TreeCanvas extends Control:
 var nodes: Array=[]
 var sources: Array=[]
 var unlocked=false
 var gold: Color
 var muted: Color
 func _ready():
  resized.connect(arrange)
  arrange()
 func arrange():
  if nodes.size()<3:return
  var w=124.0
  nodes[0].position=Vector2((size.x-w)/2,8)
  nodes[1].position=Vector2(size.x*0.25-w/2,136)
  nodes[2].position=Vector2(size.x*0.75-w/2,136)
  for i in range(3,nodes.size()):nodes[i].position=Vector2((i-3)*(size.x-w)/2,264)
  for node in nodes:node.size=Vector2(w,96)
  queue_redraw()
 func _draw():
  if nodes.size()<3:return
  var color=gold if unlocked else muted
  for i in range(1,nodes.size()):
   var source=sources[i]
   var start=nodes[source].position+Vector2(62,96)
   var end=nodes[i].position+Vector2(62,0)
   var middle=(start.y+end.y)/2
   draw_polyline(PackedVector2Array([start,Vector2(start.x,middle),Vector2(end.x,middle),end]),color,2,true)
   draw_colored_polygon(PackedVector2Array([end,end+Vector2(-4,-7),end+Vector2(4,-7)]),color)

func setup(owner_host,character: Dictionary):
 host=owner_host
 unit=character
 name="ProfessionSkillTree"
 size_flags_horizontal=Control.SIZE_EXPAND_FILL
 add_theme_constant_override("separation",10)
 var state=host.get_meta("skill_tree_selection",{})
 var saved=state.get(unit.id,{})
 profession=saved.get("profession",unit.profession) if unit.profession=="hero" else unit.profession
 if not Jobs.JOBS.has(profession):profession=unit.profession
 selected=saved.get("skill",Jobs.JOBS[profession].skills[0])
 if selected not in Jobs.JOBS[profession].skills:selected=Jobs.JOBS[profession].skills[0]
 content=VBoxContainer.new()
 content.add_theme_constant_override("separation",10)
 add_child(content)
 rebuild()

func remember():
 var state=host.get_meta("skill_tree_selection",{})
 state[unit.id]={"profession":profession,"skill":selected}
 host.set_meta("skill_tree_selection",state)

func rebuild():
 for child in content.get_children():
  content.remove_child(child)
  child.queue_free()
 if unit.profession=="hero":
  var tabs=HFlowContainer.new()
  tabs.add_theme_constant_override("h_separation",6)
  content.add_child(tabs)
  for job_id in Jobs.JOBS:
   var id=job_id
   var tab=host.button(Jobs.JOBS[id].name,func():
    profession=id;selected=Jobs.JOBS[id].skills[0];remember();rebuild(),id==profession)
   tab.name="SkillProfession_"+id
   tab.add_theme_font_size_override("font_size",15)
   tabs.add_child(tab)
 var columns=HBoxContainer.new()
 columns.add_theme_constant_override("separation",12)
 content.add_child(columns)
 var tree_panel=PanelContainer.new()
 tree_panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 tree_panel.size_flags_stretch_ratio=1.2
 tree_panel.add_theme_stylebox_override("panel",host.style(Color("101d25"),Color("34484e"),8))
 columns.add_child(tree_panel)
 var tree_body=VBoxContainer.new()
 tree_panel.add_child(tree_body)
 tree_body.add_child(host.text_label(Jobs.JOBS[profession].name+" · 技能树",18,host.GOLD))
 var canvas=TreeCanvas.new()
 canvas.name="SkillTreeCanvas"
 canvas.custom_minimum_size=Vector2(408,368)
 canvas.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 canvas.gold=host.TEAL
 canvas.muted=Color("40525a")
 canvas.unlocked=Jobs.skill_rank(unit,Jobs.JOBS[profession].skills[0])>=2
 tree_body.add_child(canvas)
 for skill_id in Jobs.JOBS[profession].skills:
  var id=skill_id
  var skill=Jobs.ALL_SKILLS[id]
  var rank=Jobs.skill_rank(unit,id)
  var root=Jobs.prerequisite(id)
  var available=root=="" or Jobs.skill_rank(unit,root)>=2
  var tint=host.TEAL if rank>0 else (host.GOLD if available else host.MUTED)
  var node=host.button("",func():selected=id;remember();rebuild())
  node.name="SkillNode_"+id
  node.tooltip_text=skill.name+" · "+Jobs.rank_description(unit,id,maxi(1,rank))
  node.add_theme_stylebox_override("normal",host.style(Color("273b40") if id==selected else Color("192a32"),host.GOLD if id==selected else tint.darkened(0.35),8))
  canvas.add_child(node)
  canvas.nodes.append(node)
  canvas.sources.append(maxi(0,Jobs.JOBS[profession].skills.find(root)))
  var body=VBoxContainer.new()
  body.mouse_filter=Control.MOUSE_FILTER_IGNORE
  body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  body.offset_top=6;body.offset_bottom=-6
  body.add_theme_constant_override("separation",2)
  node.add_child(body)
  var icon=SkillGlyph.new()
  icon.kind=skill.get("base",id)
  icon.tint=tint
  icon.custom_minimum_size.y=40
  icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
  body.add_child(icon)
  for entry in [[skill.name,16,tint],["%d / 3级"%rank if rank>0 else ("可解锁" if available else "未解锁"),14,tint]]:
   var label=host.text_label(entry[0],entry[1],entry[2])
   label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
   label.mouse_filter=Control.MOUSE_FILTER_IGNORE
   body.add_child(label)
 tree_body.add_child(host.text_label("基础2级 → 进阶；对应进阶2级 → 深层技能",13,host.MUTED))
 var inspector=PanelContainer.new()
 inspector.name="SelectedSkillDetails"
 inspector.custom_minimum_size.x=240
 inspector.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 inspector.add_theme_stylebox_override("panel",host.style(Color("1a2930"),Color("455954"),8))
 columns.add_child(inspector)
 var details=VBoxContainer.new()
 details.add_theme_constant_override("separation",10)
 inspector.add_child(details)
 show_details(details)

func show_details(parent: Control):
 var skill=Jobs.ALL_SKILLS[selected]
 var rank=Jobs.skill_rank(unit,selected)
 var root=Jobs.prerequisite(selected)
 parent.add_child(host.text_label("基础技能" if root=="" else ("深层技能" if skill.has("prerequisite") else "进阶技能"),14,host.MUTED))
 parent.add_child(host.text_label(skill.name,24,host.GOLD))
 parent.add_child(host.text_label("未解锁" if rank==0 else "%d / 3级"%rank,17,host.TEAL if rank>0 else host.MUTED))
 var rules=host.battle if host.battle!=null else preload("res://game/rules.gd").new()
 parent.add_child(host.text_label("%d行动点 · %d法力 · 射程%d"%[skill.ap,rules.skill_mana_cost(unit,selected),rules.skill_range(unit,selected)],14,host.MUTED))
 var character=preload("res://game/characters.gd").definition(unit)
 if not character.is_empty():parent.add_child(host.text_label("专属天赋 · "+character.talent+"："+character.effect,14,host.TEAL))
 host.separator(parent)
 if rank>0:parent.add_child(host.text_label("当前："+Jobs.rank_description(unit,selected),15))
 if rank<3:parent.add_child(host.text_label(("解锁效果：" if rank==0 else "下一级：")+Jobs.rank_description(unit,selected,rank+1),15,host.TEAL))
 if root!="":parent.add_child(host.text_label("前置："+Jobs.ALL_SKILLS[root].name+" 2级",14,host.MUTED))
 var spacer=Control.new()
 spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL
 parent.add_child(spacer)
 var reason=Jobs.training_reason(unit,selected)
 if host.battle!=null or host.campaign.phase not in ["camp","world"]:reason="当前阶段无法加点"
 elif unit.hp<=0:reason="已阵亡，无法加点"
 if reason!="":parent.add_child(host.text_label(reason,14,host.GOLD if rank<3 else host.TEAL))
 var caption=("解锁" if rank==0 else "强化")+skill.name+" · %d经验"%Jobs.skill_cost(unit,selected)
 if rank>=3:caption="已满级"
 var id=selected
 var train=host.button(caption,func():
  if host.campaign.train_skill(unit.id,id):
   remember();host.refresh_ui();host.show_party_menu("技能",unit.id),reason=="")
 train.add_theme_font_size_override("font_size",15)
 train.disabled=reason!=""
 parent.add_child(train)
