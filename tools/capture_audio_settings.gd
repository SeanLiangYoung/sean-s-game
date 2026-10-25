extends SceneTree
func _initialize():call_deferred("run")
func run():
 var scene=load("res://game/main.tscn").instantiate()
 scene.settings_path="user://audio-settings-capture-only.cfg"
 root.add_child(scene);await process_frame
 scene.set_process(false)
 scene.sfx_enabled=true;scene.sfx_volume=0.4
 scene.show_settings(true)
 for i in range(12):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/audio-settings.png")
 scene.queue_free();await process_frame;quit()
