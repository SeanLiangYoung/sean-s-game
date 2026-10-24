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
var release_time=0.12
var released=false
var release_count=0
var charge_root: Node3D
var charge_ring: MeshInstance3D
var host
var before: Array=[]
var after: Array=[]
var source_id=""
var mode=""
var style="slash"
var path: Array=[]
var projectile: MeshInstance3D
var projectile_target=Vector3.ZERO
var source: Node3D
var start_pos=Vector3.ZERO
var floats: Array=[]
var rings: Array=[]
var effects: Array=[]

func start(owner_node,before_state: Array,after_state: Array,actor_id: String,action: String,move_path: Array=[],target_id: String=""):
 host=owner_node
 before=before_state
 after=after_state
 source_id=actor_id
 mode=action
 path=move_path
 busy=true
 clock=0
 impact_count=0
 released=false
 release_count=0
 move_duration=maxf(0.55,path.size()*0.22)
 var consequences=false
 for unit in after:
  var old=find_unit(before,unit.id)
  if not old.is_empty() and unit.hp<old.hp:consequences=true
 duration=move_duration+(1.0 if consequences else 0.0) if mode=="move" else (1.5 if mode.begins_with("rest") else 1.2)
 release_time=0.62 if mode=="skill" else 0.12
 impact_time=move_duration if mode=="move" else (0.98 if mode=="skill" else 0.4)
 if mode=="skill":duration=impact_time+0.70
 for unit in after:
  var old=find_unit(before,unit.id)
  if not old.is_empty() and old.hp>0 and unit.hp<=0:duration=maxf(duration,impact_time+1.25)
 source=pawn_for(source_id)
 if source!=null:
  start_pos=source.position
  style=Visual.effect_style(source,action)
  Visual.play(source,"prepare_skill" if mode=="skill" else mode)
  if mode=="skill":begin_charge()
  for u in after:
   var prior=find_unit(before,u.id)
   var chosen=u.id==target_id if target_id!="" else (u.id!=source_id and (u.hp!=prior.get("hp",u.hp) or u.mp!=prior.get("mp",u.mp)))
   if not prior.is_empty() and chosen:
    face(source,host.cell_position(prior.cell))
    if action=="skill" or (action=="attack" and style in ["arrow","magic"]):
     projectile_target=host.cell_position(prior.cell)+Vector3(0,0.8,0)
     projectile=make_projectile(start_pos+Vector3(0,0.85,0),projectile_target,style)
     projectile.visible=false
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
  pawn.get_node("Body").rotation.y=atan2(direction.x,direction.z)+pawn.get_meta("forward_offset",0.0)

func advance(delta: float):
 if not busy:return
 clock+=delta
 if not released and clock>=release_time:
  released=true
  release_count+=1
  if mode=="skill" and source!=null:Visual.play(source,"skill")
  if is_instance_valid(charge_root):charge_root.visible=false
  if is_instance_valid(charge_ring):charge_ring.visible=false
 if is_instance_valid(charge_root) and not released:
  var intensity=clampf(clock/release_time,0,1)
  if is_instance_valid(charge_ring):charge_ring.scale=Vector3.ONE*(1+intensity*0.3)
  for i in range(charge_root.get_child_count()):
   var orb=charge_root.get_child(i)
   var angle=TAU*i/charge_root.get_child_count()+clock*4.0
   var radius=lerpf(0.47,0.16,intensity)
   orb.position=Vector3(cos(angle)*radius,sin(angle*1.7)*0.12,sin(angle)*radius)
   orb.scale=Vector3.ONE*(0.5+intensity*0.5)
 if is_instance_valid(projectile):
  var t=clampf((clock-release_time)/maxf(0.01,impact_time-release_time),0,1)
  projectile.position=(start_pos+Vector3(0,0.85,0)).lerp(projectile_target,t)+Vector3.UP*sin(t*PI)*0.3
  projectile.visible=released and clock<impact_time
 if mode=="move" and source!=null and not path.is_empty():
  var progress=clampf(clock/move_duration,0,1)*path.size()
  var index=mini(int(progress),path.size()-1)
  var a=start_pos if index==0 else host.cell_position(path[index-1])
  var b=host.cell_position(path[index])
  source.position=a.lerp(b,clampf(progress-index,0,1))
  face(source,b)
 elif source!=null and mode.begins_with("rest"):
  var body=source.get_node("Body")
  var settle=sin(clampf(clock/duration,0,1)*PI)
  body.position.y=-0.08*settle
  body.rotation.x=-0.10*settle
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
  elif entry.kind=="slash":
   n.scale=Vector3.ONE*(1+age*1.3)
   n.material_override.albedo_color.a=clampf(1-age/0.45,0,1)
  elif entry.kind=="orb":n.position=entry.origin+Vector3(sin(age*5+entry.phase)*0.16,age*0.9,cos(age*5+entry.phase)*0.16)
 if clock>=duration:
  busy=false
  for child in get_children():remove_child(child);child.queue_free()
  floats.clear();rings.clear();effects.clear()
  projectile=null
  charge_root=null
  charge_ring=null
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
   if style=="slash":
    var slash=make_projectile(pos+Vector3(0,0.85,0),start_pos+Vector3(0,0.85,0),"slash")
    effects.append({"node":slash,"kind":"slash","origin":slash.position})
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


func make_projectile(pos: Vector3,target: Vector3,effect: String) -> MeshInstance3D:
 var color={"arrow":Color("ffe6aa"),"heal":Color("8cf0bd"),"magic":Color("b9d7ff"),"slash":Color("ffe0a0")}.get(effect,Color.WHITE)
 var n=glow(pos,color,0.09)
 n.set_meta("effect_style",effect)
 if effect=="arrow":
  var shaft=BoxMesh.new()
  shaft.size=Vector3(0.035,0.035,0.6)
  n.mesh=shaft
  if pos.distance_squared_to(target)>0.001:n.look_at(target)
 elif effect=="slash":
  var vertices=PackedVector3Array()
  var normals=PackedVector3Array()
  for i in range(20):
   var a=-1.3+2.6*i/20.0
   var b=-1.3+2.6*(i+1)/20.0
   var outer_a=Vector3(cos(a)*0.55,sin(a)*0.55,0)
   var outer_b=Vector3(cos(b)*0.55,sin(b)*0.55,0)
   var inner_a=outer_a*(1-0.25*sin(PI*i/20.0))
   var inner_b=outer_b*(1-0.25*sin(PI*(i+1)/20.0))
   for vertex in [outer_a,inner_a,outer_b,outer_b,inner_a,inner_b]:
    vertices.append(vertex)
    normals.append(Vector3.FORWARD)
  var arrays=[]
  arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX]=vertices
  arrays[Mesh.ARRAY_NORMAL]=normals
  var geometry=ArrayMesh.new()
  geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  n.mesh=geometry
  n.material_override.cull_mode=BaseMaterial3D.CULL_DISABLED
  n.material_override.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
  if pos.distance_squared_to(target)>0.001:n.look_at(target)
 return n


func begin_charge():
 charge_root=Node3D.new()
 charge_root.name="SkillCharge"
 add_child(charge_root)
 charge_root.position=start_pos+Vector3(0,0.88,0)
 var color=Color("a9dec4") if style=="heal" else (Color("ddc795") if style in ["arrow","slash"] else Color("a3cbd5"))
 charge_ring=host.art.ring(self,start_pos+Vector3(0,0.04,0),0.34,Color(color,0.65),0.025,48)
 charge_ring.material_override.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 for i in range(7):
  var orb=glow(Vector3.ZERO,color,0.04)
  orb.reparent(charge_root,false)
