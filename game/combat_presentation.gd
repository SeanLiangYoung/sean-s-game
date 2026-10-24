extends Node3D
# Presentation never changes battle rules. Main owns the authoritative state.
signal completed
const Visual=preload("res://game/character_visual.gd")
var busy=false
var impact_count=0
var clock=0.0
var duration=1.2
var move_duration=0.55
var impact_time=0.4
var host
var before: Array=[]
var after: Array=[]
var source_id=""
var mode=""
var path: Array=[]
var projectile: MeshInstance3D
var projectile_target=Vector3.ZERO
var source: Node3D
var start_pos=Vector3.ZERO
var floats: Array=[]
var rings: Array=[]
var effects: Array=[]

func start(owner_node,before_state: Array,after_state: Array,actor_id: String,action: String,move_path: Array=[]):
 host=owner_node
 before=before_state
 after=after_state
 source_id=actor_id
 mode=action
 path=move_path
 busy=true
 clock=0
 impact_count=0
 move_duration=maxf(0.55,path.size()*0.22)
 var consequences=false
 for unit in after:
  var old=find_unit(before,unit.id)
  if not old.is_empty() and unit.hp<old.hp:consequences=true
 duration=move_duration+(1.0 if consequences else 0.0) if mode=="move" else (1.5 if mode.begins_with("rest") else 1.2)
 impact_time=move_duration if mode=="move" else 0.4
 source=pawn_for(source_id)
 if source!=null:
  start_pos=source.position
  Visual.play(source,mode)
  for u in after:
   var prior=find_unit(before,u.id)
   if not prior.is_empty() and u.id!=source_id and (u.hp!=prior.hp or u.mp!=prior.mp):
    face(source,host.cell_position(prior.cell))
    var role=source.get_meta("role","")
    if action=="skill" or (action=="attack" and role in ["ranger","engineer","medic","enemy2"]):
     projectile=glow(start_pos+Vector3(0,0.85,0),Color("f5cf89") if action=="attack" else Color("c3a2ff"),0.09)
     projectile_target=host.cell_position(prior.cell)+Vector3(0,0.8,0)
    break
 host.status_label.text={"attack":"攻击准备…","skill":"凝聚战技…","rest_hp":"休息 · 恢复生命…","rest_mp":"休息 · 恢复法力…","move":"移动中…"}.get(mode,"行动中…")

func pawn_for(id: String):
 for pawn in host.pawn_nodes:
  if is_instance_valid(pawn) and pawn.name=="Character_"+id:return pawn
 return null

func find_unit(units: Array,id: String) -> Dictionary:
 for u in units:
  if u.id==id:return u
 return {}

func face(pawn: Node3D,target: Vector3):
 var direction=target-pawn.position
 direction.y=0
 if direction.length_squared()>0.001:
  pawn.get_node("Body").rotation.y=atan2(direction.x,direction.z)

func advance(delta: float):
 if not busy:return
 clock+=delta
 if is_instance_valid(projectile):
  var t=clampf((clock-0.12)/maxf(0.01,impact_time-0.12),0,1)
  projectile.position=(start_pos+Vector3(0,0.85,0)).lerp(projectile_target,t)+Vector3.UP*sin(t*PI)*0.3
  projectile.visible=clock>=0.12 and clock<impact_time
 if mode=="move" and source!=null and not path.is_empty():
  var progress=clampf(clock/move_duration,0,1)*path.size()
  var index=mini(int(progress),path.size()-1)
  var a=start_pos if index==0 else host.cell_position(path[index-1])
  var b=host.cell_position(path[index])
  source.position=a.lerp(b,clampf(progress-index,0,1))
  face(source,b)
 elif source!=null and mode=="attack":
  # Small weight shift supports the skeletal strike without crossing occupied cells.
  var body=source.get_node("Body")
  body.position.z=sin(clampf(clock/duration,0,1)*PI)*0.10
 if impact_count==0 and clock>=impact_time:
  impact_count=1
  impact()
 var age=maxf(0,clock-impact_time)
 for entry in floats:
  entry.node.position=entry.origin+Vector3(0,age*0.85,0)
  entry.node.modulate.a=clampf(1-age/1.1,0,1)
 for entry in rings:
  entry.node.scale=Vector3.ONE*(1+age*1.6)
  entry.node.material_override.albedo_color=Color(entry.color,clampf(1-age/1.1,0,1))
 for entry in effects:
  var n=entry.node
  if entry.kind=="spark":n.position=entry.origin+entry.velocity*age+Vector3.DOWN*age*age
  elif entry.kind=="orb":n.position=entry.origin+Vector3(sin(age*5+entry.phase)*0.16,age*0.9,cos(age*5+entry.phase)*0.16)
 if clock>=duration:
  busy=false
  for child in get_children():remove_child(child);child.queue_free()
  floats.clear();rings.clear();effects.clear()
  projectile=null
  completed.emit()

