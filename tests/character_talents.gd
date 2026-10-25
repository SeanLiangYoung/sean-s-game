extends SceneTree
const Rules=preload("res://game/rules.gd")
const Characters=preload("res://game/characters.gd")
const Jobs=preload("res://game/professions.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func setup(id):
 var r=Rules.new()
 var a=Characters.create(id)
 a.speed=100;a.max_mp=100;a.mp=100
 for skill in Jobs.ALL_SKILLS:a.skill_ranks[skill]=1
 var ally=Characters.create("shen" if a.id!="hero" else "bai","friend")
 r.start_battle([a,ally],0)
 r.obstacles=[]
 a=r.actors[0];a.cell=Vector2i.ZERO;a.ap=20
 r.actors[1].cell=Vector2i(-1,0)
 for i in range(2,r.actors.size()):
  r.actors[i].cell=Vector2i(i-1,0);r.actors[i].hp=300;r.actors[i].max_hp=300
 return r
func _initialize():
 var r=setup("qing")
 var t=r.actors[1];t.hp=1
 r.cast(t.id,"heal")
 check(t.hp==43,"Qinghe urgent care adds ten healing")
 r=setup("li")
 r.cast(Vector2i(0,1),"trap")
 check(r.traps[0].damage==32,"Li trap talent adds six")
 r=setup("ya")
 var enemy=r.actors[2];enemy.cell=Vector2i(0,4)
 var hp=enemy.hp
 r.cast(enemy.id,"sniper")
 check(enemy.hp==hp-33,"Ya stationary sniper adds six")
 # Shen: one command, ally proc, kill refund, expiration.
 r=setup("shen");var a=r.actors[0];t=r.actors[2]
 r.cast(t.id,"strike")
 check(t.statuses.has("advance"),"Shen leaves command")
 var friend=r.actors[1];friend.mp=0;t.hp=1
 r.deal_damage(friend,t,1)
 check(friend.mp==3 and not t.statuses.has("advance"),"command kill rewards attacking ally once")
 r=setup("shen");a=r.actors[0];t=r.actors[2]
 r.cast(t.id,"strike");r.begin_turn(a)
 check(not t.statuses.has("advance"),"command expires on captain next action")
 # Wen checks pre-heal life and only actual support.
 r=setup("wen");a=r.actors[0];t=r.actors[1];t.hp=1
 r.cast(t.id,"hero_heal")
 check(t.statuses.shield.bonus==0,"Wen uses pre-heal half life for ten shield")
 r.begin_turn(a)
 check(not t.statuses.has("shield"),"Wen shield expires")
 t.hp=t.max_hp;t.mp=t.max_mp;r.cast(t.id,"hero_rally")
 check(not t.statuses.has("shield"),"full mana support gives no shield")
 # Lu cannot borrow the future refund.
 r=setup("lu");a=r.actors[0];t=r.actors[2];a.mp=30
 r.cast(t.id,"mark");r.cast(t.id,"dash")
 check(a.mp==24,"Lu returns four mana across skill jobs")
 r.cast(r.actors[1].id,"heal")
 check(a.mp==18,"Lu combo refund once")
 r=setup("lu");a=r.actors[0];a.mp=4;r.cast(r.actors[2].id,"mark")
 check(not r.cast(r.actors[2].id,"dash") and a.mp==0,"combo cannot fund unaffordable cast")
 # Aling: actual dash, movement pricing and snare surcharge.
 r=setup("aling");a=r.actors[0];t=r.actors[2];t.cell=Vector2i(2,-1)
 r.cast(t.id,"dash");var ap=a.ap
 check(r.Talents.state(a).free_step,"Aling gets free step after dash")
 r.put_status(a,"snare",t.id)
 var destination=a.cell+Vector2i(0,-1)
 check(r.movement_cost(a,r.path_to(a.cell,destination))==1,"snare surcharge remains on free step")
 check(r.move_to(destination) and a.ap==ap-1 and not r.Talents.state(a).free_step,"free step consumed once")
 r.begin_turn(a)
 check(not r.Talents.state(a).free_step,"free movement expires")
 # Pei execution bonus and mana.
 r=setup("pei");a=r.actors[0];t=r.actors[2];t.hp=150
 r.cast(t.id,"execute")
 check(t.hp==106,"Pei execute adds six beyond normal half-health bonus")
 r=setup("pei");a=r.actors[0];t=r.actors[2];t.hp=1;a.mp=20
 r.cast(t.id,"execute")
 check(a.mp==17,"Pei kill refunds three")
 # Chi lifesteal uses life damage, not overkill or shields.
 r=setup("chi");a=r.actors[0];t=r.actors[2];a.hp=10
 r.cast(t.id,"blade_drain")
 check(t.hp==270 and a.hp==23,"Chi low-life damage and 45 percent drain")
 r=setup("chi");a=r.actors[0];t=r.actors[2];a.hp=10;t.hp=2
 r.cast(t.id,"blade_drain")
 check(a.hp==10,"overkill does not inflate drain")
 # Ya bonus has one use and is lost by movement.
 r=setup("ya");a=r.actors[0]
 check(r.skill_range(a,"sniper")==6,"stationary sniper range six")
 r.cast(r.actors[2].id,"sniper")
 check(r.skill_range(a,"ranger_hunt")==5,"second snipe has normal range")
 r.begin_turn(a);a.ap=20;r.move_to(Vector2i(0,-1))
 check(r.skill_range(a,"sniper")==5,"moving removes sniper talent")
 # Lin grants bonus and one other-ally refund.
 r=setup("lin");a=r.actors[0];t=r.actors[2];friend=r.actors[1];friend.mp=0
 r.cast(t.id,"mark")
 check(t.statuses.mark.bonus==2,"Lin mark gets two bonus")
 r.deal_damage(a,t,1)
 check(t.statuses.mark.talent_mana,"self hit does not consume mark refund")
 r.deal_damage(friend,t,1);r.deal_damage(friend,t,1)
 check(friend.mp==2,"Lin refund once per mark")
 # Suo control uses existing snare and stagger lifecycle.
 r=setup("suo");t=r.actors[2]
 r.cast(t.id,"ranger_pin")
 check(t.statuses.has("snare") and t.statuses.has("stagger"),"Suo binds in addition to normal control")
 # Bai has to cleanse something, shield and healing are independent.
 r=setup("bai");a=r.actors[0];t=r.actors[1];t.hp=1
 r.put_status(t,"poison",r.actors[2].id);r.put_status(t,"snare",r.actors[2].id)
 r.cast(t.id,"cleanse")
 check(t.hp==7 and t.statuses.shield.bonus==4 and not t.statuses.has("poison"),"Bai cleanses multiple ailments but heals once")
 r=setup("bai");t=r.actors[1];t.hp=1;r.cast(t.id,"cleanse")
 check(t.hp==1 and t.statuses.shield.bonus==0,"Bai no reward without harmful status")
 # Wenlan grants three mana to caster and four life to friend.
 r=setup("wenlan");a=r.actors[0];t=r.actors[1];a.mp=20;t.mp=0;t.hp=1
 r.cast(t.id,"medic_channel")
 check(a.mp==19 and t.mp==10 and t.hp==5,"Wenlan support refund and healing")
 r.cast(t.id,"hero_rally")
 check(a.mp==19,"unavailable off-job skill cannot consume resources")
 # Li trap refund and limit.
 r=setup("li");a=r.actors[0];a.mp=20;t=r.actors[2]
 r.cast(Vector2i(0,1),"trap");t.cell=Vector2i(0,1);r.trigger_trap(t)
 check(a.mp==16,"Li trap returns two mana")
 r.Talents.trap_trigger(r,a)
 check(a.mp==16,"trap refund capped per own interval")
 # Tang discount must inspect the actual target and only main target gains damage.
 r=setup("tang");a=r.actors[0];t=r.actors[2];var splash=r.actors[3]
 r.put_status(t,"exposed",a.id);a.mp=6
 check(r.can_cast("bomb",t.id),"Tang can afford discounted bomb")
 check(not r.can_cast("bomb",splash.id),"discount unavailable against unexposed main target")
 r.cast(t.id,"bomb")
 check(a.mp==0 and t.hp==270 and splash.hp==280,"Tang discount and primary-only damage")
 # Ji stronger shields replace rather than add.
 r=setup("ji");a=r.actors[0];t=r.actors[1];t.hp=1
 r.cast(t.id,"engineer_pulse")
 check(t.hp==23 and t.statuses.shield.bonus==6,"Ji normal repair gains four heal and six shield")
 r.begin_turn(a);a.ap=20;t.hp=1;r.put_status(t,"shield",t.id,1)
 r.cast(t.id,"engineer_pulse")
 check(t.hp==19 and t.statuses.shield.bonus==10,"Ji preexisting shield trades heal bonus for ten shield")
 # Yue first two shares are reduced, third is ordinary; resets on own action.
 r=setup("yue");a=r.actors[0];t=r.actors[1];t.max_hp=300;t.hp=300;a.max_hp=300;a.hp=300
 r.cast(t.id,"guard")
 for i in range(3):r.deal_damage(r.actors[2],t,20)
 check(a.hp==285 and t.hp==270,"Yue reductions capped at two shares")
 r.begin_turn(a);a.ap=20;r.cast(t.id,"guard");var prior=a.hp
 r.deal_damage(r.actors[2],t,20)
 check(a.hp==prior-4,"Yue guard cap resets")
 # Qin rewards only interruptible existing warning.
 r=setup("qin");a=r.actors[0];t=r.actors[2]
 r.boss_intents=[{"source":t.id,"kind":"overload"}]
 r.cast(t.id,"bash")
 check(t.hp==278 and r.boss_intents.is_empty() and a.statuses.shield.bonus==-2,"Qin bonus damage, actual interrupt and eight shield")
 r=setup("qin");a=r.actors[0];t=r.actors[2];r.put_status(t,"chill",a.id)
 r.cast(t.id,"bash")
 check(t.hp==283 and not a.statuses.has("shield"),"Qin no damage bonus on already slowed target, no fictitious interrupt")
 # Luosui rescues other low-life targets; only one ailment.
 r=setup("luosui");a=r.actors[0];t=r.actors[1];t.hp=1
 r.put_status(t,"poison",r.actors[2].id);r.put_status(t,"chill",r.actors[2].id)
 r.cast(t.id,"warden_rescue")
 check(t.hp==27 and not t.statuses.has("poison") and t.statuses.has("chill") and t.statuses.has("shield"),"Luosui healing and poison-first cleanse")
 # Talents continue to refer to identity after retraining.
 r=setup("aling");a=r.actors[0];a.profession="warden"
 check(r.Talents.is_character(a,"aling") and "dash" not in r.available_skills(a),"retraining retains identity but gates skill")
 # Relic interactions: healing penalties, shield boosts and independent personal bindings.
 r=setup("qing");a=r.actors[0];t=r.actors[1];t.hp=1
 r.relic_state=[r.Relic.instance("prism",1,a.id),r.Relic.instance("ember",2)]
 r.cast(t.id,"heal")
 check(t.hp==41,"Qing talent and prism heal are jointly reduced by ember recovery penalty")
 check(r.relic_state[0].remaining==7,"enhanced heal consumes only one prism charge")
 r=setup("li");a=r.actors[0]
 r.relic_state=[r.Relic.instance("cog",1,a.id)]
 r.cast(Vector2i(0,1),"trap")
 check(r.traps[0].damage==40,"Li talent stacks with cog once")
 r=setup("wen");a=r.actors[0];t=r.actors[1];t.hp=1
 r.relic_state=[r.Relic.instance("wardbell",1),r.Relic.instance("wardstone",2,a.id)]
 r.cast(t.id,"hero_heal")
 check(t.statuses.shield.bonus==8,"Wen talent shield includes team and caster personal shield boosts")
 r=setup("ji");a=r.actors[0];t=r.actors[1];t.hp=1
 r.put_status(t,"shield",t.id,30)
 r.cast(t.id,"engineer_pulse")
 check(t.statuses.shield.bonus==30 and t.statuses.shield.source==t.id,"weaker shield cannot replace or shorten existing strong shield")
 r.begin_turn(a)
 check(t.statuses.has("shield"),"retained stronger shield keeps its original expiry")
 print("CHECKS: %d FAILURES: %d"%[checks,failures])
 quit(1 if failures else 0)
