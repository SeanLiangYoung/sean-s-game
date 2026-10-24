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
 scene.campaign=load("res://game/campaign.gd").new("user://relic-capture-only.json")
 scene.enter_campaign()
 scene.campaign.depart()
 scene.campaign.acquire_relic("banner")
 scene.campaign.acquire_relic("candle","hero")
 scene.campaign.acquire_relic("echo","medic")
 scene.show_party_menu("遗物","hero")
 await capture("relic-world")
 scene.show_party_menu("装备","hero")
 await capture("relic-slot")
 scene.campaign.phase="reward"
 scene.campaign.choices=[scene.campaign.REWARDS.filter(func(r):return r.id=="echo")[0]]
 scene.show_relic_binding("echo",0)
 await capture("relic-binding")
 quit()
