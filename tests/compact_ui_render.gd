extends SceneTree
var scene
func _initialize():call_deferred("run")
func capture(name):
 await process_frame;await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/ui-compact-"+name+".png")
func run():
 scene=load("res://game/main.tscn").instantiate();root.add_child(scene);await process_frame
 scene.set_process(false)
 scene.settings_path="user://compact-render.cfg"
 scene.campaign=preload("res://game/campaign.gd").new("user://compact-render.json")
 scene.show_captain_selection()
 await capture("newgame")
 scene.close_modal();scene.session_started=true;scene.set_game_hud_visible(true)
 scene.campaign.depart();scene.show_deploy(0)
 await capture("deploy")
 scene.begin_battle(0)
 await capture("battle")
 scene.select_action("skills")
 await capture("skills")
 scene.battle.active().hp-=5;scene.battle.active().mp-=5
 scene.select_action("rest")
 await capture("rest")
 scene.select_action("move")
 var actor=scene.battle.active();var target=actor.cell
 for cell in scene.battle.cells():
  var preview=scene.movement_preview(cell)
  if not preview.is_empty() and preview.remaining==0:target=cell;break
 scene.update_movement_preview(scene.camera.unproject_position(scene.cell_position(target)))
 await capture("move")
 scene.show_details("角色状态与共鸣","可查看完整说明；返回保留原选择。\n\n"+scene.battle.status_text(actor)+"\n"+scene.Campaign.Relic.resonance_description(scene.battle.applicable_relics(actor)))
 await capture("details")
 scene.close_details()
 scene.battle.find_actor("blade").hp=0;scene.battle.outcome="victory"
 scene.after_battle_action()
 await capture("reward")
 scene.battle=null;scene.campaign.phase="camp";scene.show_party_menu("装备","hero")
 var slot=scene.modal.find_child("EquipmentSlot_mainhand",true,false);slot.pressed.emit()
 await capture("equipment")
 scene.queue_free();await process_frame
 DirAccess.remove_absolute("user://compact-render.json")
 print("COMPACT_UI_RENDER_OK");quit()
