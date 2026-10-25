extends "res://tools/fresh_run_simulation.gd"
# Instrumentation does not alter the inherited action, drop, or progression policy.
var diagnostics: Array=[]
var battle_key=""
var support_ai=false
var careful_supply=false
var sustain_training=false
func plan(unit: Dictionary) -> Array:
 if not sustain_training:return super.plan(unit)
 if unit.profession=="hero" and unit.character_id=="lu":return [["strike",2],["hero_burst",1],["hero_burst",2],["hero_sunder",1],["mark",1],["hero_heal",1],["hero_heal",2],["hero_rally",1],["strike",3]]
 if unit.profession=="ranger":return [["mark",2],["sniper",1],["sniper",2],["ranger_pin",1],["ranger_volley",1],["ranger_volley",2],["ranger_expose",1],["mark",3]]
 if unit.profession=="warden":return [["guard",2],["bash",1],["warden_ward",1],["warden_ward",2],["warden_rescue",1],["warden_rebuke",1],["bash",2],["warden_fortify",1]]
 return super.plan(unit)
func supply(c,trace: Array,profile: String="balanced"):
 if not careful_supply:super.supply(c,trace,profile);return
 while c.phase=="world" and c.supplies>1:
  var active=c.roster.filter(func(u):return u.id in deployed(c,profile))
  if not active.any(func(u):return u.hp*100<u.max_hp*80 or u.mp*100<u.max_mp*50):break
  var before=c.supplies
  if not c.use_supply():break
  trace.append({"region":c.route.region,"node":c.route.current,"used":before-c.supplies,"remaining":c.supplies})
func units_state(units: Array) -> Array:
 var result=[]
 for u in units:
  result.append({"id":u.id,"character":u.get("character_id",u.id),"side":u.get("side",0),"hp":u.hp,"max_hp":u.max_hp,"mp":u.mp,"max_mp":u.max_mp,"ap":u.get("ap",0),"skills":u.get("skill_ranks",{}).duplicate(true),"xp":u.get("xp",0),"statuses":u.get("statuses",{}).duplicate(true)})
 return result
func battle_step(c,b,trace: Array) -> bool:
 var key=c.route.region+":"+c.route.current
 if key!=battle_key:
  battle_key=key
  diagnostics.append({"region":c.route.region,"node":c.route.current,"supplies":c.supplies,"silver":c.silver,"initial":units_state(b.actors),"initial_roster":units_state(c.roster),"events":[],"actions":{},"rounds":[],"outcome":""})
 var d=diagnostics[-1]
 if d.rounds.is_empty() or d.rounds[-1].round!=b.round_no:d.rounds.append({"round":b.round_no,"units":units_state(b.actors),"supplies":c.supplies})
 var actor=b.active();var before=b.events.size();var actor_id=actor.id
 var supplied=false
 if careful_supply and actor.side==0 and actor.ap>=2 and c.supplies>0 and actor.cell not in b.boss_warnings():
  var targets=b.actors.filter(func(u):return u.side==0 and u.hp>0 and u.max_hp-u.hp>=15 and u.hp*100<u.max_hp*75 and b.auto_incoming_pressure(u,u.cell)>=u.hp)
  targets.sort_custom(func(x,y):return x.hp*y.max_hp<y.hp*x.max_hp)
  for target in targets:
   if ["heal","medic_mend","hero_heal","engineer_pulse","warden_rescue"].any(func(id):return b.can_cast(id,target.id)):continue
   if b.use_medicine(target.id):
    c.supplies-=1;supplied=true
    trace.append({"region":c.route.region,"node":c.route.current,"in_battle":true,"actor":actor.id,"target":target.id,"used":1,"remaining":c.supplies});break
 var ok=true if supplied else super.battle_step(c,b,trace)
 for i in range(before,b.events.size()):
  d.events.append({"round":b.round_no,"actor":actor_id,"text":b.events[i]})
 d.actions[actor_id]=int(d.actions.get(actor_id,0))+1
 d.outcome=b.outcome;d.final=units_state(b.actors);d.final_supplies=c.supplies
 return ok
func run(captain: String,profile: String,strategy: String,region: String,seed_value: int,denied: Array=[],whole_campaign: bool=false) -> Dictionary:
 diagnostics=[];battle_key=""
 combat.support_ai=support_ai
 var result=super.run(captain,profile,strategy,region,seed_value,denied,whole_campaign)
 result.diagnostics=diagnostics.duplicate(true)
 result.decisions={"support_ai":support_ai,"careful_supply":careful_supply,"sustain_training":sustain_training}
 return result
