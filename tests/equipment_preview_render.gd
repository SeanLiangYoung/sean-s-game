extends SceneTree
var checks=0
var failures=0
var preview
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func _initialize():call_deferred("run")
func snapshot() -> Image:
 for i in 6:await process_frame
 await RenderingServer.frame_post_draw
 return preview.viewport.get_texture().get_image()
func changed(a: Image,b: Image) -> float:
 var count=0
 for y in range(0,a.get_height(),3):
  for x in range(0,a.get_width(),3):
   var ca=a.get_pixel(x,y);var cb=b.get_pixel(x,y)
   if absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b)>0.15:count+=1
 return float(count)/(ceil(a.get_width()/3.0)*ceil(a.get_height()/3.0))
func run():
 preview=load("res://game/equipment_preview.gd").new();preview.size=Vector2(300,620);root.add_child(preview)
 var profile={"appearance":"hero","mainhand":"sword","offhand":"shield","armor":"plate"}
 preview.show_character("hero",profile)
 var front=await snapshot()
 check(not front.is_empty(),"native preview renders")
 preview.yaw=2.5;preview.update_camera()
 var back=await snapshot()
 check(changed(front,back)>0.05,"rotation visibly shows another side")
 preview.yaw=preview.DEFAULT_YAW;preview.zoom=1.0;preview.update_camera()
 var close=await snapshot()
 check(changed(front,close)>0.06,"zoom visibly enlarges model")
 preview.reset_view()
 profile.mainhand="bow";preview.show_character("hero",profile)
 var bow=await snapshot()
 check(changed(front,bow)>0.01,"loadout visibly updates preview")
 var fits=true
 for yaw in [0.0,PI/2,PI,3*PI/2]:
  preview.yaw=yaw;preview.update_camera();await snapshot()
  for mesh in preview.pawn.find_child("EquippedMainhand",true,false).find_children("*","MeshInstance3D",true,false):
   var bounds=mesh.get_aabb()
   for i in 8:
    var point=mesh.global_transform*bounds.get_endpoint(i)
    var pixel=preview.camera.unproject_position(point)
    if pixel.x<0 or pixel.y<0 or pixel.x>preview.viewport.size.x or pixel.y>preview.viewport.size.y:fits=false
 check(fits,"reset full-body view fits wide weapon from all sides in tall preview")
 preview.queue_free();await process_frame
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
