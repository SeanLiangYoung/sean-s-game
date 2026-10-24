extends SceneTree
const Rules=preload("res://game/rules.gd")
const Jobs=preload("res://game/professions.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func setup(job: String):
 var r=Rules.new()
 var party=r.default_party()
 var unit=party[0] if job=="hero" else party[1]
 unit.profession=job;unit.role=Jobs.JOBS[job].name;unit.speed=30
 r.start_battle([unit,party[3]],0)
 r.obstacles=[]
 var a=r.actors[0]
 a.cell=Vector2i.ZERO
 r.actors[1].cell=Vector2i(-1,0)
 r.actors[2].cell=Vector2i(1,0)
 r.actors[3].cell=Vector2i(3,0)
 r.actors[4].cell=Vector2i(3,-1)
 return r
func _initialize():
 var r=Rules.new()
 check(r.has_method("can_cast"),"distinct tactical skills exist")
 if not r.has_method("can_cast"):
  print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1);return
 r=setup("medic")
 var a=r.active()
 var ally=r.actors[1]
 ally.hp=1
 check(r.call("cast",ally.id,"heal") and ally.hp==33,"medic healing specialization")
 check(not r.call("cast",ally.id,"heal"),"skill once per personal turn")
 r=setup("hero");a=r.active();ally=r.actors[1];ally.hp=1;a.learned=["heal"]
 check(r.call("cast",ally.id,"heal") and ally.hp==27,"hero learns heal without medic specialization")
 r=setup("blade");a=r.active();var enemy=r.actors[2]
 enemy.cell=Vector2i(2,0)
 check(r.call("cast",enemy.id,"dash") and r.hex_distance(a.cell,enemy.cell)==1,"dash has legal landing")
 r=setup("blade");a=r.active();enemy=r.actors[2];enemy.hp=1
 check(r.call("cast",enemy.id,"execute") and a.ap==3,"blade kill refund")
 r.actors[3].cell=Vector2i(0,1);r.actors[3].hp=1
 check(r.attack(r.actors[3].id) and a.ap==1,"refund once per turn")
 r=setup("ranger");a=r.active();enemy=r.actors[2];enemy.hp=100;enemy.max_hp=100
 check(r.call("cast",enemy.id,"mark"),"mark applied")
 check(r.attack(enemy.id) and enemy.hp==73,"mark adds five to melee-distance basic attack")
 r=setup("ranger");a=r.active();enemy=r.actors[2];enemy.cell=Vector2i(4,0)
 check(r.call("cast",enemy.id,"sniper"),"sniper reaches five tiles")
 r=setup("engineer");a=r.active();enemy=r.actors[2]
 check(r.call("cast",Vector2i(2,0),"trap"),"empty-cell trap placement")
 var ap=a.ap;var mp=a.mp
 check(not r.call("cast",Vector2i(2,1),"trap") and a.ap==ap and a.mp==mp,"rejected repeated trap costs nothing")
 r.order_index=r.order.find(2);enemy.ap=4
 check(r.move_to(Vector2i(3,0))==false,"occupied destination rejected")
 r.actors[3].cell=Vector2i(4,-1)
 var hp=enemy.hp
 check(r.move_to(Vector2i(3,0)) and enemy.cell==Vector2i(2,0) and enemy.hp==hp-26,"enemy trap interrupts path with specialized damage")
 check(r.traps.is_empty(),"trap consumed")
 r=setup("engineer");a=r.active();enemy=r.actors[2]
 r.call("cast",Vector2i(2,0),"trap")
 r.order_index=r.order.find(2);enemy.ap=4;enemy.hp=10
 r.actors[3].cell=Vector2i(4,-1)
 r.move_to(Vector2i(3,0))
 check(enemy.hp==0 and r.active().id!=enemy.id and r.outcome=="","lethal trap advances turn instead of deadlocking")
 r=setup("engineer");a=r.active();enemy=r.actors[2]
 r.actors[3].cell=Vector2i(1,1)
 var hp0=enemy.hp;var hp1=r.actors[3].hp
 check(r.call("cast",enemy.id,"bomb") and enemy.hp==hp0-24 and r.actors[3].hp==hp1-24,"bomb hits adjacent enemies")
 r=setup("warden");a=r.active();ally=r.actors[1];enemy=r.actors[2]
 check(r.call("cast",ally.id,"guard"),"guard attached")
 r.order_index=r.order.find(2);enemy.ap=4;enemy.cell=Vector2i(-2,0)
 var guard_hp=a.hp;var ally_hp=ally.hp
 check(r.attack(ally.id) and ally.hp==ally_hp-5 and a.hp==guard_hp-2,"guard splits once and specialist reduces taken damage")
 r=setup("warden");a=r.active();enemy=r.actors[2]
 check(r.call("cast",enemy.id,"bash"),"bash accepted")
 r.begin_turn(a)
 r.begin_turn(enemy)
 check(enemy.ap==3,"bash waits for target next action")
 r.begin_turn(enemy)
 check(enemy.ap==4,"bash consumed once")
 r=setup("medic");a=r.active();ally=r.actors[1];enemy=r.actors[2]
 ally.statuses={"mark":{"source":enemy.id}}
 check(r.call("cast",ally.id,"cleanse") and not ally.statuses.has("mark"),"cleanse removes mark")
 r.order_index=r.order.find(2);enemy.ap=4;enemy.cell=Vector2i(-2,0)
 var shield_hp=ally.hp
 check(r.attack(ally.id) and ally.hp==shield_hp,"shield absorbs ten")
 check(not ally.statuses.has("shield"),"shield consumed on hit")
 r=setup("ranger");a=r.active();enemy=r.actors[2]
 r.call("cast",enemy.id,"mark");r.begin_turn(a)
 check(not enemy.statuses.has("mark"),"mark expires at source turn")
 r.call("cast",enemy.id,"mark");a.hp=0;r.check_outcome()
 check(not enemy.statuses.has("mark"),"dead source removes status")
 for kind in ["sword","dagger","bow","staff","crossbow",""]:
  var party=Rules.new().default_party().slice(0,2)
  party[0].mainhand=kind;party[1].hp=20
  r=Rules.new();r.start_battle(party,0)
  check(r.aura==kind,"aura follows main hand "+kind)
  if kind=="sword":
   r.obstacles=[];r.actors[2].cell=r.active().cell+Vector2i(1,0)
   var before=r.actors[2].hp
   r.attack(r.actors[2].id)
   check(r.actors[2].hp==before-24,"sword aura benefits ally")
  if kind=="dagger":check(r.actors[1].speed==17,"dagger speed before sorting")
  if kind=="bow":check(r.actors[1].range==2,"bow aura adds range")
  if kind=="staff":check(r.actors[1].hp==23,"staff aura heals active unit")
  if kind=="crossbow":check(r.actors[1].armor==2,"crossbow aura armor")
  r.actors[0].hp=0;r.check_outcome()
  check(r.aura=="","hero death disables aura "+kind)
  if kind=="bow":check(r.actors[1].range==1,"death removes bow aura range")
 var party=Rules.new().default_party().slice(1,3)
 r=Rules.new();r.start_battle(party,0)
 check(r.aura=="","hero reserve means no aura")
 r=setup("medic");a=r.active();a.max_ap=2;r.begin_turn(a);ally=r.actors[1];ally.hp=1
 check(r.call("cast",ally.id,"heal"),"plate medic can use two point heal")
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
