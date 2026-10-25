extends RefCounted
# Terrain uses its own random stream: enemy rolls cannot change the map.
const NAMES=["开阔散布","双路绕行","错落通道","障碍群"]
static func rotate_cell(cell: Vector2i,turns: int) -> Vector2i:
 for i in range(turns):cell=Vector2i(-cell.y,cell.x+cell.y)
 return cell

static func connected(b,limit: int) -> bool:
 var open=b.cells().filter(func(c):return b.hex_distance(c,Vector2i.ZERO)<=limit and c not in b.obstacles)
 var seen={Vector2i.ZERO:true}
 var queue=[Vector2i.ZERO]
 var cursor=0
 while cursor<queue.size():
  var cell=queue[cursor];cursor+=1
  for d in b.DIRS:
   var next=cell+d
   if next in open and not seen.has(next):
    seen[next]=true
    queue.append(next)
 return seen.size()==open.size()

static func safe(b) -> bool:
 # Every surviving ring must remain a single walkable region.
 for limit in range(2,5):
  if not connected(b,limit):return false
 for a in b.actors:
  var exits=0
  for d in b.DIRS:
   if b.is_free(a.cell+d):exits+=1
  if exits<1:return false
 return true

static func generate(b,config: Dictionary):
 var rng=RandomNumberGenerator.new()
 rng.seed=int(config.get("seed",0)) ^ 0x4B1D27
 var region=config.get("biome","border")
 var pattern=rng.randi_range(0,3)
 # Regions bias structure as well as density, but retain multiple layouts.
 if region in ["frost","ruins"] and rng.randf()<0.6:pattern=2
 if region in ["wood","marsh"] and rng.randf()<0.6:pattern=3
 if region=="waste" and rng.randf()<0.6:pattern=0
 var turns=rng.randi_range(0,5)
 var pools=[[],[]]
 for cell in b.cells():
  if b.hex_distance(cell,Vector2i.ZERO)>3:continue
  if cell.x<=-2:pools[0].append(cell)
  if cell.x>=2:pools[1].append(cell)
 # Draw without replacement, keeping opposing deployment bands apart.
 for a in b.actors:
  var pool=pools[a.side]
  a.cell=rotate_cell(pool.pop_at(rng.randi_range(0,pool.size()-1)),turns)
 b.obstacles=[]
 var candidates=[]
 var focus=Vector2i(0,2 if rng.randi_range(0,1)==0 else -2)
 for cell in b.cells():
  var distance=b.hex_distance(cell,Vector2i.ZERO)
  if distance<=1 or distance>3 or not b.unit_at(cell).is_empty():continue
  var local=rotate_cell(cell,(6-turns)%6)
  var score=rng.randf()*2.0
  match pattern:
   1:score+=3.0 if local.x==0 else 0.0
   2:score+=3.0 if (local.y==2 and local.x<=0) or (local.y==-2 and local.x>=0) else 0.0
   3:score+=maxf(0.0,4.0-b.hex_distance(local,focus)*1.5)
  candidates.append({"cell":cell,"score":score})
 candidates.sort_custom(func(a,c):return a.score>c.score)
 var target=rng.randi_range(5,7)
 if region in ["wood","ruins"]:target+=2
 elif region in ["frost","marsh"]:target+=1
 var inner_count=0
 for candidate in candidates:
  if b.obstacles.size()>=target:break
  var cell=candidate.cell
  var inner=b.hex_distance(cell,Vector2i.ZERO)==2
  # At least sixteen of nineteen midgame cells remain available.
  if inner and inner_count>=3:continue
  b.obstacles.append(cell)
  if not safe(b):
   b.obstacles.pop_back()
   continue
  if inner:inner_count+=1
 b.events.append("地形："+NAMES[pattern])
