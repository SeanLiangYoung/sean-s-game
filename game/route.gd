extends RefCounted
const REGIONS=[{"id":"border","name":"灰潮边境","desc":"断桥与古道之间，商旅仍在寻找生路。","pos":Vector2(0.30,0.63)}, {"id":"wood","name":"苍翠林海","desc":"沿林间旧路寻找隐居的佣兵与遗物。","pos":Vector2(0.57,0.39)}, {"id":"waste","name":"赤砂荒原","desc":"穿过荒原商道，深入遗械散落之地。","pos":Vector2(0.77,0.67)}]
var region=""
var current=""
var completed=false
var nodes: Array=[]
var visited: Array=[]
func setup(id: String):
 region=id
 current=""
 visited=[]
 completed=true
 nodes=[]
 var types=[["battle","shop"],["event","hire"],["shop","battle"],["battle","supply"],["extract","extract"]]
 if id=="wood":types=[["event","battle"],["shop","hire"],["battle","supply"],["shop","battle"],["extract","extract"]]
 if id=="waste":types=[["shop","battle"],["hire","event"],["battle","shop"],["supply","battle"],["extract","extract"]]
 var encounter=0
 for depth in range(types.size()):
  for lane in range(2):
   var kind=types[depth][lane]
   nodes.append({"id":"%d%s"%[depth,"a" if lane==0 else "b"],"depth":depth,"lane":lane,"kind":kind,"encounter":mini(encounter,2)})
   if kind=="battle":encounter+=1
func node(id: String) -> Dictionary:
 for n in nodes:
  if n.id==id:return n
 return {}
func available() -> Array:
 if not completed:return []
 var depth=0 if current=="" else int(node(current).depth)+1
 return nodes.filter(func(n):return n.depth==depth).map(func(n):return n.id)
func visible_nodes() -> Array:
 var depth=-1 if current=="" else int(node(current).depth)
 return nodes.filter(func(n):return n.depth<=depth+2 and (n.depth>depth or n.id in visited))
func enter(id: String) -> bool:
 if id not in available():return false
 current=id
 visited.append(id)
 completed=false
 return true
func data() -> Dictionary:
 return {"region":region,"current":current,"completed":completed,"visited":visited.duplicate()}
func restore(saved: Dictionary) -> bool:
 if not saved.get("region","") in REGIONS.map(func(r):return r.id):return false
 setup(saved.region)
 if not saved.get("visited") is Array or not saved.get("completed") is bool:return false
 var previous=-1
 for id in saved.visited:
  if not id is String or node(id).is_empty() or node(id).depth!=previous+1:return false
  previous+=1
 if saved.get("current","")!=("" if saved.visited.is_empty() else saved.visited[-1]):return false
 current=saved.current
 visited=saved.visited.duplicate()
 completed=saved.completed
 return true
