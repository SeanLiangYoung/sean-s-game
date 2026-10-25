extends SceneTree
func _initialize():call_deferred("run")
func run():
 var scene=load("res://game/main.tscn").instantiate();root.add_child(scene);await process_frame
 scene.set_process(false)
 scene.campaign=load("res://game/campaign.gd").new("user://achievement-capture-only.json")
 scene.campaign.completed_difficulties=[0,1]
 scene.campaign.overall_difficulty=2
 scene.campaign.cleared_regions=["border","wood","waste"]
 scene.enter_campaign();scene.show_achievements(false)
 for i in range(12):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/achievements.png")
 scene.queue_free();await process_frame;quit()
