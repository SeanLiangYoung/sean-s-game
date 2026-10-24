extends SceneTree
var checks=0
var failures=0
func check(value: bool):
 checks+=1
 if not value:failures+=1;push_error("route check %d"%checks)
func _init():
 var c=preload("res://game/campaign.gd").new("user://routes-test.json")
 check(c.start_region("border"))
 check(c.route.available()==["0a","0b"])
 check(not c.route.visible_nodes().any(func(n):return n.depth>2))
 check(c.enter_route("0b"))
 check(not c.enter_route("0a"))
 check(not c.buy("sword"))
 check(c.silver==40)
 c.silver=500
 check(c.buy("sword"))
 check(not c.buy("sword"))
 check(c.buy("fury"))
 check(c.learn_book(0,"hero"))
 check(c.roster[0].get("learned",[]).has("fury"))
 check(c.books.is_empty())
 check(c.enter_route("1b"))
 check(c.hire(0))
 check(not c.hire(0))
 var loaded=preload("res://game/campaign.gd").new("user://routes-test.json")
 check(loaded.load_game())
 check(loaded.route.current==c.route.current)
 check(loaded.roster.size()==7)
 check(loaded.roster[0].learned==["fury"])
 check(not loaded.enter_route("0a"))
 check(not loaded.buy("focus"))
 loaded.roster[0].hp=0
 loaded.books=["focus"]
 check(not loaded.learn_book(0,"hero"))
 check(loaded.books==["focus"])
 var invalid=loaded.to_data()
 invalid.route.visited=["4a"]
 check(not loaded.load_data(invalid))
 var rules=preload("res://game/rules.gd").new()
 var hero=preload("res://game/rules.gd").new().default_party()[0]
 hero.learned=["focus"]
 rules.start_battle([hero],0)
 rules.order_index=rules.order.find(0)
 rules.actors[0].hp=20
 check(rules.rest_amount("hp")==22)
 var blocked=preload("res://game/campaign.gd").new("user://routes-blocked.json")
 check(blocked.start_region("border"))
 check(not blocked.extract([]))
 check(blocked.enter_route("0a"))
 check(not blocked.enter_route("1a"))
 check(blocked.make_battle(["hero"],1)==null)
 print("CHECKS: %d FAILURES: %d"%[checks,failures])
 quit(1 if failures else 0)
