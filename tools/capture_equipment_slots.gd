extends SceneTree
func _initialize():call_deferred("run")
func capture(filename):
 for i in 12:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/"+filename+".png")
func run():
 root.size=Vector2i(1280,832)
 var scene=load("res://game/main.tscn").instantiate();root.add_child(scene);await process_frame
 scene.set_process(false);scene.close_modal()
 scene.campaign=load("res://game/campaign.gd").new("user://equipment-slots-capture.json")
 scene.campaign.equip_item(3,"medic");scene.campaign.equip_item(6,"medic")
 scene.enter_campaign();scene.show_party_menu("装备","medic")
 await capture("equipment-slots")
 scene.find_child("EquipmentSlot_armor",true,false).pressed.emit()
 await capture("equipment-slot-choices")
 scene.find_child("EquipmentChoice_7",true,false).pressed.emit()
 await capture("equipment-slot-confirmation")
 quit()
