extends SceneTree
const Campaign=preload("res://game/campaign.gd")
const Visual=preload("res://game/character_visual.gd")
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
 scene.set_process(false);scene.close_modal();scene.campaign=Campaign.new("user://expansion-ui.json")
 scene.show_settings(false)
 check("六档递进难度" in texts(scene.modal) and "第 1 / 6 档" in texts(scene.modal),"settings explain progression difficulty")
 scene.close_modal()
 scene.depart() # The camp now opens the village; map checks follow its expedition action.
 check("第 1 / 6 档" in texts(scene.atlas),"map shows initial difficulty")
 check("星陨遗城（0/5）" in texts(scene.atlas),"map shows final region lock progress")
 scene.show_region("ruins")
 check(not is_instance_valid(scene.modal),"locked region cannot open departure dialog")
 scene.show_party_menu("技能","blade");await process_frame;await process_frame
 var tree=scene.modal.find_child("SkillTreeCanvas",true,false)
 var rects=[]
 check(tree.nodes.size()==6,"all six skill nodes rendered")
 for node in tree.nodes:
  check(node.size.x>=110 and node.size.y>=90,"skill node has usable dimensions")
  check(node.position.x>=0 and node.position.y>=0 and node.position.x+node.size.x<=tree.size.x+1 and node.position.y+node.size.y<=tree.size.y+1,"skill node contained in tree")
  for rect in rects:check(not rect.intersects(node.get_rect()),"tree nodes do not overlap")
  rects.append(node.get_rect())
 scene.modal.find_child("SkillNode_blade_drain",true,false).pressed.emit()
 check(scene.modal.find_child("SelectedSkillDetails",true,false)!=null,"advanced skill inspector opens")
 scene.close_modal();scene.campaign.cleared_regions=["border","wood","waste","frost","marsh"];scene.campaign.start_region("ruins");scene.refresh_ui();await process_frame
 for n in scene.campaign.route.nodes:
  var pos=scene.atlas.node_position(n)
  check(pos.x>=100 and pos.x<=1080,"all stages fit before map sidebar")
 var shop=scene.campaign.route.nodes.filter(func(n):return n.depth==0 and n.kind=="shop")[0]
 scene.select_route_node(shop.id)
 check(scene.campaign.shop_inventory().size()==7,"shop UI uses generated inventory")
 var pawn=Node3D.new();root.add_child(pawn)
 Visual.create(pawn,"hero",{"appearance":"hero","mainhand":"runic_sword","offhand":"focus_guard","armor":"bulwark_plate"})
 var skeleton=pawn.find_child("Skeleton3D",true,false)
 for pair in [["EquippedMainhand","runic_sword"],["EquippedOffhand","focus_guard"],["EquippedArmor","bulwark_plate"]]:
  var part=skeleton.get_node_or_null(pair[0]);check(part!=null and part.get_meta("item_id","")==pair[1],"variant visible on character: "+pair[1])
 check(pawn.get_meta("equipped_weapon","")=="sword","variant uses family animation")
 scene.close_modal();scene.campaign.phase="camp"
 scene.campaign.equipment.append({"id":"runic_sword","owner":"hero"});scene.campaign.equipment.append({"id":"focus_guard","owner":"hero"})
 scene.campaign.refresh_stats();scene.show_party_menu("装备","hero")
 check("基础装备" in texts(scene.modal),"equipment page explains basic tiers")
 pawn.queue_free();scene.queue_free();await process_frame
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
