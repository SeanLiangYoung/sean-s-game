extends SceneTree
const Rules=preload("res://game/rules.gd")
const Jobs=preload("res://game/professions.gd")
const Relic=preload("res://game/relics.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func act(b,choice):
 match choice.get("action",""):
  "move":return b.move_to(choice.target)
  "attack":return b.attack(choice.target)
  "skill":return b.cast(choice.target,choice.skill)
  "rest_mp":return b.rest("mp")
  "rest_hp":return b.rest("hp")
  _:return b.end_action()
func play(b):
 var steps=0
 while b.outcome=="" and steps<400:
  steps+=1
  var a=b.active()
  if a.side==1:b.enemy_step();continue
  if a.cell in b.boss_warnings():
   var dodge=b.auto_action()
   if dodge.get("action","")=="move":act(b,dodge);continue
  if Jobs.job_id(a)=="medic":
   var afflicted=b.actors.filter(func(u):return u.side==0 and u.hp>0 and (u.get("statuses",{}).has("poison") or u.get("statuses",{}).has("chill")) and b.can_cast("cleanse",u.id))
   if not afflicted.is_empty():b.cast(afflicted[0].id,"cleanse");continue
   var wounded=b.actors.filter(func(u):return u.side==0 and u.hp>0 and u.max_hp-u.hp>=25 and b.can_cast("heal",u.id))
   wounded.sort_custom(func(x,y):return x.hp<y.hp)
   if not wounded.is_empty():b.cast(wounded[0].id,"heal");continue
  # Exposed breaks renewable barriers; one support action can open a whole turn.
  var shielded=b.actors.filter(func(u):return u.side==1 and u.hp>0 and u.get("statuses",{}).has("shield") and b.can_cast("hero_sunder",u.id))
  if not shielded.is_empty():b.cast(shielded[0].id,"hero_sunder");continue
  var boss=b.actors.filter(func(u):return u.side==1 and u.hp>0 and u.get("boss",false))
  if b.biome=="ruins" and not b.boss_intents.is_empty() and not boss.is_empty() and b.can_cast("ranger_pin",boss[0].id):b.cast(boss[0].id,"ranger_pin");continue
  if not act(b,b.auto_action()):b.end_action()
 return steps
func _initialize():
 var total=0
 var wins=0
 var identity_wins={}
 for region in ["border","wood","waste","frost","marsh","ruins"]:
  identity_wins[region]=0
  for seed_value in [21,42,73]:
   var party=Rules.new().default_party().slice(0,5)
   var gear=[]
   for pair in [["bastion_sword","hero"],["wind_dagger","blade"],["mark_bow","ranger"],["spring_staff","medic"],["siege_crossbow","engineer"],["bulwark_plate","hero"],["shield","medic"]]:gear.append({"id":pair[0],"owner":pair[1]})
   for u in party:
    for id in Jobs.JOBS[u.profession].skills:u.skill_ranks[id]=2
    u.merge(Jobs.stats(u,gear),true)
   party[0].skill_ranks.ranger_pin=1
   var relic_ids={"border":[["wardbell",""],["shell","hero"]],"wood":[["hunt",""],["focusstone","ranger"],["cog","engineer"]],"waste":[["boots",""],["thorn","blade"]],"frost":[["wardbell",""],["wardstone","medic"]],"marsh":[["campfire",""],["spark","medic"]],"ruins":[["reservoir",""],["well","medic"],["cog","engineer"]]}
   var relics=[]
   for entry in relic_ids[region]:relics.append(Relic.instance(entry[0],relics.size()+1,entry[1]))
   var b=Rules.new();b.start_battle(party,2,relics,{"biome":region,"seed":seed_value,"threat":"boss"})
   var steps=play(b);total+=1
   check(steps<400 and b.outcome!="","counter-build battle terminates")
   if b.outcome=="victory":wins+=1;identity_wins[region]+=1
   print("REGION_SIM ",region," seed=",seed_value," outcome=",b.outcome," round=",b.round_no)
  check(identity_wins[region]>=1,"at least one representative counter build win in "+region)
 check(wins>=12,"majority of prepared counter-build samples can beat bosses")
 print("REGIONAL_BALANCE: ",wins,"/",total," victories")
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
