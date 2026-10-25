extends SceneTree
var checks=0
var failures=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
 check(ResourceLoader.exists("res://tools/simulate_boss_balance.gd"),"paired boss study helper exists")
 if failures:quit(1);return
 var study=load("res://tools/simulate_boss_balance.gd")
 var relic=load("res://game/relics.gd")
 var jobs=load("res://game/professions.gd")
 var full=study.case_matrix(false)
 var quick=study.case_matrix(true)
 check(full.size()==360,"full study pairs six regions six seeds two resources five builds")
 check(quick.size()==90,"quick study pairs six regions three seeds five builds at full resources")
 for resource in ["full","depleted"]:
  var control=study.prepare_case("control",resource)
  check(control.relics.is_empty(),"baseline has zero relics")
  check(control.party.map(func(u):return u.id)==["hero","blade","ranger","medic","engineer"],"fixed party identities")
  for build in ["blood","hunt","ward","arcane"]:
   var setup=study.prepare_case(build,resource)
   check(setup.party==control.party,"relic builds have paired skills equipment and resources "+build)
   check(setup.relics.size()==4,"prepared build has exactly four relics "+build)
   var team=0;var personal=0
   for entry in setup.relics:
    if relic.definition(entry).scope=="team":team+=1;check(entry.owner=="","team relic has no personal owner")
    else:
     personal+=1
     check(entry.owner in ["hero","blade","ranger","medic","engineer"],"personal relic binds to deployed actor")
   check(team==3 and personal==1,"three team plus one personal relic "+build)
  for unit in control.party:
   check(unit.hp<=unit.max_hp and unit.mp<=unit.max_mp,"resources bounded without boosts")
   check(unit.ap==4 and unit.max_ap==4,"base AP is unmodified")
   check(unit.xp>=0,"legal training spends within budget")
   for id in jobs.JOBS[unit.profession].skills:
    if jobs.skill_rank(unit,id)==0:continue
    var prerequisite=jobs.prerequisite(id)
    check(prerequisite=="" or jobs.skill_rank(unit,prerequisite)>=2,"training prerequisites satisfied "+id)
 var a=study.prepare_case("blood","full")
 a.party[0].hp=1;a.relics[0].owner="wrong"
 var fresh=study.prepare_case("blood","full")
 check(fresh.party[0].hp==80 and fresh.relics[0].owner=="","each paired setup is independent")
 # A newly warned unit escapes and never voluntarily returns into the warning.
 var rules=load("res://game/rules.gd").new()
 rules.start_battle(study.prepare_case("control","full").party,2,[],{"biome":"ruins","seed":21,"threat":"boss"})
 var actor=rules.active()
 rules.boss_intents=[{"source":"enemy3","kind":"overload","cells":[actor.cell],"due":99,"phase":1}]
 var decision=study.decide(rules)
 check(decision.action=="move" and decision.target!=actor.cell,"policy dodges warned cell")
 check(rules.move_to(decision.target),"dodge pays legal movement cost")
 if rules.active().id==actor.id:
  var next=study.decide(rules)
  check(not(next.action=="move" and next.target in rules.boss_warnings()),"policy does not walk back into warning")
 # The control branch must use real AP/MP and must target the pending boss.
 var ranger=rules.find_actor("ranger")
 rules.order_index=rules.order.find(rules.actors.find(ranger));ranger.ap=4;ranger.mp=ranger.max_mp;ranger.used_skills=[]
 var boss=rules.find_actor("enemy3");boss.cell=Vector2i.ZERO;boss.statuses={}
 rules.boss_intents=[{"source":boss.id,"kind":"overload","cells":[Vector2i(4,0)],"due":99,"phase":1}]
 var control_decision=study.decide(rules)
 check(control_decision.get("skill","")=="ranger_pin" and control_decision.target==boss.id,"policy interrupts a pending ruins overload")
 var mp_before=ranger.mp;var ap_before=ranger.ap
 var real_mp_cost=rules.skill_mana_cost(ranger,"ranger_pin",boss.id)
 check(study.execute(rules,control_decision),"control skill uses legal action API")
 check(ranger.mp==mp_before-real_mp_cost and ranger.ap==ap_before-2,"control pays actual AP and MP")
 check(boss.statuses.has("stagger"),"control creates actual interrupt condition")
 var hashes=study.source_hashes()
 check(study.changed_sources(hashes).is_empty(),"current source fingerprint validates")
 hashes["game/rules.gd"]="stale fingerprint"
 check("game/rules.gd" in study.changed_sources(hashes),"source drift is rejected")
 var result=study.battle({"region":"border","seed":21,"resource":"full","build":"control"})
 for field in ["win","outcome","rounds","deaths","remaining_hp","remaining_mp","phase2_reached","invalid_actions"]:
  check(result.has(field),"per-case result records "+field)
 check(result.invalid_actions==0 and result.outcome!="step_limit","real smoke battle finishes without illegal actions")
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
