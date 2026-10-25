extends SceneTree
const Campaign=preload("res://game/campaign.gd")
var checks=0
var failures=0
func check(ok: bool,label: String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label)
func texts(node) -> String:
 var result=node.text+"\n" if node is Label or node is Button else ""
 for child in node.get_children():result+=texts(child)
 return result
func _initialize():call_deferred("run")
func run():
 var path="user://relic-discovery-ui.json"
 for suffix in ["",".relics",".achievements"]:DirAccess.remove_absolute(path+suffix)
 var s=load("res://game/main.tscn").instantiate();root.add_child(s);await process_frame;s.set_process(false)
 s.campaign=Campaign.new(path)
 s.show_relic_catalog("","余烬徽印")
 check("余烬徽印" not in texts(s.modal),"search cannot reveal unseen relic")
 check(s.campaign.discovered_relics.is_empty(),"catalog browsing never discovers")
 s.campaign.phase="reward"
 s.campaign.choices=[Campaign.REWARDS.filter(func(r):return r.id=="ember")[0]]
 s.show_reward()
 check(s.campaign.discovered_relics==["ember"] and s.campaign.relics.is_empty(),"displayed reward discovers without acquisition")
 s.show_relic_catalog()
 check("余烬徽印" in texts(s.modal) and "旧世泉核" not in texts(s.modal),"only seen relic revealed")
 s.show_achievements()
 check("初识遗物" in texts(s.modal) and "遗物收集成就 · 已解锁 1 / 4" in texts(s.modal),"discovery achievement visible")
 check("100" in texts(s.modal) and "解锁全部遗物" in texts(s.modal),"all milestones listed")
 s.campaign.phase="camp"
 s.campaign.start_region("border");s.campaign.route.setup("border",71023);s.campaign.encounters=["open","open","open"];s.campaign.enter_route("0b")
 s.show_route_trade("遗物")
 check(not s.campaign.shop_inventory().is_empty(),"shop encounter has stock")
 for id in s.campaign.shop_inventory():
  if Campaign.Relic.CATALOG.has(id):check(id in s.campaign.discovered_relics,"displayed shop relic discovered")
 s.show_relic_catalog()
 if "--capture-discovery" in OS.get_cmdline_user_args():
  await process_frame;await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://artifacts/relic-discovery-catalog.png")
  s.show_achievements();await process_frame
  for scroll in s.modal.find_children("*","ScrollContainer",true,false):scroll.scroll_vertical=10000
  await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://artifacts/relic-discovery-achievements.png")
 s.queue_free();await process_frame
 for suffix in ["",".relics",".achievements"]:DirAccess.remove_absolute(path+suffix)
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
