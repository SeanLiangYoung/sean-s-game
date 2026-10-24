extends SceneTree
const Campaign=preload("res://game/campaign.gd")
const Jobs=preload("res://game/professions.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func _initialize():
 var c=Campaign.new("user://progression-test.json")
 check(c.has_method("train_skill"),"experience training exists")
 if not c.has_method("train_skill"):
  print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1);return
 var blade=c.roster[1]
 check(blade.xp==0 and Jobs.new().call("skill_rank",blade,"dash")==1 and "execute" not in Jobs.skills_for(blade),"basic free advanced locked")
 blade.xp=300
 check(not c.train_skill("blade","execute"),"advanced needs rank two basic")
 check(c.train_skill("blade","dash") and blade.xp==255,"rank two spending")
 check(c.train_skill("blade","execute") and "execute" in Jobs.skills_for(blade),"advanced unlock")
 check(c.train_skill("blade","dash") and not c.train_skill("blade","dash"),"rank cap")
 check(not c.train_skill("blade","heal"),"profession boundary")
 var saved=c.to_data()
 var loaded=Campaign.new("user://progression-loaded.json")
 check(loaded.load_data(saved) and loaded.roster[1].skill_ranks==blade.skill_ranks and loaded.roster[1].xp==blade.xp,"save ranks and XP")
 var bad=saved.duplicate(true);bad.roster[1].xp=-1
 check(not loaded.load_data(bad),"negative xp rejected")
 bad=saved.duplicate(true);bad.roster[1].skill_ranks.dash=4
 check(not loaded.load_data(bad),"invalid rank rejected")
 var legacy=saved.duplicate(true);legacy.version=2
 for u in legacy.roster:u.erase("xp");u.erase("skill_ranks")
 check(loaded.load_data(legacy) and "execute" in Jobs.skills_for(loaded.roster[1]),"legacy existing skills preserved")
 c.depart()
 var b=c.make_battle(["hero","blade","ranger"],0)
 b.find_actor("ranger").hp=0
 b.find_actor("blade").kills=2
 b.outcome="victory"
 var before=blade.xp
 check(c.resolve_battle(b) and blade.xp==before+90 and c.roster[0].xp==60,"survivors share plus kills")
 check(c.roster[2].xp==0 and c.roster[3].xp==0,"dead and reserves excluded")
 check(not c.resolve_battle(b) and blade.xp==before+90,"no double settlement")
 check(not c.train_skill("blade","execute"),"reward phase cannot train")
 var r=preload("res://game/rules.gd").new()
 var hero=c.roster[0].duplicate(true);hero.speed=100;hero.skill_ranks.strike=3
 r.start_battle([hero],0)
 var enemy=r.find_actor("enemy0");enemy.cell=Vector2i(-2,0);enemy.hp=1
 check(r.cast(enemy.id,"strike") and r.find_actor("hero").get("kills",0)==1,"skill kill credited")
 check(Jobs.new().call("skill_bonus",hero,"strike")==8,"rank three effect stronger")
 c.phase="camp"
 check(c.change_profession("blade","medic") and Jobs.new().call("skill_rank",blade,"heal")==1,"new profession basic granted")
 check(c.change_profession("blade","blade") and Jobs.new().call("skill_rank",blade,"dash")==3,"retraining preserves investment")
 check(loaded.load_data(JSON.parse_string(JSON.stringify(saved))),"JSON experience round trip")
 for id in ["heal","trap","cleanse","guard","mark","strike"]:
  var unit=Campaign.new().roster[0].duplicate(true)
  unit.speed=100;unit.skill_ranks[id]=3
  r=preload("res://game/rules.gd").new();r.start_battle([unit],0);r.obstacles=[]
  var actor=r.find_actor("hero")
  var foe=r.find_actor("enemy0");foe.cell=actor.cell+Vector2i(1,0);foe.hp=100;foe.max_hp=100
  if id=="heal":
   actor.hp=1
   check(r.cast(actor.id,id) and actor.hp==35,"rank healing applies +8")
  elif id=="trap":
   var cell=actor.cell+Vector2i(0,1)
   check(r.cast(cell,id) and r.traps[0].damage==28,"rank trap applies +8")
  elif id=="cleanse":
   r.cast(actor.id,id)
   var hp=actor.hp;r.deal_damage(foe,actor,25)
   check(actor.hp==hp-7,"rank shield absorbs 18")
  elif id=="mark":
   r.cast(foe.id,id);r.attack(foe.id)
   check(foe.hp==100-actor.power-13,"rank mark adds 13")
  elif id=="strike":
   check(r.cast(foe.id,id) and foe.hp==100-actor.power-22,"rank strike damage applies +8")
  else:
   var ally=Campaign.new().roster[3].duplicate(true);ally.speed=1
   r.start_battle([unit,ally],0);r.obstacles=[]
   actor=r.find_actor("hero");var target=r.find_actor("medic")
   r.cast(target.id,id);foe=r.find_actor("enemy0")
   var hp=actor.hp
   r.deal_damage(foe,target,20)
   check(actor.hp==hp-2,"rank guard reduces shared damage by eight")
 for id in Jobs.BRANCHES:
  var caster=Campaign.new().roster[0].duplicate(true)
  caster.speed=100;caster.skill_ranks[id]=3
  r=preload("res://game/rules.gd").new();r.start_battle([caster],0);r.obstacles=[]
  var actor=r.find_actor("hero");var foe=r.find_actor("enemy0")
  foe.cell=actor.cell+Vector2i(1,0)
  var effect=Jobs.BRANCHES[id].base
  if effect=="heal":
   actor.hp=1
   check(r.cast(actor.id,id) and actor.hp==35,"branch healing "+id)
  elif effect=="cleanse":
   check(r.cast(actor.id,id) and actor.statuses.shield.bonus==8,"branch shielding "+id)
  else:
   foe.hp=1
   check(r.cast(foe.id,id) and actor.kills>=1,"branch damage and kill credit "+id)
 var trapper=Campaign.new().roster[4].duplicate(true);trapper.speed=100
 r=preload("res://game/rules.gd").new();r.start_battle([trapper],0);r.obstacles=[]
 var source=r.find_actor("engineer");var victim=r.find_actor("enemy0")
 var tile=source.cell+Vector2i(1,0)
 r.cast(tile,"trap");victim.cell=tile;victim.hp=1;r.trigger_trap(victim)
 check(source.kills==1,"trap kills reward owner")
 r.deal_damage(source,victim,100)
 check(source.kills==1,"corpse cannot reward another kill")
 var shopper=Campaign.new("user://progression-shop.json")
 shopper.start_region("border");shopper.enter_route("0b");shopper.silver=500
 check(not shopper.buy("execute") and not shopper.buy("blade_sweep"),"shop cannot bypass tree unlock costs")
 var defeat=Campaign.new("user://progression-defeat.json");defeat.depart()
 var lost=defeat.make_battle(["hero"],0);lost.find_actor("hero").kills=3;lost.outcome="gameover"
 defeat.resolve_battle(lost)
 check(defeat.roster[0].xp==0,"defeat grants no experience")
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
