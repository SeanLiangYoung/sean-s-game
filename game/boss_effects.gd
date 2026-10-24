extends RefCounted
# Cue-local visual state lives under CombatPresentation and disappears with its cleanup.
const Visual=preload("res://game/character_visual.gd")
const Regions=preload("res://game/regions.gd")
static func begin(p,cues: Array):
 for cue in cues:
  var actor=p.pawn_for(str(cue.get("source","")))
  if is_instance_valid(actor):
   Visual.play(actor,"prepare_skill" if cue.get("type","")=="charge" else "skill")
   var body=actor.get_node_or_null("Body")
   if body!=null:
    for previous in p.get_children():
     if previous.get_meta("boss_weight_shift",false) and previous.get_meta("body",null)==body:
      body.position=previous.get_meta("origin");body.rotation=previous.get_meta("rotation")
      p.remove_child(previous);previous.queue_free()
    var state=Node3D.new();state.name="BossWeightShift";p.add_child(state)
    state.set_meta("boss_weight_shift",true)
    state.set_meta("body",body);state.set_meta("origin",body.position);state.set_meta("rotation",body.rotation)
  if cue.get("type","")=="charge":spawn(p,cue,true)
static func impact(p,cues: Array):
 for cue in cues:
  var actor=p.pawn_for(str(cue.get("source","")))
  if is_instance_valid(actor):Visual.play(actor,"hit" if cue.get("type","")=="interrupt" else "skill")
  spawn(p,cue,false)
static func spawn(p,cue: Dictionary,windup: bool):
 var biome=str(cue.get("biome","border"))
 var color=Color(Regions.definition(biome).accent)
 var cue_type=str(cue.get("type","release"))
 if cue_type=="interrupt":color=Color("fff1c7")
 var cells=cue.get("cells",[])
 var positions: Array=[]
 for cell in cells:
  if cell is Vector2i:positions.append(p.host.cell_position(cell))
 if positions.is_empty():
  var actor=p.pawn_for(str(cue.get("source","")))
  if is_instance_valid(actor):positions.append(actor.position)
 for pos in positions:
  var root=Node3D.new();root.name="BossCue_"+biome+"_"+cue_type;p.add_child(root);root.position=pos
  root.set_meta("boss_effect",true);root.set_meta("age",0.0);root.set_meta("windup",windup)
  root.set_meta("biome",biome);root.set_meta("cue_type",cue_type)
  root.set_meta("lifetime",1.15 if windup else 0.75)
  var art=p.host.art
  var radius=0.40 if windup else (0.80 if int(cue.get("phase",1))==2 else 0.60)
  art.ring(root,Vector3(0,0.06,0),radius,color,0.045,32)
  if cue_type=="phase":art.ring(root,Vector3(0,0.12,0),radius*1.25,color,0.07,32)
  for i in (3 if windup else 7):
   var angle=TAU*i/(3.0 if windup else 7.0)
   var point=Vector3(cos(angle)*radius,0.12,sin(angle)*radius)
   match biome:
    "border":
     var bar=art.box(root,point,Vector3(0.08,0.65,0.16),color);bar.rotation.y=-angle
    "wood":art.rod(root,point,point+Vector3(cos(angle)*0.2,0.65,sin(angle)*0.2),0.055,color)
    "waste":
     var blade=art.cone(root,point,0.18,0,0.55,color,3);blade.rotation.z=0.85
    "frost":art.cone(root,point,0.14,0,0.85,color,4)
    "marsh":art.ball(root,point+Vector3(0,0.2+(i%3)*0.1,0),Vector3(0.22,0.22,0.22),color)
    "ruins":
     var ring=art.ring(root,point+Vector3(0,0.35,0),0.17,color,0.04,6);ring.rotation.x=PI/2
   if cue_type=="interrupt":art.rod(root,point,point*1.5+Vector3.UP*0.3,0.025,color)
  for mesh in root.find_children("*","MeshInstance3D",true,false):
   var mat=StandardMaterial3D.new();mat.albedo_color=Color(color,0.6 if windup else 0.9)
   mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
   mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mesh.material_override=mat
static func advance(p,_cues: Array,_clock: float,delta: float):
 for root in p.get_children():
  if root.get_meta("boss_weight_shift",false):
   var body=root.get_meta("body",null)
   var age=float(root.get_meta("age",0.0))+delta;root.set_meta("age",age)
   if is_instance_valid(body):
    var strength=sin(clampf(age/1.0,0,1)*PI)
    body.position=root.get_meta("origin")+Vector3(0,-0.06*strength,-0.10*strength)
    body.rotation=root.get_meta("rotation")+Vector3(-0.12*strength,0,0)
   if age>=1.0:root.queue_free()
   continue
  if not root.get_meta("boss_effect",false):continue
  var age=float(root.get_meta("age"))+delta;root.set_meta("age",age)
  var progress=clampf(age/float(root.get_meta("lifetime")),0,1)
  root.rotation.y+=delta*(0.7 if root.get_meta("windup") else 1.8)
  root.scale=Vector3.ONE*(1+progress*(0.12 if root.get_meta("windup") else 0.65))
  for mesh in root.find_children("*","MeshInstance3D",true,false):mesh.material_override.albedo_color.a=(1-progress)*0.85
  if progress>=1:root.queue_free()
