extends SceneTree
func _initialize():call_deferred("run")
func capture(filename):
 for i in 8:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/"+filename+".png")
func run():
 root.size=Vector2i(1440,960)
 var scene=load("res://game/main.tscn").instantiate();root.add_child(scene);await process_frame
 scene.set_process(false);scene.close_modal()
 for region in ["border","wood","waste","frost","marsh","ruins"]:
  scene.battle=null;scene.campaign=load("res://game/campaign.gd").new("user://boss-capture-"+region+".json");scene.campaign.rng.seed=21;scene.campaign.start_region(region)
  var node=scene.campaign.route.nodes.filter(func(n):return n.get("threat","")=="boss")[0]
  scene.campaign.route.visited=[]
  for depth in range(node.depth):scene.campaign.route.visited.append(str(depth)+"a")
  scene.campaign.route.current=scene.campaign.route.visited[-1];scene.campaign.route.completed=true;scene.campaign.enter_route(node.id)
  scene.selected_ids=["hero","blade","ranger","medic","engineer"];scene.begin_battle(node.encounter);scene.close_modal()
  var b=scene.battle;var boss=b.actors[-1]
  scene.set_game_hud_visible(true);scene.ui.show()
  await capture("boss-"+region+"-phase1")
  b.lose_hp(boss,int(ceil(boss.max_hp*0.5)));scene.draw_battle();scene.refresh_ui()
  await capture("boss-"+region+"-phase2")
  b.order_index=b.order.find(b.actors.find(boss));boss.ap=4;boss.enemy_used=false;boss.cooldowns={};boss.boss_prepared=false
  scene.draw_battle();scene.refresh_ui()
  # Ensure primary windup is shown even when the AI would prefer low-health support.
  var before=b.actors.duplicate(true);var cue_start=b.boss_cues.size()
  b.cast_enemy_skill(b.enemy_skills(boss)[0])
  scene.presentation.start(scene,before,b.actors.duplicate(true),boss.id,"boss_charge",[],"",b.boss_cues.slice(cue_start))
  scene.presentation.advance(0.15)
  await capture("boss-"+region+"-charge")
  scene.presentation.advance(3)
  before=b.actors.duplicate(true);cue_start=b.boss_cues.size();b.begin_turn(boss)
  scene.presentation.start(scene,before,b.actors.duplicate(true),boss.id,"boss_release",[],"",b.boss_cues.slice(cue_start))
  scene.presentation.advance(0.48)
  await capture("boss-"+region+"-release")
  scene.presentation.advance(3)
  if region=="ruins":
   boss.enemy_used=false;boss.cooldowns={};boss.boss_prepared=false;boss.ap=4;b.order_index=b.order.find(b.actors.find(boss))
   b.cast_enemy_skill(b.enemy_skills(boss)[0]);b.put_status(boss,"stagger","hero")
   before=b.actors.duplicate(true);cue_start=b.boss_cues.size();b.begin_turn(boss)
   scene.presentation.start(scene,before,b.actors.duplicate(true),boss.id,"boss_interrupt",[],"",b.boss_cues.slice(cue_start));scene.presentation.advance(0.48)
   await capture("boss-ruins-interrupt");scene.presentation.advance(3)
  scene.show_region_briefing();await capture("boss-"+region+"-skills");scene.close_modal()
 scene.queue_free();await process_frame;print("BOSS_CAPTURES_READY");quit()
