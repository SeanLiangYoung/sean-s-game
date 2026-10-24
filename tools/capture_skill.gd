extends SceneTree
func _initialize():call_deferred("run")
func run():
 var scene=load("res://game/main.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 await process_frame
 scene.close_modal()
 scene.campaign=load("res://game/campaign.gd").new("user://ashbound-skill-capture.json")
 scene.campaign.depart()
 scene.show_deploy(0)
 scene.begin_battle(0)
 scene.ui.show()
 scene.set_process(false)
 var actor=scene.battle.find_actor("ranger")
 scene.battle.order=[scene.battle.actors.find(actor)]
 scene.battle.order_index=0
 actor.cell=Vector2i(0,0)
 var target=scene.battle.find_actor("enemy0")
 target.cell=Vector2i(2,0)
 scene.draw_battle()
 scene.camera_zoom=12
 scene.update_camera()
 print("SKILL_ACCEPTED ",scene.perform_battle_action("skill",target.id))
 for i in range(25):
  scene.presentation.advance(1.0/60)
  await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/skill-charge.png")
 for i in range(25):
  scene.presentation.advance(1.0/60)
  await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/skill-release.png")
 print("SKILL_CAPTURES_READY")
 quit()
