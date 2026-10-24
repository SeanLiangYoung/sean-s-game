extends RefCounted
const Jobs=preload("res://game/professions.gd")
const Relic=preload("res://game/relics.gd")
const REGIONS=[{"id":"border","name":"灰潮边境","desc":"断桥与古道之间，商旅仍在寻找生路。","pos":Vector2(0.30,0.63)}, {"id":"wood","name":"苍翠林海","desc":"沿林间旧路寻找隐居的佣兵与遗物。","pos":Vector2(0.57,0.39)}, {"id":"waste","name":"赤砂荒原","desc":"穿过荒原商道，深入遗械散落之地。","pos":Vector2(0.77,0.67)}, {"id":"frost","name":"霜脊山隘","desc":"寒风中的守卫与坚甲佣兵；准备破甲与治疗。","pos":Vector2(0.32,0.28)}, {"id":"marsh","name":"暮雾沼泽","desc":"雾中猎手善于远射，护盾与控制能创造突破机会。","pos":Vector2(0.47,0.76)}, {"id":"ruins","name":"星陨遗城","desc":"遗械卫士守护城心；机关与法力续航尤为重要。","pos":Vector2(0.73,0.26)}]
var seed_value=-1
var region=""
var current=""
var completed=false
var nodes: Array=[]
var visited: Array=[]
func setup(id: String,route_seed: int=-1):
 seed_value=route_seed
 region=id
 current=""
 visited=[]
 completed=true
 nodes=[]
 if route_seed>=0:
  generate(route_seed)
  return
 var types=[["battle","shop"],["event","hire"],["shop","battle"],["battle","supply"],["extract","extract"]]
 if id=="wood":types=[["event","battle"],["shop","hire"],["battle","supply"],["shop","battle"],["extract","extract"]]
 if id=="waste":types=[["shop","battle"],["hire","event"],["battle","shop"],["supply","battle"],["extract","extract"]]
 var encounter=0
 for depth in range(types.size()):
  for lane in range(2):
   var kind=types[depth][lane]
   nodes.append({"id":"%d%s"%[depth,"a" if lane==0 else "b"],"depth":depth,"lane":lane,"kind":kind,"encounter":mini(encounter,2)})
   if kind=="battle":encounter+=1
# Generation is deterministic and isolated from reward RNG and global random state.
func generate(route_seed: int):
 var random=RandomNumberGenerator.new()
 random.seed=route_seed
 var count=random.randi_range(7,9)
 var encounter=0
 for depth in range(count):
  var types=["battle","event"]
  if depth==0:types=["battle","shop"]
  elif depth==1:types=["supply","hire"] if random.randf()<0.6 else ["event","hire"]
  elif depth==3:types=["shop","supply"]
  elif depth==count-3:types=["supply","shop"]
  elif depth==count-2:types=["battle","battle"]
  elif depth==count-1:types=["extract","extract"]
  elif depth>3:types=["battle","supply"]
  if depth>0 and depth<count-2 and random.randf()<0.5:types.reverse()
  for lane in range(2):
   var kind=types[lane]
   var threat="boss" if depth==count-2 else ("elite" if depth>=4 and kind=="battle" else "normal")
   var n={"id":"%d%s"%[depth,"a" if lane==0 else "b"],"depth":depth,"lane":lane,"kind":kind,"encounter":encounter if kind=="battle" else -1,"tier":mini(2,int(depth/3)),"threat":threat,"seed":int(random.randi()),"biome":region,"event":random.randi_range(0,5)}
   if kind=="battle":encounter+=1
   if kind=="shop":
    n.stock=["fury","focus"]
    var gear=Jobs.ITEMS.keys().filter(func(id):return not Jobs.ITEMS[id].get("legacy",false))
    for i in range(3):n.stock.append(gear.pop_at(random.randi_range(0,gear.size()-1)))
    var relic_pool=Relic.CATALOG.keys()
    for i in range(2):n.stock.append(relic_pool.pop_at(random.randi_range(0,relic_pool.size()-1)))
   nodes.append(n)

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
 var result={"region":region,"current":current,"completed":completed,"visited":visited.duplicate()}
 if seed_value>=0:result.merge({"seed":seed_value,"generation":1})
 return result
func restore(saved: Dictionary) -> bool:
 if not saved.get("region","") in REGIONS.map(func(r):return r.id):return false
 var route_seed=saved.get("seed",-1)
 if not route_seed is int and not route_seed is float:return false
 if not is_finite(float(route_seed)) or float(route_seed)!=floor(float(route_seed)) or route_seed< -1 or route_seed>4294967295:return false
 if route_seed>=0 and saved.get("generation",0)!=1:return false
 setup(saved.region,int(route_seed))
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
