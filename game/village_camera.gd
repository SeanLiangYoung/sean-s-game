extends RefCounted
# Precomposed frames: near daily life, house details and the distant landscape.
const Story=preload("res://game/village_story.gd")
var view="daily"
var tween: Tween
var destination: Dictionary={}
static func pose(id: String) -> Dictionary:
 if Story.HOMES.has(id):
  var d=Story.HOMES[id]
  var offset=Vector3(-6,5.3,10) if id in ["lodger","blade"] else Vector3(6,5.3,10)
  if id=="medic":offset=Vector3(1,5.3,12)
  if id=="engineer":offset=Vector3(10,5.3,8)
  offset=offset.rotated(Vector3.UP,deg_to_rad(float(d.angle)))
  var right=Vector3(offset.z,0,-offset.x).normalized()
  var target=d.pos+Vector3(0,1.4,0)+right*2.05
  return {"position":target+offset,"target":target,"size":7.8}
 if id=="overview":return {"position":Vector3(21,18,36),"target":Vector3(1,2,-3),"size":28.0}
 var target=Vector3(-0.6,1.2,0.3)
 return {"position":target+Vector3(15,15,26),"target":target,"size":19.5}
func is_home() -> bool:
 return Story.HOMES.has(view)
func cancel():
 if tween!=null and tween.is_valid():tween.kill()
 tween=null
func set_view(host,id: String,duration: float=0.65):
 if id not in ["daily","overview"] and not Story.HOMES.has(id):return
 cancel()
 view=id;destination=pose(id)
 var basis=Transform3D.IDENTITY.looking_at(destination.target-destination.position,Vector3.UP).basis
 var end_rotation=basis.get_rotation_quaternion()
 preload("res://game/village_ui.gd").update_overview(host)
 var start_position=host.camera.position;var start_rotation=host.camera.quaternion;var start_size=host.camera.size
 if duration<=0:
  apply(host,destination.position,end_rotation,destination.size)
 else:
  tween=host.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
  tween.tween_method(func(weight):
   if not is_instance_valid(host.camera):return
   apply(host,start_position.lerp(destination.position,weight),start_rotation.slerp(end_rotation,weight),lerpf(start_size,destination.size,weight)),0.0,1.0,duration)
func apply(host,position: Vector3,rotation: Quaternion,size: float):
 host.camera.position=position;host.camera.quaternion=rotation;host.camera.size=size
 if is_instance_valid(host.atlas) and host.atlas.village_mode:
  preload("res://game/village_ui.gd").update_doors(host,host.atlas)
func finish(host):
 if destination.is_empty():return
 set_view(host,view,0)
func restore(host):
 set_view(host,view,0)
