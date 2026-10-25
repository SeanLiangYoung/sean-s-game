extends SceneTree
func _initialize():call_deferred("run")
func run():
 var s=load("res://game/main.tscn").instantiate();root.add_child(s);await process_frame
 var review="--review-village" in OS.get_cmdline_user_args()
 var ok=s.campaign.save_path==("user://ashbound-village-review.json" if review else "user://ashbound-save.json") and s.settings_path==("user://ashbound-village-review-settings.cfg" if review else "user://ashbound-settings.cfg")
 s.queue_free();await process_frame
 print("CHECKS: 1 FAILURES: %d"%[0 if ok else 1]);quit(0 if ok else 1)
