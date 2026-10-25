extends SceneTree
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
 var scene=load("res://game/main.tscn").instantiate()
 scene.settings_path="user://achievement-popup-settings.cfg"
 DirAccess.remove_absolute(scene.settings_path)
 DirAccess.remove_absolute(scene.settings_path+".progression")
 root.add_child(scene);await process_frame
 scene.set_process(false)
 var path="user://achievement-popup-tests.json"
 for suffix in ["",".achievements"]:DirAccess.remove_absolute(path+suffix)
 scene.campaign=load("res://game/campaign.gd").new(path)
 scene.campaign.cleared_regions=["border","wood","waste","frost","marsh"]
 scene.campaign.start_region("ruins")
 var boss=scene.campaign.route.nodes.filter(func(n):return n.get("threat","")=="boss")[0]
 for depth in range(int(boss.depth)+1):
  scene.campaign.route.enter("%da"%depth)
  if depth<int(boss.depth):scene.campaign.route.completed=true
 scene.enter_campaign();scene.selected_ids=["hero"];scene.begin_battle(int(boss.encounter))
 scene.battle.outcome="victory";scene.after_battle_action()
 var popup=scene.ui.get_node_or_null("AchievementUnlockPopup")
 check(popup!=null,"first full clear opens achievement popup")
 if popup!=null:
  check(popup.visible and popup.title=="成就解锁","popup is visible with unlock title")
  check("灰潮归来" in popup.dialog_text and "全队攻击 +1" in popup.dialog_text,"popup shows achievement name and awarded attribute")
  check(scene.campaign.phase=="reward" and scene.campaign.choices.size()==5,"popup preserves reward selection")
  var celebration=popup.get_node_or_null("UnlockCelebration")
  check(celebration!=null,"unlock has celebration animation")
  var sound=popup.get_node_or_null("UnlockCelebration/UnlockChime")
  check(sound is AudioStreamPlayer and sound.stream is AudioStreamWAV and sound.playing,"unlock plays a one-shot chime")
  if celebration!=null:
   check(popup.get_label().modulate.a<1.0,"achievement text fades in")
   await create_timer(0.85).timeout
   check(popup.get_label().modulate.a==1.0 and popup.get_label().scale.is_equal_approx(Vector2.ONE),"entrance settles at fully readable size")
   check(celebration.progress==1.0,"sparkle burst finishes")
  if sound!=null:
   check(sound.stream.get_length()>0.5 and sound.stream.get_length()<2.0 and sound.stream.loop_mode==AudioStreamWAV.LOOP_DISABLED,"chime is short and non-looping")
   var pcm=sound.stream.data
   var peak=0
   for i in range(pcm.size()/2):peak=maxi(peak,absi(pcm.decode_s16(i*2)))
   check(peak>1000 and peak<30000,"chime has audible signal with headroom")
   check(pcm.decode_s16(0)==0 and absi(pcm.decode_s16(pcm.size()-2))<10,"chime fades at both boundaries")
  popup.confirmed.emit();await process_frame
  check(not is_instance_valid(popup),"confirm dismisses popup")
  scene.show_reward()
  check(scene.ui.get_node_or_null("AchievementUnlockPopup")==null,"reopening rewards does not repeat notification")
 scene.show_achievement_unlock(1)
 var early=scene.ui.get_node("AchievementUnlockPopup")
 check("全队护甲 +1" in early.dialog_text,"celebration preserves each achievement reward")
 early.canceled.emit();await process_frame
 check(not is_instance_valid(early),"can dismiss safely during animation and sound")
 # Repeat the same final boss: its achievement is already owned.
 scene.return_world();scene.campaign.phase="camp";scene.campaign.start_region("ruins")
 boss=scene.campaign.route.nodes.filter(func(n):return n.get("threat","")=="boss")[0]
 for depth in range(int(boss.depth)+1):
  scene.campaign.route.enter("%da"%depth)
  if depth<int(boss.depth):scene.campaign.route.completed=true
 scene.selected_ids=["hero"];scene.begin_battle(int(boss.encounter))
 scene.battle.outcome="victory";scene.after_battle_action()
 check(scene.ui.get_node_or_null("AchievementUnlockPopup")==null,"repeat completion does not show unlock popup")
 for suffix in ["",".achievements"]:DirAccess.remove_absolute(path+suffix)
 DirAccess.remove_absolute(scene.settings_path+".progression")
 scene.queue_free();await process_frame
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
