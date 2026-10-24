extends SceneTree
const Campaign=preload("res://game/campaign.gd")
var checks=0
var failures=0
func check(value,message):
 checks+=1
 if not value:failures+=1;print("FAIL: ",message)
func _initialize():call_deferred("run")
func find_button(node,needle):
 if node is Button and needle in node.text:return node
 for child in node.get_children():
  var found=find_button(child,needle)
  if found!=null:return found
 return null
func run():
 var scene=load("res://game/main.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 scene.set_process(false)
 check(is_instance_valid(scene.modal) and find_button(scene.modal,"开始游戏")!=null,"startup displays main menu")
 if not scene.has_method("show_main_menu"):
  check(false,"main menu API exists")
  print("CHECKS: ",checks," FAILURES: ",failures)
  quit(1)
  return
 var path="user://ashbound-menu-tests.json"
 DirAccess.remove_absolute(path)
 scene.campaign=Campaign.new(path)
 scene.settings_path="user://ashbound-menu-settings-tests.cfg"
 scene.show_main_menu()
 check(find_button(scene.modal,"继续游戏").disabled,"continue disabled without save")
 find_button(scene.modal,"开始游戏").pressed.emit()
 check(not is_instance_valid(scene.modal) and scene.campaign.phase=="camp","new game enters camp")
 check(FileAccess.file_exists(path),"new game creates save at current destination")
 scene.campaign.depart()
 scene.refresh_ui()
 scene.campaign.silver=321
 scene.campaign.world_position=[2.5,3.0]
 scene.show_pause_menu()
 find_button(scene.modal,"保存游戏").pressed.emit()
 var saved=Campaign.new(path)
 check(saved.load_game() and saved.silver==321 and saved.world_position==[2.5,3.0],"manual save retains resources and position")
 scene.return_to_main_menu()
 check(find_button(scene.modal,"继续游戏")!=null,"return opens main menu")
 find_button(scene.modal,"开始游戏").pressed.emit()
 check(find_button(scene.modal,"确认开始")!=null,"existing save requires new game confirmation")
 find_button(scene.modal,"取消").pressed.emit()
 check(saved.load_game() and saved.silver==321,"cancel new game preserves save")
 find_button(scene.modal,"继续游戏").pressed.emit()
 check(scene.campaign.silver==321 and scene.campaign.phase=="world" and not is_instance_valid(scene.modal),"continue restores campaign")
 scene.campaign.silver=322
 scene.show_deploy(0)
 scene.begin_battle(0)
 scene.show_pause_menu()
 check(find_button(scene.modal,"保存游戏").disabled,"midbattle saving disabled")
 var hp=scene.battle.actors[0].hp
 scene._process(2.0)
 check(scene.battle.actors[0].hp==hp,"menu pauses combat")
 scene.return_to_main_menu()
 scene.continue_game()
 check(scene.battle==null and scene.campaign.phase=="world" and scene.campaign.silver==322,"battle continue restores prebattle checkpoint")
 scene.show_pause_menu()
 find_button(scene.modal,"设置").pressed.emit()
 check(scene.modal.find_child("ZoomSpeed",true,false)==null,"fixed camera has no zoom setting")
 find_button(scene.modal,"返回").pressed.emit()
 check(FileAccess.file_exists(scene.settings_path),"display settings persisted independently")
 scene.close_modal()
 var escape=InputEventKey.new()
 escape.keycode=KEY_ESCAPE
 escape.pressed=true
 scene._unhandled_input(escape)
 check(scene.menu_screen=="pause","Escape opens pause menu")
 scene._unhandled_input(escape)
 check(not is_instance_valid(scene.modal),"Escape resumes game")
 scene.campaign.phase="reward"
 scene.campaign.choices=Campaign.REWARDS.slice(0,3).duplicate(true)
 scene.campaign.save_game()
 scene.show_main_menu()
 scene.continue_game()
 check(scene.campaign.phase=="reward" and find_button(scene.modal,"选择此奖励")!=null,"continue restores pending reward selection")
 scene.campaign.save_path="user://missing-menu-dir/save.json"
 scene._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
 check(find_button(scene.modal,"选择此奖励")!=null,"failed window-close save retains required reward dialog")
 scene.campaign.save_path=path
 scene.campaign.phase="gameover"
 scene.campaign.save_game()
 scene.show_main_menu()
 scene.continue_game()
 check(find_button(scene.modal,"读取远征前存档")!=null,"continue restores game-over recovery options")
 scene.close_modal()
 scene.campaign.phase="world"
 scene.campaign.save_path="user://missing-menu-dir/save.json"
 scene.return_to_main_menu()
 check(scene.session_started and scene.menu_screen=="pause","failed return save keeps current game available")
 scene.campaign.save_path=path
 var f=FileAccess.open(path,FileAccess.WRITE)
 f.store_string("broken json")
 f.close()
 scene.show_main_menu()
 check(find_button(scene.modal,"继续游戏").disabled,"corrupt save cannot be continued")
 var before=scene.campaign
 check(not scene.continue_game() and scene.campaign==before,"failed continue preserves current state")
 scene.campaign=Campaign.new("user://missing-menu-dir/save.json")
 scene.campaign.phase="world"
 scene.session_started=true
 scene.show_deploy(0)
 scene.begin_battle(0)
 check(scene.battle==null and scene.campaign.phase=="world" and is_instance_valid(scene.modal),"failed prebattle save keeps deployment and world progress")
 scene.new_game()
 check(scene.campaign.save_path=="user://missing-menu-dir/save.json" and is_instance_valid(scene.modal),"failed new save stays in menu and keeps destination")
 DirAccess.remove_absolute(path)
 DirAccess.remove_absolute(scene.settings_path)
 scene.queue_free()
 await process_frame
 print("CHECKS: ",checks," FAILURES: ",failures)
 quit(1 if failures else 0)
