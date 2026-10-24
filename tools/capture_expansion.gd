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
 scene.campaign=load("res://game/campaign.gd").new("user://expansion-capture.json")
 scene.enter_campaign();scene.show_party_menu("技能","blade")
 await capture("expanded-skill-tree")
 scene.close_modal();scene.refresh_ui()
 await capture("expanded-regions")
 scene.campaign.rng.seed=12;scene.campaign.start_region("ruins");scene.refresh_ui()
 await capture("expanded-route")
 var shop=scene.campaign.route.nodes.filter(func(n):return n.depth==0 and n.kind=="shop")[0]
 scene.select_route_node(shop.id)
 await capture("expanded-shop")
 scene.close_modal()
 scene.campaign.equipment.append({"id":"runic_sword","owner":"hero"})
 scene.campaign.equipment.append({"id":"focus_guard","owner":"hero"})
 scene.campaign.equipment.append({"id":"bulwark_plate","owner":"hero"})
 scene.campaign.refresh_stats();scene.show_party_menu("装备","hero")
 await capture("expanded-build")
 scene.queue_free();await process_frame
 print("EXPANSION_CAPTURES_READY");quit()
