extends SceneTree
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func texts(node):
 var result=""
 if node is Label or node is Button:result+=node.text+"\n"
 for child in node.get_children():result+=texts(child)
 return result
func button(node,needle):
 if node is Button and needle in node.text:return node
 for child in node.get_children():
  var found=button(child,needle)
  if found!=null:return found
 return null
func _initialize():call_deferred("run")
func run():
 var scene=load("res://game/main.tscn").instantiate();root.add_child(scene);await process_frame
 scene.set_process(false);scene.close_modal()
 scene.campaign=load("res://game/campaign.gd").new("user://progression-ui-test.json")
 scene.campaign.roster[1].xp=200
 scene.show_party_menu("技能","blade")
 check("可用经验 200" in texts(scene.modal) and "追斩" in texts(scene.modal) and "回旋刃" in texts(scene.modal),"tree displays both branches and balance")
 var node=scene.modal.find_child("SkillNode_execute",true,false)
 check(node!=null,"skills render as selectable tree nodes")
 if node==null:
  scene.queue_free();await process_frame
  print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1);return
 node.pressed.emit()
 check(scene.campaign.roster[1].xp==200,"selecting a node does not spend experience")
 check(button(scene.modal,"解锁追斩").disabled,"prerequisite visible and blocked")
 scene.modal.find_child("SkillNode_dash",true,false).pressed.emit()
 button(scene.modal,"强化掠影突袭").pressed.emit()
 check(scene.campaign.roster[1].xp==155 and "2 / 3级" in texts(scene.modal),"real UI upgrades and refreshes")
 scene.modal.find_child("SkillNode_execute",true,false).pressed.emit()
 button(scene.modal,"解锁追斩").pressed.emit()
 check(scene.campaign.roster[1].xp==125 and "execute" in scene.campaign.Professions.skills_for(scene.campaign.roster[1]),"real UI unlocks usable skill")
 scene.show_party_menu("技能","hero")
 var profession=scene.modal.find_child("SkillProfession_ranger",true,false)
 check(profession!=null,"hero can select profession trees")
 profession.pressed.emit()
 check(scene.modal.find_child("SkillNode_mark",true,false)!=null and scene.modal.find_child("SkillNode_dash",true,false)==null,"profession tabs show distinct profession skills")
 check(scene.campaign.roster[0].get("skill_ranks",{}).get("dash",0)==0,"another character keeps independent skill ranks")
 for job_id in scene.campaign.Professions.JOBS:
  scene.modal.find_child("SkillProfession_"+job_id,true,false).pressed.emit()
  for skill_id in scene.campaign.Professions.JOBS[job_id].skills:
   check(scene.modal.find_child("SkillNode_"+skill_id,true,false)!=null,"profession renders its own skill: "+skill_id)
 scene.show_party_menu("技能","blade")
 scene.campaign.roster[1].xp=0
 scene.modal.find_child("SkillNode_dash",true,false).pressed.emit()
 check(button(scene.modal,"强化掠影突袭").disabled and "经验不足" in texts(scene.modal),"insufficient experience blocks upgrading")
 scene.campaign.roster[1].skill_ranks.dash=3
 scene.modal.find_child("SkillNode_dash",true,false).pressed.emit()
 check(button(scene.modal,"已满级").disabled,"maximum rank cannot spend experience")
 var hero=scene.campaign.roster[0]
 hero.profession="blade"
 scene.show_party_menu("技能","hero")
 check(scene.modal.find_child("SkillNode_dash",true,false)!=null and scene.modal.find_child("SkillNode_execute",true,false)!=null and scene.modal.find_child("SkillNode_blade_sweep",true,false)!=null,"same profession shares the same skill tree")
 check(scene.campaign.Professions.skill_rank(hero,"dash")==0,"same profession keeps character progression independent")
 hero.profession="hero"
 scene.campaign.roster[1].skill_ranks.dash=2
 scene.campaign.roster[1].xp=200

 scene.campaign.depart();scene.selected_ids=["hero","blade"];scene.begin_battle(0)
 scene.show_party_menu("技能","blade")
 scene.modal.find_child("SkillNode_dash",true,false).pressed.emit()
 check(button(scene.modal,"强化掠影突袭").disabled,"battle cannot spend")
 scene.queue_free();await process_frame
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
