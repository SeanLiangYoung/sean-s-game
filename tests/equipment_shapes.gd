extends SceneTree
const Shapes=preload("res://game/equipment_shapes.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func _initialize():
 var holder=Node3D.new()
 var mat=StandardMaterial3D.new()
 var shell=Shapes.shell(holder,[Vector4(0,0.5,0.3,0),Vector4(1,0.4,0.3,0)],mat,"shell")
 var arrays=shell.mesh.surface_get_arrays(0)
 var outside=true
 for i in arrays[Mesh.ARRAY_VERTEX].size():
  var p=arrays[Mesh.ARRAY_VERTEX][i]
  if arrays[Mesh.ARRAY_NORMAL][i].dot(Vector3(p.x,0,p.z))<=0:outside=false
 check(outside,"armor shell normals face outward so chest is not culled")
 var tube=Shapes.tube(holder,[Vector3.ZERO,Vector3.UP],0.1,mat,"tube")
 arrays=tube.mesh.surface_get_arrays(0)
 outside=true
 for i in arrays[Mesh.ARRAY_VERTEX].size():
  var p=arrays[Mesh.ARRAY_VERTEX][i];var n=arrays[Mesh.ARRAY_NORMAL][i]
  if absf(n.y)<0.5 and n.dot(Vector3(p.x,0,p.z))<=0:outside=false
 check(outside,"rim tube normals face outward")
 var blade=Shapes.blade(holder,[Vector3(0,0.1,0.03),Vector3(1,0.05,0.02)],mat,"blade")
 arrays=blade.mesh.surface_get_arrays(0)
 outside=true
 for i in arrays[Mesh.ARRAY_VERTEX].size():
  var p=arrays[Mesh.ARRAY_VERTEX][i];var n=arrays[Mesh.ARRAY_NORMAL][i]
  if absf(p.z)>0.005 and p.z*n.z<=0:outside=false
 check(outside,"blade cutting faces visible from either side")
 holder.free()
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
