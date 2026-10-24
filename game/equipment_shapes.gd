extends RefCounted
# Small reusable surface builders; coordinates remain in the wearer's rest space.
static func mesh_node(parent: Node3D,st: SurfaceTool,mat: Material,name: String) -> MeshInstance3D:
 st.generate_normals()
 var node=MeshInstance3D.new();node.name=name;node.mesh=st.commit();node.material_override=mat;parent.add_child(node)
 return node

static func triangle(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3):
 # Godot front faces use clockwise winding. Callers describe outward right-handed faces.
 st.add_vertex(a);st.add_vertex(c);st.add_vertex(b)

static func quad(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3):
 triangle(st,a,b,c);triangle(st,a,c,d)

# Horizontal elliptical rings: y, half-width, half-depth, depth offset.
static func shell(parent: Node3D,rows: Array,mat: Material,name: String,segments: int=24,from_angle: float=-PI,to_angle: float=PI) -> MeshInstance3D:
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in range(rows.size()-1):
  var a=rows[row];var b=rows[row+1]
  for i in segments:
   var u=lerpf(from_angle,to_angle,float(i)/segments);var v=lerpf(from_angle,to_angle,float(i+1)/segments)
   quad(st,Vector3(sin(u)*a.y,a.x,cos(u)*a.z+a.w),Vector3(sin(v)*a.y,a.x,cos(v)*a.z+a.w),Vector3(sin(v)*b.y,b.x,cos(v)*b.z+b.w),Vector3(sin(u)*b.y,b.x,cos(u)*b.z+b.w))
 return mesh_node(parent,st,mat,name)

static func tube(parent: Node3D,points: Array,radius: float,mat: Material,name: String,sides: int=8) -> MeshInstance3D:
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var rings=[]
 for i in points.size():
  var tangent=(points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]).normalized()
  var reference=Vector3.UP if absf(tangent.dot(Vector3.UP))<0.9 else Vector3.RIGHT
  var x=tangent.cross(reference).normalized();var y=tangent.cross(x).normalized()
  var ring=[]
  for j in sides:ring.append(points[i]+radius*(x*cos(TAU*j/sides)+y*sin(TAU*j/sides)))
  rings.append(ring)
 for i in range(rings.size()-1):
  for j in sides:
   var k=(j+1)%sides
   quad(st,rings[i][j],rings[i][k],rings[i+1][k],rings[i+1][j])
 for j in range(1,sides-1):
  triangle(st,rings[0][0],rings[0][j+1],rings[0][j])
  triangle(st,rings[-1][0],rings[-1][j],rings[-1][j+1])
 return mesh_node(parent,st,mat,name)

# Outline is a clockwise x/y polygon seen from the front; bevel is a smaller raised face.
static func bevel_panel(parent: Node3D,outline: Array,front: float,back: float,bevel: float,mat: Material,name: String) -> MeshInstance3D:
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 outline=outline.duplicate()
 var area=0.0
 for i in outline.size():area+=outline[i].cross(outline[(i+1)%outline.size()])
 if area<0:outline.reverse()
 var center=Vector2.ZERO
 for p in outline:center+=p
 center/=outline.size()
 for i in outline.size():
  var j=(i+1)%outline.size()
  var a=outline[i];var b=outline[j]
  var inner_a=a.lerp(center,bevel);var inner_b=b.lerp(center,bevel)
  quad(st,Vector3(a.x,a.y,back),Vector3(b.x,b.y,back),Vector3(b.x,b.y,front-0.025),Vector3(a.x,a.y,front-0.025))
  quad(st,Vector3(a.x,a.y,front-0.025),Vector3(b.x,b.y,front-0.025),Vector3(inner_b.x,inner_b.y,front),Vector3(inner_a.x,inner_a.y,front))
  triangle(st,Vector3(inner_a.x,inner_a.y,front),Vector3(inner_b.x,inner_b.y,front),Vector3(center.x,center.y,front))
  triangle(st,Vector3(b.x,b.y,back),Vector3(a.x,a.y,back),Vector3(center.x,center.y,back))
 return mesh_node(parent,st,mat,name)

# A blade with a raised central ridge and thin cutting edges.
static func blade(parent: Node3D,rows: Array,mat: Material,name: String) -> MeshInstance3D:
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(rows.size()-1):
  var a=rows[i];var b=rows[i+1]
  for side in [-1,1]:
   var za=a.z*side;var zb=b.z*side
   var points=[Vector3(-a.y,a.x,0),Vector3(0,a.x,za),Vector3(a.y,a.x,0)]
   var next=[Vector3(-b.y,b.x,0),Vector3(0,b.x,zb),Vector3(b.y,b.x,0)]
   for j in 2:
    if side>0:quad(st,points[j],points[j+1],next[j+1],next[j])
    else:quad(st,points[j+1],points[j],next[j],next[j+1])
 return mesh_node(parent,st,mat,name)
