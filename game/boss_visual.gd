extends RefCounted
# Ornament coordinates use the imported rig's rest space, so attacks carry the silhouette.
const Equipment=preload("res://game/equipment_visual.gd")
const Regions=preload("res://game/regions.gd")
static func decorate(art,pawn: Node3D,unit: Dictionary) -> Node3D:
 var old=pawn.get_node_or_null("BossInsignia")
 if old!=null:pawn.remove_child(old);old.queue_free()
 var root=Node3D.new();root.name="BossInsignia";pawn.add_child(root)
 var biome=str(unit.get("biome","border"));var phase=int(unit.get("boss_phase",1))
 root.set_meta("biome",biome);root.set_meta("boss_phase",phase)
 var model=pawn.get_node_or_null("Body")
 if model==null:return root
 var skeleton=model.find_child("Skeleton3D",true,false) as Skeleton3D
 if skeleton==null:return root
 for child in skeleton.get_children():
  if child.get_meta("boss_ornament",false):skeleton.remove_child(child);child.queue_free()
 var accent=Color(Regions.definition(biome).accent)
 var head=mount(skeleton,"Head" if skeleton.find_bone("Head")>=0 else "Head_2","Head")
 var torso=mount(skeleton,"Torso","Torso")
 var hand=mount(skeleton,"LowerArm.R","Hand")
 if head==null or torso==null:return root
 var growth=1.35 if phase==2 else 1.0
 match biome:
  "border":
   art.rod(torso,Vector3(-0.35,1.2,-0.3),Vector3(-0.35,3.0,-0.3),0.045,Color("bca777"))
   art.cloth(torso,Vector3(-0.05,2.55,-0.32),0.6*growth,0.85,Color("914d43"))
   for side in [-1,1]:art.cone(head,Vector3(side*0.23,2.45,0),0.09,0,0.40*growth,accent,4)
   art.ball(head,Vector3(0,2.42,0.2),Vector3(0.22,0.25,0.10),accent)
  "wood":
   for side in [-1,1]:
    art.rod(head,Vector3(side*0.18,2.30,0),Vector3(side*0.6*growth,2.95*growth,0),0.09,Color("75664c"))
    for i in 3:
     var start=Vector3(side*(0.30+i*0.09),2.48+i*0.14,0)
     art.rod(head,start,start+Vector3(side*0.24,0.22,0.07)*growth,0.045,accent)
    art.ball(torso,Vector3(side*0.43,1.8,0),Vector3(0.35,0.55,0.4),Color("526845"))
  "waste":
   art.cloth(torso,Vector3(0,1.83,-0.32),0.85*growth,0.5,Color("cf965e"))
   art.ring(head,Vector3(0,2.42,0),0.34*growth,accent,0.065,16).rotation.x=PI/2
   for side in [-1,1]:art.cone(head,Vector3(side*0.3,2.6,0),0.07,0,0.35,accent,4)
   if hand!=null:
    art.rod(hand,Vector3(-0.63,0.6,0.1),Vector3(-0.63,3.25,0.1),0.035,Color("6b5140"))
    art.cone(hand,Vector3(-0.63,3.4,0.1),0.13,0,0.5*growth,accent,4)
  "frost":
   for i in 5:art.cone(head,Vector3((i-2)*0.14,2.43+0.09*(2-absi(i-2)),0),0.10,0,0.45*growth,accent,5)
   for side in [-1,1]:
    for i in 3:art.cone(torso,Vector3(side*(0.38+i*0.12),1.95,0),0.14,0,0.48*growth,Color("b4dce6"),4).rotation.z=-side*0.35
  "marsh":
   art.ball(head,Vector3(0,2.54,0),Vector3(1.25*growth,0.4,0.95*growth),Color("80658c"))
   for i in 6:
    var angle=TAU*i/6
    art.ball(torso,Vector3(cos(angle)*0.43,1.80,sin(angle)*0.32),Vector3(0.22,0.36,0.22),accent)
  "ruins":
   art.ball(torso,Vector3(0,1.68,0.45),Vector3(0.35,0.50,0.28)*growth,accent)
   for i in 3:
    var ring=art.ring(torso,Vector3(0,1.7,0),0.64*growth,accent,0.035,24)
    ring.rotation=Vector3(0.45+i*0.7,0,i*0.8)
 if phase==2:
  for i in 6:
   var angle=TAU*i/6
   var flare=art.cone(torso,Vector3(cos(angle)*0.6,1.9+sin(angle)*0.55,-0.32),0.10,0,0.46,accent,4)
   flare.name="PhaseTwoFlare%d"%i
   var material=Equipment.material(accent.to_html(false),0.2)
   material.emission_enabled=true;material.emission=accent;material.emission_energy_multiplier=1.4
   flare.material_override=material
 return root
static func mount(skeleton: Skeleton3D,bone: String,suffix: String) -> Node3D:
 var attachment=Equipment.mount(skeleton,"BossMount"+suffix,bone)
 if attachment==null:return null
 attachment.set_meta("boss_ornament",true)
 return Equipment.rest_space(skeleton,attachment)
