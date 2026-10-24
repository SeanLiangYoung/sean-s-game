extends SceneTree
const Campaign=preload("res://game/campaign.gd")
var failures=0
func check(ok,message):
 if not ok:failures+=1;print("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
 var scene=load("res://game/main.tscn").instantiate()
 root.add_child(scene);await process_frame
 scene.set_process(false);scene.close_modal()
 scene.campaign=Campaign.new("user://equipment-slots-test.json")
 scene.enter_campaign();scene.show_party_menu("装备","hero")
 var slot=scene.find_child("EquipmentSlot_mainhand",true,false)
 check(slot!=null,"vertical mainhand slot exists")
 if slot==null:scene.queue_free();await process_frame;quit(1);return
 check(slot.icon!=null and slot.tooltip_text!="","slot has icon and hover details")
 var before=scene.campaign.equipment.duplicate(true)
 slot.pressed.emit();await process_frame
 var choices=scene.find_child("EquipmentChoices",true,false)
 check(choices!=null,"click opens type choices")
 check(choices.find_child("EquipmentChoice_5",true,false)==null,"mainhand excludes shield")
 var choice=choices.find_child("EquipmentChoice_2",true,false)
 choice.pressed.emit();await process_frame
 check(scene.campaign.equipment==before,"selection does not change equipment")
 var dialog=scene.find_child("EquipmentConfirmation",true,false)
 check(dialog!=null and dialog.visible,"confirmation opens")
 check(dialog.find_child("StatChange_power",true,false)!=null,"confirmation shows attribute changes")
 dialog.canceled.emit();dialog.hide();await process_frame
 check(scene.campaign.equipment==before,"cancel preserves equipment")
 choice.pressed.emit();await process_frame
 dialog=scene.find_child("EquipmentConfirmation",true,false)
 dialog.confirmed.emit();await process_frame
 check(scene.campaign.equipment[2].owner=="hero","confirm equips chosen item")
 scene.find_child("EquipmentSlot_mainhand",true,false).pressed.emit();await process_frame
 scene.find_child("EquipmentRemove_mainhand",true,false).pressed.emit();await process_frame
 check(scene.campaign.equipment[2].owner=="hero","removal awaits confirmation")
 scene.find_child("EquipmentConfirmation",true,false).confirmed.emit();await process_frame
 check(scene.campaign.equipped_index("hero","mainhand")==-1,"confirmed removal clears slot")
 scene.campaign.equip_item(3,"medic")
 scene.find_child("EquipmentSlot_mainhand",true,false).pressed.emit();await process_frame
 scene.find_child("EquipmentChoice_3",true,false).pressed.emit();await process_frame
 dialog=scene.find_child("EquipmentConfirmation",true,false)
 check(dialog.find_children("StatChange_heal_bonus","Label",true,false).size()==2,"transfer previews both characters including healing")
 check(scene.campaign.equipment[3].owner=="medic","transfer waits for confirmation")
 dialog.confirmed.emit();await process_frame
 check(scene.campaign.equipment[3].owner=="hero" and scene.campaign.equipped_index("medic")==-1,"confirmed transfer updates both owners")
 scene.campaign.roster[0].hp=0
 scene.show_party_menu("装备","hero")
 scene.find_child("EquipmentSlot_armor",true,false).pressed.emit();await process_frame
 check(scene.find_child("EquipmentChoice_7",true,false).disabled,"dead character cannot equip")
 scene.queue_free();await process_frame
 print("FAILURES: ",failures);quit(1 if failures else 0)
