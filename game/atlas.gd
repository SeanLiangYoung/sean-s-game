extends Control
var route
var route_mode=false
func _draw():
 var scale_to=size/Vector2(1440,900)
 draw_set_transform(Vector2.ZERO,0,scale_to)
 draw_rect(Rect2(0,0,1440,900),Color("172d35"))
 var random=RandomNumberGenerator.new()
 random.seed=91279
 var land=PackedVector2Array()
 for i in range(100):
  var a=TAU*i/100.0
  var r=1.0+0.09*sin(a*7)+0.05*cos(a*13)
  land.append(Vector2(660,450)+Vector2(cos(a)*580,sin(a)*365)*r)
 draw_colored_polygon(land,Color("958c62") if route_mode else Color("728367"))
 var coast=land.duplicate()
 coast.append(land[0])
 draw_polyline(coast,Color("b8ad80"),5,true)
 for i in range(900):
  var p=Vector2(random.randf_range(100,1200),random.randf_range(95,810))
  if not Geometry2D.is_point_in_polygon(p,land):continue
  if p.x>800 and p.y>470:
   draw_circle(p,random.randf_range(2,9),Color(0.64,0.48,0.30,0.3))
  elif p.x>470 and p.y<450:
   draw_circle(p,random.randf_range(3,10),Color(0.16,0.30,0.23,0.38))
  else:draw_line(p,p+Vector2(8,-3),Color(0.8,0.78,0.55,0.14),2)
 for i in range(27):
  var p=Vector2(190+i*17,235+sin(i*0.3)*65)
  draw_colored_polygon(PackedVector2Array([p+Vector2(-15,14),p+Vector2(0,-27),p+Vector2(18,14)]),Color("57645b"))
  draw_line(p+Vector2(0,-27),p+Vector2(7,-9),Color("c2c3a0"),3)
 var river=PackedVector2Array()
 for i in range(70):river.append(Vector2(660+sin(i*0.09)*85,240+i*8))
 draw_polyline(river,Color("416e78"),12,true)
 draw_polyline(river,Color("739b9c"),3,true)
 if route_mode and route!=null:
  var shown=route.visible_nodes()
  for n in shown:
   for other in shown:
    if other.depth==n.depth+1:draw_line(node_position(n),node_position(other),Color(0.90,0.83,0.61,0.55),3,true)
  for n in shown:
   var color=Color("ecd99e") if n.id in route.available() else Color("7c826b")
   if n.id==route.current:color=Color("e6a363")
   draw_circle(node_position(n),32,color)
   draw_arc(node_position(n),36,0,TAU,48,Color("263c37"),3,true)
 draw_rect(Rect2(22,22,1396,856),Color("c1ac78"),false,2)
func node_position(n: Dictionary) -> Vector2:
 return Vector2(260+n.depth*195,420+(n.lane*2-1)*115)