func impact():
 host.status_label.text={"attack":"攻击命中","skill":"战技生效","rest_hp":"休息 · 生命恢复","rest_mp":"休息 · 法力恢复","move":"移动完成"}.get(mode,"行动生效")
 for unit in after:
  var old=find_unit(before,unit.id)
  if old.is_empty():continue
  var hp=unit.hp-old.hp
  var mp=unit.mp-old.mp
  var resting=unit.id==source_id and mode.begins_with("rest")
  var damaged=hp<0
  if hp==0 and mp<=0 and not resting:continue
  var pawn=pawn_for(unit.id)
  var pos=pawn.position if pawn!=null else host.cell_position(old.cell)
  if pawn!=null:
   if damaged:Visual.play(pawn,"death" if unit.hp<=0 else "hit")
   if unit.id!=source_id and damaged:face(pawn,start_pos)
   # Update the existing bar at impact without destroying the skeletal animation.
   var bar=pawn.get_node_or_null("HealthFill")
   if bar!=null:
    var width=0.85*float(unit.hp)/unit.max_hp
    bar.scale.x=maxf(0.01,width/0.85)
    bar.position.x=(width-0.85)/2
  var color=Color("ffb38a") if damaged else (Color("87d7ff") if mode=="rest_mp" else Color("a2f0bc"))
  var text="−%d"%abs(hp) if damaged else ("+%d 法力"%maxi(0,mp) if mode=="rest_mp" else "+%d 生命"%maxi(0,hp))
  if resting and hp==0 and mp==0:text="休息 · 已充盈"
  floating(text,pos+Vector3(0,1.9,0),color)
  pulse(pos,color)
  if damaged:
   sparks(pos+Vector3(0,0.85,0),color)
   if mode=="skill":pulse(pos+Vector3(0,0.04,0),Color("f6d18a"),0.65)
  else:orbs(pos,color)
 if mode=="skill" and source!=null:
  pulse(start_pos,Color("c9b4ff"),0.55)

func floating(text: String,pos: Vector3,color: Color):
 var label=Label3D.new()
 label.text=text
 label.font=host.game_font
 label.font_size=44
 label.pixel_size=0.006
 label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 label.no_depth_test=true
 label.modulate=color
 label.outline_size=8
 label.position=pos
 add_child(label)
 floats.append({"node":label,"origin":pos})

func pulse(pos: Vector3,color: Color,radius: float=0.35):
 var n=host.art.ring(self,pos+Vector3(0,0.09,0),radius,color,0.055,40)
 n.material_override.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 rings.append({"node":n,"color":color})

func glow(pos: Vector3,color: Color,size: float):
 var n=MeshInstance3D.new()
 var mesh=SphereMesh.new()
 mesh.radius=size
 mesh.height=size*2
 mesh.radial_segments=8
 mesh.rings=4
 n.mesh=mesh
 n.position=pos
 var material=StandardMaterial3D.new()
 material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.albedo_color=color
 n.material_override=material
 add_child(n)
 return n

func sparks(pos: Vector3,color: Color):
 for i in range(9):
  var angle=TAU*i/9
  var n=glow(pos,color,0.035)
  effects.append({"node":n,"kind":"spark","origin":pos,"velocity":Vector3(cos(angle),0.8+(i%3)*0.2,sin(angle))*1.3})

func orbs(pos: Vector3,color: Color):
 for i in range(8):
  var p=pos+Vector3(cos(i*2.4)*0.28,0.15+i*0.08,sin(i*2.4)*0.28)
  var n=glow(p,color,0.035)
  effects.append({"node":n,"kind":"orb","origin":p,"phase":i*2.4})
