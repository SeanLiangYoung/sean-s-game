extends SceneTree
func _initialize():call_deferred("run")
func run():
 var scene=load("res://game/main.tscn").instantiate();root.add_child(scene);await process_frame
 scene.set_process(false)
 scene.campaign=load("res://game/campaign.gd").new("user://achievement-popup-capture-only.json")
 scene.campaign.phase="reward"
 scene.campaign.choices=scene.campaign.REWARDS.slice(0,5).duplicate(true)
 scene.enter_campaign();scene.show_achievement_unlock(0)
 await create_timer(0.16).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/achievement-unlock-burst.png")
 preload("res://game/achievement_celebration.gd").chime().save_to_wav("res://artifacts/achievement-unlock.wav")
 await create_timer(0.8).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/achievement-unlock-popup.png")
 scene.queue_free();await process_frame;quit()
