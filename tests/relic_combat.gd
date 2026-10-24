extends SceneTree
const Rules=preload("res://game/rules.gd")
const Relic=preload("res://game/relics.gd")
const Campaign=preload("res://game/campaign.gd")
var failures=0
var checks=0
func check(value,message):
 checks+=1
 if not value:failures+=1;print("FAIL: ",message)
func fight(entries: Array):
 var b=Rules.new()
 b.start_battle(b.default_party().slice(0,4),0,entries)
 return b
func activate(b,id):
 b.order_index=b.order.find(b.actors.find(b.find_actor(id)))
 b.begin_turn(b.find_actor(id))
func _initialize():
 var b=fight(["ember","ember","spring","banner"])
 var hero=b.find_actor("hero")
 check(b.relic_modifier(hero,"damage")==12,"duplicate team relics do not stack")
 check(hero.armor==-3,"negative armor is retained as risk")
 var enemy=b.find_actor("enemy0")
 enemy.power=10
 var hp=hero.hp
 b.deal_damage(enemy,hero,10)
 check(hp-hero.hp==15,"negative armor and spring risk increase incoming damage")
 hero.hp=20
 check(b.heal_unit(hero,20)==15,"ember reduces received healing")
 activate(b,"hero")
 check(b.rest_amount("hp")==int(floor(int(floor(hero.max_hp*hero.ap*0.07))*0.75)),"rest previews include both benefits and risks")
 b=fight([Relic.instance("echo",1,"hero")])
 hero=b.find_actor("hero");enemy=b.find_actor("enemy0")
 enemy.cell=hero.cell+Vector2i(1,0);enemy.hp=200;enemy.max_hp=200
 activate(b,"hero")
 var remaining=b.relic_state[0].remaining
 check(not b.cast("missing","strike") and b.relic_state[0].remaining==remaining,"invalid cast spends no charge")
 var mp=hero.mp
 var old_hp=enemy.hp
 check(b.cast(enemy.id,"strike"),"echo bearer casts damage skill")
 check(old_hp-enemy.hp==hero.power+14+8,"echo adds one damage hit")
 check(hero.mp==mp-Rules.Professions.ALL_SKILLS.strike.mp-3 and b.relic_state[0].remaining==5,"echo pays additional mana and one charge")
 check(not b.has_relic(b.find_actor("blade"),"echo"),"personal effects exclude other allies")
 b=fight([Relic.instance("fang",1,"hero")])
 hero=b.find_actor("hero");enemy=b.find_actor("enemy0")
 enemy.hp=200;enemy.max_hp=200
 hp=hero.hp
 b.deal_damage(hero,enemy,10)
 check(enemy.hp==180 and hero.hp==hp-2 and b.relic_state[0].remaining==9,"fang damage cost and charge happen together")
 b=fight([Relic.instance("shell",1,"hero")])
 hero=b.find_actor("hero");b.relic_state[0].remaining=1
 var speed=hero.speed
 hp=hero.hp
 b.lose_hp(hero,15)
 check(hero.hp==hp-5 and b.relic_state.is_empty(),"shell last charge applies reduction then breaks")
 check(hero.speed==speed+2,"destroyed relic removes passive risk immediately")
 b=fight([Relic.instance("tide",1,"hero")])
 hero=b.find_actor("hero");activate(b,"hero")
 hero.mp=0
 var gain=b.rest_amount("mp")
 b.rest("mp")
 check(hero.mp==gain and b.relic_state[0].remaining==5,"mana rest spends one tide charge")
 b=fight([Relic.instance("chalice",1,"hero")])
 hero=b.find_actor("hero");enemy=b.find_actor("enemy0");hero.hp=20
 b.deal_damage(hero,enemy,999)
 check(hero.hp==32 and b.relic_state[0].remaining==7,"kill heals and consumes chalice")
 b=fight([Relic.instance("prism",1,"medic")])
 var medic=b.find_actor("medic")
 hero=b.find_actor("hero");hero.hp=1;hero.cell=medic.cell+Vector2i(1,0)
 activate(b,"medic");mp=medic.mp
 check(b.cast("hero","heal"),"prism bearer heals")
 check(hero.hp==45 and medic.mp==mp-Rules.Professions.ALL_SKILLS.heal.mp-3 and b.relic_state[0].remaining==7,"prism improves heal with mana cost and charge")
 b=fight([Relic.instance("candle",1,"hero")])
 hero=b.find_actor("hero");hero.hp=1;hero.cell=Vector2i(4,0)
 b.shrink()
 check(hero.hp==1 and b.relic_state.is_empty() and b.outcome=="","candle prevents lethal gray tide damage")
 b=fight([Relic.instance("shell",1,"hero")])
 hero=b.find_actor("hero");hero.cell=Vector2i(4,0);hp=hero.hp
 b.shrink()
 check(hero.hp==hp-6 and b.relic_state[0].remaining==7,"shell reduces gray tide damage and consumes charge")
 var c=Campaign.new("user://ashbound-relic-combat.json");c.depart()
 c.acquire_relic("echo","hero");c.personal_relic("hero").remaining=2
 check(c.extract([0]) and c.collection[0].remaining==2 and c.collection[0].owner=="hero","extraction preserves owner and wear")
 c.depart();b=c.make_battle(["blade"],0)
 check(b.relic_modifier(b.find_actor("blade"),"damage")==0 and not b.has_relic(b.find_actor("blade"),"echo"),"reserve owner's personal relic cannot affect deployed ally")
 var malformed=c.to_data();malformed.phase="world";malformed.collection.append(malformed.collection[0].duplicate(true))
 check(not c.load_data(malformed),"duplicate instance IDs rejected")
 print("CHECKS: ",checks," FAILURES: ",failures)
 quit(1 if failures else 0)
