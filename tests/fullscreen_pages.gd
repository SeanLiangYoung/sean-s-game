extends SceneTree
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func _initialize():call_deferred("run")
func find_button(node,needle):
 if node is Button and (needle in node.text or needle in node.accessibility_name):return node
 for child in node.get_children():
  var found=find_button(child,needle)
  if found!=null:return found
 return null
func press_back(scene):
 check(scene.modal.position==Vector2.ZERO and scene.modal.anchor_right==1.0 and scene.modal.anchor_bottom==1.0,"page fills viewport")
 var back=scene.modal.find_child("PageBack",true,false)
 check(back!=null,"page exposes a back button")
 if back!=null:back.pressed.emit()
func escape(scene,echo_event=false):
 var event=InputEventKey.new()
 event.keycode=KEY_ESCAPE
 event.pressed=true
 event.echo=echo_event
 scene._unhandled_input(event)
func run():
 var scene=load("res://game/main.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 scene.set_process(false)
 scene.settings_path="user://fullscreen-navigation-settings.cfg"
 scene.campaign=load("res://game/campaign.gd").new("user://fullscreen-navigation-tests.json")
 check(scene.modal.position==Vector2.ZERO and scene.modal.anchor_right==1.0 and scene.modal.anchor_bottom==1.0,"main menu fills viewport")
 scene.show_settings(true)
 var back=scene.modal.find_child("PageBack",true,false)
 check(back!=null,"settings has top-left back navigation")
 if back!=null:
  back.pressed.emit()
  check(scene.menu_screen=="main","settings back returns to main menu")
 scene.close_modal()
 scene.session_started=true
 scene.campaign.depart()
 scene.show_deploy(0)
 back=scene.modal.find_child("PageBack",true,false)
 if back!=null:back.pressed.emit()
 check(not is_instance_valid(scene.modal),"deployment back returns to world")
 scene.show_party_menu()
 check(scene.modal.position==Vector2.ZERO and scene.modal.anchor_right==1.0,"party page fills viewport")
 back=scene.modal.find_child("PageBack",true,false)
 check(back!=null,"party page retains back navigation")
 # Key repeats must not dismiss a newly opened page.
 escape(scene,true)
 check(is_instance_valid(scene.modal) and scene.party_menu_open,"held Escape does not dismiss party page")
 if is_instance_valid(scene.modal):press_back(scene)
 scene.show_pause_menu()
 scene.show_settings(false)
 scene.settings_path="user://missing-fullscreen-settings/settings.cfg"
 press_back(scene)
 check(scene.menu_screen=="settings","failed settings save stays on settings page")
 scene.settings_path="user://fullscreen-navigation-settings.cfg"
 escape(scene)
 check(scene.menu_screen=="pause","settings Escape returns to pause menu")
 scene.request_main_menu()
 press_back(scene)
 check(scene.menu_screen=="pause" and scene.session_started,"cancel return-to-main preserves session")
 press_back(scene)
 check(not is_instance_valid(scene.modal),"pause back resumes game")
 scene.show_restore()
 var before=scene.campaign.to_data()
 press_back(scene)
 check(not is_instance_valid(scene.modal) and scene.campaign.to_data()==before,"cancel restore preserves campaign")
 scene.show_extract()
 press_back(scene)
 check(scene.campaign.phase=="world" and not is_instance_valid(scene.modal),"extraction back keeps expedition active")
 scene.campaign.phase="reward"
 var reward=scene.campaign.REWARDS.filter(func(r):return r.id=="echo")[0]
 scene.campaign.choices=[reward.duplicate(true)]
 scene.show_reward()
 escape(scene)
 check(is_instance_valid(scene.modal) and scene.page_back.disabled,"Escape cannot skip reward settlement")
 scene.show_relic_binding("echo",0)
 press_back(scene)
 check(scene.campaign.phase=="reward" and scene.campaign.choices.size()==1 and scene.page_back.disabled,"binding back retains unclaimed reward")
 scene.show_relic_binding("echo",0)
 escape(scene)
 check(scene.campaign.phase=="reward" and scene.page_back.disabled,"binding Escape returns to reward page")
 scene.close_modal()
 scene.campaign=load("res://game/campaign.gd").new("user://fullscreen-navigation-tests.json")
 scene.enter_campaign()
 scene.show_region("border")
 press_back(scene)
 check(scene.campaign.phase=="camp" and scene.campaign.route.region=="" and scene.atlas.visible,"region back returns to map without starting expedition")
 scene.show_region("border")
 var start=find_button(scene.modal,"确认出发")
 start.pressed.emit()
 scene.campaign.route.setup("border");scene.campaign.encounters=["open","open","open"]
 check(not is_instance_valid(scene.modal) and scene.atlas.route_mode,"region confirmation enters route map")
 scene.select_route_node("0b")
 scene.show_relic_binding("echo")
 press_back(scene)
 check(find_button(scene.modal,"购买")!=null and scene.campaign.at_node("shop"),"shop binding back returns to shop")
 press_back(scene)
 check(not is_instance_valid(scene.modal) and scene.atlas.route_mode,"shop back returns to route")
 scene.select_route_node("1b")
 press_back(scene)
 check(not is_instance_valid(scene.modal) and scene.campaign.at_node("hire"),"hire back preserves current route node")
 scene.select_route_node("2b")
 press_back(scene)
 check(scene.battle==null and not scene.campaign.route.completed,"deployment back leaves encounter available")
 scene.show_deploy(1)
 scene.begin_battle(1)
 var battle_before=scene.battle
 scene.show_surrender()
 press_back(scene)
 check(scene.battle==battle_before and scene.battle.outcome=="","surrender back preserves battle")
 scene.show_party_menu()
 escape(scene)
 check(scene.battle==battle_before and not is_instance_valid(scene.modal),"party Escape returns to same battle")
 scene.show_gameover()
 back=scene.modal.find_child("PageBack",true,false)
 check(back!=null and back.disabled,"mandatory game-over cannot be dismissed")
 scene.battle=null
 scene.campaign.phase="world"
 scene.campaign.save_game()
 scene.show_main_menu()
 scene.request_new_game()
 press_back(scene)
 check(scene.menu_screen=="main" and not scene.session_started,"new-game cancellation returns to main menu")
 escape(scene)
 check(scene.menu_screen=="main" and scene.page_back.disabled,"main menu cannot back into inactive session")
 DirAccess.remove_absolute("user://fullscreen-navigation-tests.json")
 DirAccess.remove_absolute("user://fullscreen-navigation-settings.cfg")
 scene.queue_free()
 await process_frame
 print("CHECKS: %d FAILURES: %d"%[checks,failures])
 quit(1 if failures else 0)
