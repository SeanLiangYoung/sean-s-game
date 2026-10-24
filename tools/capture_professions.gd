extends SceneTree
func _initialize():call_deferred("run")
func capture(name: String):
 for i in range(12):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/"+name+".png")
func run():
 var scene=load("res://game/main.tscn").instantiate()
 root.add_child(scene);await process_frame
 scene.set_process(false)
 scene.campaign=load("res://game/campaign.gd").new("user://profession-capture-only.json")
 scene.enter_campaign()
 scene.show_party_menu("职业","medic")
 await capture("profession-retraining")
 scene.show_party_menu("装备","medic")
 var scroll=scene.modal.find_child("CharacterPageScroll",true,false)
 for i in range(4):await process_frame
 scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value)
 await capture("profession-equipment")
 scene.campaign.equip_item(0,"hero")
 scene.show_party_menu("职业","hero")
 await capture("profession-hero")
 scene.close_modal();scene.campaign.depart();scene.selected_ids=["engineer","hero","medic","warden","ranger"];scene.begin_battle(0)
 scene.battle.order_index=scene.battle.order.find(0)
 scene.select_action("skills")
 await capture("profession-skills")
 quit()
