extends SceneTree
func _initialize():call_deferred("run")
func run():
 var scene=load("res://game/main.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 scene.campaign=load("res://game/campaign.gd").new("user://portrait-preview-unused.json")
 scene.show_party_menu("角色","hero")
 for i in range(20):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/party-cards.png")
 scene.show_deploy(0)
 for i in range(10):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/deployment-cards.png")
 quit()
