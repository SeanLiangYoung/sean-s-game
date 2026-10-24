extends SceneTree
const Campaign=preload("res://game/campaign.gd")
var checks=0
var failures=0
var portraits
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func _initialize():call_deferred("run")
func snapshot(profile: Dictionary) -> Image:
 var texture=portraits.portrait("hero",profile)
 for i in 5:await process_frame
 await RenderingServer.frame_post_draw
 return texture.get_image()
func difference(a: Image,b: Image,area: Rect2i=Rect2i(0,0,192,192)) -> float:
 var count=0
 for y in range(area.position.y,area.end.y):
  for x in range(area.position.x,area.end.x):
   var ca=a.get_pixel(x,y);var cb=b.get_pixel(x,y)
   if absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b)>0.08:count+=1
 return float(count)/(area.size.x*area.size.y)
func run():
 portraits=load("res://game/portraits.gd").new();root.add_child(portraits)
 var c=Campaign.new("user://render-appearance-unused.json")
 c.equip_item(0,"hero")
 var sword=await snapshot(c.visual_profile("hero"))
 check(not sword.is_empty(),"native portrait renders")
 c.equip_item(5,"hero")
 var shield=await snapshot(c.visual_profile("hero"))
 check(difference(sword,shield)>0.01,"shield changes visible portrait pixels")
 c.equip_item(7,"hero")
 var plate=await snapshot(c.visual_profile("hero"))
 check(difference(shield,plate)>0.03,"plate changes visible portrait pixels")
 check(difference(shield,plate,Rect2i(74,12,40,40))<0.02,"armor preserves the face and hair")
 c.equip_item(6,"hero")
 var leather=await snapshot(c.visual_profile("hero"))
 check(difference(plate,leather)>0.03,"leather and plate are visually distinct")
 c.unequip_item("hero","armor");c.unequip_item("hero","offhand")
 var restored=await snapshot(c.visual_profile("hero"))
 check(difference(sword,restored)<0.001,"unequip restores original outfit pixels")
 for item in [1,2,3,4]:
  c.equip_item(item,"hero")
  var weapon=await snapshot(c.visual_profile("hero"))
  check(difference(sword,weapon)>0.01,"weapon %d changes visible portrait"%item)
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
