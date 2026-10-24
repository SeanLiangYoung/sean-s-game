extends SceneTree
func _initialize():call_deferred("run")
func capture(filename):
 for i in 10:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/"+filename+".png")
func run():
 root.size=Vector2i(1440,960)
 var scene=load("res://game/main.tscn").instantiate();root.add_child(scene);await process_frame
 scene.set_process(false);scene.close_modal()
 for region in ["border","wood","waste","frost","marsh","ruins"]:
  scene.battle=null
  scene.campaign=load("res://game/campaign.gd").new("user://regional-capture-"+region+".json")
  scene.campaign.rng.seed=21;scene.campaign.start_region(region)
  for pair in [[0,"hero"],[1,"blade"],[2,"ranger"],[3,"medic"],[4,"engineer"]]:scene.campaign.equip_item(pair[0],pair[1])
  var node=scene.campaign.route.nodes.filter(func(n):return n.get("threat","")=="boss")[0]
  scene.campaign.route.visited=[]
  for depth in range(node.depth):scene.campaign.route.visited.append(str(depth)+"a")
  scene.campaign.route.current=scene.campaign.route.visited[-1];scene.campaign.route.completed=true;scene.campaign.enter_route(node.id)
  scene.selected_ids=["hero","blade","ranger","medic","engineer"]
  scene.begin_battle(node.encounter);scene.close_modal()
  var boss=scene.battle.actors[-1]
  scene.battle.order_index=scene.battle.order.find(scene.battle.actors.find(boss));boss.ap=4
  scene.battle.enemy_step()
  scene.draw_battle();scene.refresh_ui();scene.set_game_hud_visible(true);scene.ui.show()
  scene.camera_zoom=16;scene.update_camera()
  await capture("region-"+region)
  if region=="ruins":
   scene.show_region_briefing();await capture("region-mechanics")
   scene.close_modal()
 scene.queue_free();await process_frame
 print("REGION_CAPTURES_READY");quit()
