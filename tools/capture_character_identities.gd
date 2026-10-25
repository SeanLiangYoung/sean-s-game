extends SceneTree
func _initialize():call_deferred("run")
func capture(path):
 for i in range(15):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(path)
func run():
 var scene=load("res://game/main.tscn").instantiate();root.add_child(scene)
 await process_frame
 scene.set_process(false)
 scene.campaign=load("res://game/campaign.gd").new("user://identity-preview-unused.json")
 scene.show_captain_selection("wen")
 await capture("res://artifacts/captain-selection.png")
 scene.campaign.select_captain("wen")
 scene.enter_campaign()
 scene.show_party_menu("详情","hero")
 await capture("res://artifacts/character-biography-talent.png")
 scene.queue_free();await process_frame;quit()
