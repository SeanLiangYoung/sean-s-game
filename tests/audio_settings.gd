extends SceneTree
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
 var path="user://achievement-audio-settings-tests.cfg"
 DirAccess.remove_absolute(path)
 var scene=load("res://game/main.tscn").instantiate()
 scene.settings_path=path
 root.add_child(scene);await process_frame
 scene.set_process(false);scene.show_settings(true)
 var toggle=scene.modal.find_child("SoundEffectsToggle",true,false)
 var slider=scene.modal.find_child("SoundEffectsVolume",true,false)
 check(toggle is CheckButton and slider is HSlider,"settings expose sound toggle and volume slider")
 if toggle==null or slider==null:
  scene.queue_free();await process_frame
  print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1);return
 check(toggle.button_pressed and slider.value==100,"default enabled and original volume retained")
 slider.value=25
 check(scene.sfx_volume==0.25 and "25%" in scene.modal.find_child("SoundEffectsVolumeLabel",true,false).text,"slider updates volume and percentage")
 var preview_button=scene.modal.find_child("SoundEffectsPreviewButton",true,false)
 var preview=scene.modal.find_child("SoundEffectsPreview",true,false)
 check(preview_button is Button and preview is AudioStreamPlayer,"settings provide a chime preview button and player")
 if preview_button!=null and preview!=null:
  preview_button.pressed.emit()
  check(preview.playing and preview.stream==preload("res://game/achievement_celebration.gd").chime(),"preview plays the real achievement chime")
  check(is_equal_approx(preview.volume_db,-10.0+linear_to_db(0.25)),"preview follows unsaved slider volume")
  slider.value=40
  check(is_equal_approx(preview.volume_db,-10.0+linear_to_db(0.4)),"volume changes update active preview")
  preview_button.pressed.emit()
  check(scene.modal.find_children("SoundEffectsPreview","AudioStreamPlayer",true,false).size()==1,"repeated preview reuses one player")
  slider.value=0
  check(preview_button.disabled and not preview.playing,"zero volume disables and stops preview")
  slider.value=25
  check(not preview_button.disabled,"raising volume reenables preview")
  preview_button.pressed.emit()
 toggle.button_pressed=false
 check(not scene.sfx_enabled and not slider.editable,"mute disables slider without losing volume")
 if preview_button!=null and preview!=null:
  check(preview_button.disabled and not preview.playing,"mute disables and stops preview")
 scene.navigate_back()
 await process_frame
 check(not is_instance_valid(preview),"leaving settings releases preview player")
 var config=ConfigFile.new();config.load(path)
 check(config.get_value("audio","sfx_enabled",true)==false and config.get_value("audio","sfx_volume",0)==0.25,"return saves sound preferences")
 scene.sfx_enabled=true;scene.sfx_volume=1.0;scene.load_settings()
 check(not scene.sfx_enabled and scene.sfx_volume==0.25,"reloading restores sound preferences")
 scene.show_achievement_unlock(0)
 var popup=scene.ui.get_node("AchievementUnlockPopup")
 var sound=popup.get_node("UnlockCelebration/UnlockChime")
 check(not sound.playing,"muted achievement does not play sound")
 check(popup.get_node("UnlockCelebration")!=null,"muting preserves celebration animation")
 popup.canceled.emit();await process_frame
 scene.show_settings(true)
 toggle=scene.modal.find_child("SoundEffectsToggle",true,false)
 slider=scene.modal.find_child("SoundEffectsVolume",true,false)
 toggle.button_pressed=true
 check(slider.editable and slider.value==25,"unmuting restores selected volume")
 scene.show_achievement_unlock(0)
 popup=scene.ui.get_node("AchievementUnlockPopup")
 sound=popup.get_node("UnlockCelebration/UnlockChime")
 check(sound.playing and is_equal_approx(sound.volume_db,-10.0+linear_to_db(0.25)),"achievement playback uses selected volume")
 popup.canceled.emit();await process_frame
 slider.value=0
 scene.show_achievement_unlock(0)
 popup=scene.ui.get_node("AchievementUnlockPopup")
 check(not popup.get_node("UnlockCelebration/UnlockChime").playing,"zero volume is silent")
 popup.canceled.emit();await process_frame
 config.set_value("audio","sfx_enabled","invalid")
 config.set_value("audio","sfx_volume",5.0);config.save(path)
 scene.load_settings()
 check(scene.sfx_enabled and scene.sfx_volume==1.0,"invalid toggle uses default and volume is bounded")
 config.set_value("audio","sfx_volume","invalid");config.save(path)
 scene.load_settings()
 check(scene.sfx_volume==1.0,"invalid volume uses default")
 config.erase_section("audio");config.save(path)
 scene.load_settings()
 check(scene.sfx_enabled and scene.sfx_volume==1.0,"old settings without audio stay compatible")
 DirAccess.remove_absolute(path)
 scene.queue_free();await process_frame
 # Let the audio thread release its stopped playback before exiting the engine.
 await create_timer(0.1).timeout
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
