extends SceneTree
const Campaign=preload("res://game/campaign.gd")
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func texts(node):
 var result=node.text+"\n" if node is Label or node is Button else ""
 for child in node.get_children():result+=texts(child)
 return result
func _initialize():call_deferred("run")
func run():
 var scene=load("res://game/main.tscn").instantiate();root.add_child(scene);await process_frame
 scene.set_process(false);scene.close_modal()
 check(scene.has_method("refresh_boss_hud"),"dedicated phase HUD exists")
 if not scene.has_method("refresh_boss_hud"):
  scene.queue_free();await process_frame;finish();return
 for region in ["border","wood","waste","frost","marsh","ruins"]:
  scene.battle=null;scene.campaign=Campaign.new("user://boss-presentation-"+region+".json");scene.campaign.cleared_regions=(["border","wood","waste","frost","marsh"] if region=="ruins" else []);scene.campaign.rng.seed=71023;scene.campaign.start_region(region)
  var node=scene.campaign.route.nodes.filter(func(n):return n.get("threat","")=="boss")[0]
  scene.campaign.route.current=node.id;scene.campaign.route.completed=false
  scene.show_deploy(node.encounter)
  var intel=scene.modal.find_children("*","Button",true,false).filter(func(entry):return "敌情与战场规则" in entry.text)
  check(not intel.is_empty(),"deployment exposes enemy intel details")
  intel[0].pressed.emit()
  check("随机强化" in texts(scene.detail_overlay) and "无耗蓝" in texts(scene.detail_overlay),"deployment details preserve affix and enemy skills")
  scene.close_details()
  scene.begin_battle(node.encounter);scene.close_modal()
  var boss=scene.battle.actors[-1]
  check(scene.ui.find_child("BossHUD",true,false)!=null and "50%" in texts(scene.ui.find_child("BossHUD",true,false)),"boss HUD states threshold")
  var pawn=scene.scene_root.get_node("Character_"+boss.id)
  check(pawn.find_child("BossMountTorso",true,false)!=null,"boss ornaments follow skeleton")
  scene.battle.order_index=scene.battle.order.find(scene.battle.actors.find(boss));boss.ap=4
  scene.draw_battle();var before=scene.battle.actors.duplicate(true)
  check(scene.perform_battle_action("enemy"),"boss prepares via actual scene command")
  check(scene.presentation.boss_cues.size()>0 and scene.presentation.boss_cues[0].type=="charge","structured charge reaches presentation "+region)
  scene.presentation.advance(0.55)
  check(scene.presentation.find_children("BossCue*","",true,false).size()>0,"charge has visible per-region effects "+region)
  scene.presentation.advance(3)
  check(scene.battle.actors[-1].hp==before[-1].hp,"playback does not mutate boss HP")
  var frozen=scene.battle.boss_intents.duplicate(true)
  scene.battle.lose_hp(boss,int(ceil(boss.max_hp*0.5)))
  scene.draw_battle();scene.refresh_ui()
  check("Ⅱ" in texts(scene.ui.find_child("BossHUD",true,false)),"phase HUD updates")
  check(scene.battle.boss_intents==frozen,"phase redraw leaves old warning unchanged")
  check(scene.scene_root.get_node("Character_"+boss.id).find_child("PhaseTwoFlare0",true,false)!=null,"phase two silhouette changes")
  scene.show_region_briefing();var brief=texts(scene.modal)
  check("主动技能" in brief and "被动" in brief and "随机强化" in brief,"combat encyclopedia exposes skills/passive/affix")
  scene.close_modal()
 # Release on someone else's end action is still shown using the boss as cue source.
 var b=scene.battle;var boss=b.actors[-1];var hero=b.find_actor("hero")
 b.boss_intents=[];boss.cooldowns={};boss.enemy_used=false;boss.boss_prepared=false;boss.ap=4
 b.order_index=b.order.find(b.actors.find(boss));b.cast_enemy_skill(b.enemy_skills(boss)[0])
 b.order=[b.actors.find(hero),b.actors.find(boss)];b.order_index=0;hero.ap=4
 scene.draw_battle();check(scene.perform_battle_action("end"),"ending hero turn resolves queued boss spell")
 check(scene.presentation.boss_cues.any(func(c):return c.type=="release" and c.source==boss.id),"release cue preserves different actual source")
 var saved=b.actors.duplicate(true);scene.presentation.advance(3)
 check(b.actors==saved,"release playback doesn't mutate rule state")
 # Enemy dash animation must reach its real landing before the damage impact.
 scene.battle=null;scene.campaign=Campaign.new("user://enemy-dash-visual.json");scene.campaign.start_region("wood")
 var encounter=scene.campaign.route.nodes.filter(func(n):return n.kind=="battle")[0]
 scene.campaign.route.current=encounter.id;scene.campaign.route.completed=false
 scene.selected_ids=["hero"];scene.begin_battle(encounter.encounter);scene.close_modal()
 b=scene.battle
 var ambusher=b.actors.filter(func(u):return u.get("trait","")=="ambush")[0]
 hero=b.find_actor("hero");ambusher.cell=Vector2i.ZERO;ambusher.range=1;hero.cell=Vector2i(2,0);hero.hp=1;b.obstacles=[]
 for u in b.actors:
  if u.id not in [hero.id,ambusher.id]:u.hp=0
 b.order_index=b.order.find(b.actors.find(ambusher));ambusher.ap=4;ambusher.enemy_used=false;ambusher.cooldowns={}
 scene.draw_battle();var origin=scene.scene_root.get_node("Character_"+ambusher.id).position
 check(scene.perform_battle_action("enemy"),"enemy dash accepted through scene")
 scene.presentation.advance(0.2)
 check(not scene.presentation.source.position.is_equal_approx(origin),"enemy dash visibly moves before impact")
 scene.presentation.advance(0.25)
 check(scene.presentation.source.position.is_equal_approx(scene.cell_position(ambusher.cell)),"enemy dash lands before damage feedback")
 scene.presentation.advance(3)
 scene.queue_free();await process_frame;finish()
func finish():
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
