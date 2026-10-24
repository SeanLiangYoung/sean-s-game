extends SceneTree
func _initialize():call_deferred("run")
func capture(name: String):
 for i in range(8):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/"+name+".png")
func run():
 var scene=load("res://game/main.tscn").instantiate();root.add_child(scene);await process_frame
 scene.set_process(false)
 scene.campaign=load("res://game/campaign.gd").new("user://relic-build-capture.json")
 scene.enter_campaign();scene.campaign.depart()
 for id in ["blood_1","blood_2","blood_3"]:scene.campaign.acquire_relic(id)
 scene.campaign.acquire_relic("blood_6","hero")
 scene.show_party_menu("遗物","hero");await capture("relic-build-resonance")
 scene.show_relic_catalog("ward");await capture("relic-build-catalog")
 scene.campaign.equipment.append({"id":"runic_sword","owner":"hero"})
 scene.campaign.refresh_stats();scene.show_party_menu("装备","hero");await capture("equipment-basic-tiers")
 scene.campaign.phase="reward";scene.campaign.choices=[]
 for id in ["hunt_1","ward_1","arcane_6","runic_sword","silver"]:
  scene.campaign.choices.append(scene.campaign.REWARDS.filter(func(r):return r.id==id)[0].duplicate(true))
 scene.show_reward();await capture("relic-five-choices")
 scene.queue_free();await process_frame
 quit()
