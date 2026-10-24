extends SceneTree
const Rules=preload("res://game/rules.gd")
const Regional=preload("res://game/region_combat.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func make_battle(region):
 var b=Rules.new();b.start_battle(b.default_party().slice(0,5),1,[],{"biome":region,"seed":42,"threat":"boss"});b.obstacles=[]
 return b
func _initialize():
 var first=make_battle("wood")
 check(first.actors[-1].has("boss_phase"),"boss phase state exists")
 if not first.actors[-1].has("boss_phase"):finish();return
 for region in ["border","wood","waste","frost","marsh","ruins"]:
  var b=make_battle(region);var boss=b.actors[-1];var hero=b.find_actor("hero")
  check(boss.boss_phase==1,"starts phase one "+region)
  b.order_index=b.order.find(b.actors.find(boss));boss.ap=4
  b.enemy_step()
  var frozen=b.boss_intents.duplicate(true)
  check(not frozen.is_empty() and frozen[0].phase==1,"intent snapshots phase")
  b.lose_hp(boss,int(ceil(boss.max_hp*0.5)))
  check(boss.boss_phase==2,"half HP transitions "+region)
  check(b.boss_intents==frozen,"existing warnings don't mutate at phase change")
  check(b.boss_cues.filter(func(c):return c.type=="phase").size()==1,"one transition cue")
  b.heal_unit(boss,boss.max_hp);b.lose_hp(boss,int(ceil(boss.max_hp*0.5)))
  check(boss.boss_phase==2 and b.boss_cues.filter(func(c):return c.type=="phase").size()==1,"transition latched after healing")
  b.boss_intents=[];boss.enemy_used=false;boss.boss_prepared=false;boss.cooldowns={}
  check(Regional.prepare(b,boss),"phase two prepares with ordinary AP")
  var plan=b.boss_intents[0]
  check(plan.phase==2 and plan.cells.size()<=7 and plan.name!=frozen[0].name,"phase two has distinct bounded pattern")
  check(plan.damage>=frozen[0].damage,"phase two uses declared damage")
  var copy=b.auto_snapshot();copy.boss_cues.clear()
  check(not b.boss_cues.is_empty() and copy.actors[-1].boss_phase==2,"phase and cues isolated in auto snapshot")
  boss.hp=0;b.check_outcome();check(b.boss_warnings().is_empty(),"death cancels phase two intent")
 # Every warned ally on a small board has a reachable safe cell (assuming two or more AP).
 for radius_value in [1,2,3,4]:
  var b=make_battle("waste");b.radius=radius_value
  var boss=b.actors[-1];boss.cell=Vector2i(radius_value,0)
  var hero=b.find_actor("hero");hero.cell=Vector2i.ZERO
  for unit in b.actors:
   if unit.id not in [hero.id,boss.id]:unit.hp=0
  b.lose_hp(boss,int(ceil(boss.max_hp*0.5)));boss.ap=4
  check(Regional.prepare(b,boss),"late-ring phase two can prepare")
  var escapes=b.cells().filter(func(c):return c not in b.boss_warnings() and not b.path_to(hero.cell,c).is_empty())
  check(not escapes.is_empty(),"late ring leaves reachable escape")
 # Trap-style damage can transition; lethal damage does not manufacture a phase change.
 var b=make_battle("frost");var boss=b.actors[-1];var hero=b.find_actor("hero")
 boss.statuses={};b.deal_damage(hero,boss,90,false)
 check(boss.boss_phase==2,"indirect damage triggers phase")
 b=make_battle("wood");boss=b.actors[-1];b.lose_hp(boss,999)
 check(boss.boss_phase==1 and b.boss_cues.filter(func(c):return c.type=="phase").is_empty(),"dead bosses don't transition")
 finish()
func finish():
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
