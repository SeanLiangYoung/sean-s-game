extends SceneTree
func _initialize():call_deferred("run")
func capture(path: String):
 for i in range(12):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(path)
func run():
 var scene=load("res://game/main.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 scene.set_process(false)
 scene.close_modal()
 scene.campaign=load("res://game/campaign.gd").new("user://skill-tree-visual-preview.json")
 scene.campaign.roster[1].xp=155
 scene.campaign.roster[1].skill_ranks.dash=2
 scene.enter_campaign()
 scene.show_party_menu("技能","blade")
 await capture("res://artifacts/skill-tree.png")
 scene.modal.find_child("SkillNode_execute",true,false).pressed.emit()
 await capture("res://artifacts/skill-tree-branch.png")
 scene.show_party_menu("技能","hero")
 scene.modal.find_child("SkillProfession_ranger",true,false).pressed.emit()
 await capture("res://artifacts/skill-tree-professions.png")
 scene.queue_free()
 await process_frame
 quit()
