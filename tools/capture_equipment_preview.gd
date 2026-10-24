extends SceneTree
func _initialize():call_deferred("run")
func capture(filename: String):
 for i in 12:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/"+filename+".png")
func run():
 root.size=Vector2i(1440,900)
 var scene=load("res://game/main.tscn").instantiate();root.add_child(scene);await process_frame
 scene.set_process(false);scene.close_modal()
 scene.campaign=load("res://game/campaign.gd").new("user://equipment-preview-capture-only.json")
 for pair in [[0,"hero"],[5,"hero"],[7,"hero"]]:scene.campaign.equip_item(pair[0],pair[1])
 scene.enter_campaign();scene.show_party_menu("装备","hero")
 await capture("equipment-preview-full")
 var preview=scene.modal.find_child("EquipmentPreview",true,false)
 preview.yaw=2.55;preview.pitch=0.16;preview.update_camera()
 await capture("equipment-preview-back")
 preview.yaw=0.55;preview.zoom=1.05;preview.update_camera()
 await capture("equipment-preview-close")
 quit()
