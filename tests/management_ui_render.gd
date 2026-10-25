extends SceneTree
var s
func _initialize():call_deferred("run")
func capture(name):
 await process_frame;await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/management-"+name+".png")
func run():
 s=load("res://game/main.tscn").instantiate();root.add_child(s);await process_frame;s.set_process(false)
 s.settings_path="user://management-render.cfg";s.campaign=preload("res://game/campaign.gd").new("user://management-render.json")
 s.show_party_menu("详情","hero");await capture("character")
 s.modal.find_child("CharacterBiography",true,false).pressed.emit();await capture("biography");s.close_details()
 s.show_party_menu("装备","hero");await capture("equipment")
 s.campaign.books=["focus"];s.show_party_menu("技能","hero");await capture("skills")
 s.modal.find_child("SkillBooks",true,false).pressed.emit();await capture("books")
 s.show_party_menu("职业","medic");await capture("professions")
 s.campaign.depart();s.campaign.acquire_relic("candle","hero");s.campaign.acquire_relic("banner");s.campaign.acquire_relic("prism","medic")
 s.show_party_menu("遗物","hero");await capture("owned-relics")
 s.show_relic_catalog();await capture("catalog")
 s.show_relic_catalog("blood");await capture("catalog-filter")
 s.show_relic_catalog("","百战军册");await capture("catalog-search")
 s.campaign=preload("res://game/campaign.gd").new("user://management-render.json");s.campaign.rng.seed=71023;s.campaign.start_region("border")
 s.campaign.route.setup("border");s.campaign.encounters=["open","open","open"];s.campaign.enter_route("0b");s.campaign.silver=1000
 s.show_route_trade();await capture("shop")
 s.show_relic_binding("echo");await capture("binding")
 s.campaign.enter_route("1b");s.show_route_trade();await capture("hire")
 s.queue_free();await process_frame;DirAccess.remove_absolute("user://management-render.json")
 print("MANAGEMENT_UI_RENDER_OK");quit()
