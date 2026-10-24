extends SceneTree
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func button(node,needle):
 if node is Button and needle in node.text:return node
 for child in node.get_children():
  var found=button(child,needle)
  if found!=null:return found
 return null
func _initialize():call_deferred("run")
func run():
 var scene=load("res://game/main.tscn").instantiate();root.add_child(scene);await process_frame
 scene.set_process(false);scene.close_modal()
 scene.campaign=load("res://game/campaign.gd").new("user://equipment-preview-test.json")
 scene.show_party_menu("装备","hero")
 var preview=scene.modal.find_child("EquipmentPreview",true,false)
 check(preview!=null,"equipment page has full-body preview")
 if preview==null:
  scene.queue_free();await process_frame
  print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1);return
 check(preview.viewport.own_world_3d and preview.pawn!=null,"preview has isolated world and equipped model")
 var world_zoom=scene.camera.size
 var wheel=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true
 var old_zoom=preview.camera.size
 preview.handle_input(wheel)
 check(preview.camera.size<old_zoom and scene.camera.size==world_zoom,"wheel zoom affects only preview")
 var press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true
 preview.handle_input(press)
 var motion=InputEventMouseMotion.new();motion.relative=Vector2(100,30);motion.button_mask=MOUSE_BUTTON_MASK_LEFT
 preview.handle_input(motion)
 var state=preview.view_state()
 check(absf(state.yaw-preview.DEFAULT_YAW)>0.1 and state.pitch!=preview.DEFAULT_PITCH,"drag rotates and tilts model view")
 var release=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false
 preview.handle_input(release)
 preview.handle_input(motion)
 check(preview.view_state()==state,"released drag no longer rotates")
 scene.find_child("EquipmentSlot_mainhand",true,false).pressed.emit()
 scene.find_child("EquipmentChoice_0",true,false).pressed.emit()
 scene.find_child("EquipmentConfirmation",true,false).confirmed.emit()
 await process_frame
 preview=scene.modal.find_child("EquipmentPreview",true,false)
 check(preview.pawn.get_meta("equipped_weapon","")=="sword","real equip callback updates preview immediately")
 check(preview.view_state()==state,"equip keeps camera angle and zoom")
 scene.campaign.equip_item(5,"hero");scene.campaign.equip_item(7,"hero");scene.show_party_menu("装备","hero")
 preview=scene.modal.find_child("EquipmentPreview",true,false)
 check(preview.pawn.find_child("EquippedOffhand",true,false)!=null and preview.pawn.find_child("EquippedArmor",true,false)!=null,"shield and plate appear")
 check(preview.view_state()==state,"armor change preserves view")
 scene.find_child("EquipmentSlot_mainhand",true,false).pressed.emit()
 button(scene.modal,"卸下当前主手").pressed.emit()
 scene.find_child("EquipmentConfirmation",true,false).confirmed.emit()
 await process_frame
 preview=scene.modal.find_child("EquipmentPreview",true,false)
 check(preview.pawn.find_child("EquippedMainhand",true,false)==null,"unequip removes preview weapon")
 scene.show_party_menu("装备","medic")
 preview=scene.modal.find_child("EquipmentPreview",true,false)
 check(preview.character_id=="medic" and preview.view_state().yaw==preview.DEFAULT_YAW,"new character starts with own view")
 scene.show_party_menu("装备","hero")
 preview=scene.modal.find_child("EquipmentPreview",true,false)
 check(preview.view_state()==state,"returning character restores view")
 for i in 100:preview.handle_input(wheel)
 check(preview.camera.size>=preview.MIN_ZOOM,"zoom in bounded")
 wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN
 for i in 100:preview.handle_input(wheel)
 check(preview.camera.size<=preview.MAX_ZOOM,"zoom out bounded")
 button(preview,"重置").pressed.emit()
 check(preview.view_state()=={"yaw":preview.DEFAULT_YAW,"pitch":preview.DEFAULT_PITCH,"zoom":preview.DEFAULT_ZOOM},"reset restores full body view")
 var weak_preview=weakref(preview)
 scene.show_party_menu("技能","hero");await process_frame
 check(scene.modal.find_child("EquipmentPreview",true,false)==null and weak_preview.get_ref()==null,"leaving equipment releases preview world")
 scene.queue_free();await process_frame
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
