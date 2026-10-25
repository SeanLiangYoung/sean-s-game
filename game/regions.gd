extends RefCounted
# Combat, preparation screens and scenery share these region identities.
const CATALOG={
 "border":{"name":"灰潮边境","theme":"断桥哨站","ground":"788050","tile":"859358","accent":"d6aa66","sky":"b6c7bc","light":"ffe9bc","enemies":[["哨站斥候","spotter","enemy2","crossbow"],["灰巢盾卒","formation","enemy0","sword"]],"boss":"灰潮督军","boss_trait":"formation","intent":"号令齐射","kind":"command","damage":0,"debuff":"mark","counter":"盾卒相邻时减伤，斥候会标记。用突进拆阵、净护清标记，援护与高档木盾保护集火目标。","boss_tip":"督军预告两格号令；下次自身行动标记仍在格中的友军，并强化至多两名敌人的下一击。移出预告格或及时净护。"},
 "wood":{"name":"苍翠林海","theme":"密林石环","ground":"304c38","tile":"52734b","accent":"90c273","sky":"7b9f8a","light":"bce1b4","enemies":[["林荫伏弓","camouflage","enemy2","bow"],["棘影刺客","ambush","enemy1","dagger"]],"boss":"古林守望","boss_trait":"camouflage","intent":"缚根生长","kind":"roots","damage":6,"debuff":"snare","counter":"伏弓抵挡远距直伤；标记、近身和机关可以克制。近战武器、静观瞳石或缚潮齿轮各有发挥。","boss_tip":"守望预告至多三格藤根，下次自身行动造成6基础伤害并束缚：下一次移动首格多花1行动点。可提前移开或用净护解束缚。"},
 "waste":{"name":"赤砂荒原","theme":"沙丘商寨","ground":"b28a57","tile":"b99b66","accent":"ed9b50","sky":"d9b48a","light":"ffcf91","enemies":[["砂丘掠弩","sapper","enemy2","crossbow"],["赤砂狂刃","raider","enemy1","sword"]],"boss":"赤砂军阀","boss_trait":"raider","intent":"穿沙长矛","kind":"sandline","damage":10,"debuff":"","counter":"狂刃半血后普攻+3，掠弩每次行动首次伤害耗蓝2。用钉足箭控制、追斩收割；远程武器便于保持间距，孤影与血契遗物帮助收割。","boss_tip":"军阀预告一条最多五格的沙矛路径，下次自身行动造成10基础伤害并耗蓝2。侧向移动避开整条射线，勿沿线扎堆。"},
 "frost":{"name":"霜脊山隘","theme":"雪线烽台","ground":"b6cbd0","tile":"a5bec7","accent":"90d5ef","sky":"a8bccf","light":"d1e8ff","enemies":[["雪隘寒弩","frostshot","enemy2","bow"],["霜甲戍卫","frost_armor","enemy0","sword"]],"boss":"霜脊统领","boss_trait":"ice_king","intent":"寒潮裂隙","kind":"cold","damage":8,"debuff":"chill","counter":"霜甲每次自身行动间首个直伤减4；破甲与机关可克制。寒弩首次伤害附寒冷，净护解除；木盾和板甲提升基础防护，护生石强化护盾。","boss_tip":"统领每次行动恢复10点冰盾，破甲可阻止续盾；预告至多三格寒潮，下次行动造成8基础伤害和寒冷。寒冷与盾击合计最多削减1行动点。"},
 "marsh":{"name":"暮雾沼泽","theme":"幽沼枯木","ground":"4c6558","tile":"617a66","accent":"bad578","sky":"8daba6","light":"cee1cb","enemies":[["雾沼毒弓","venom","enemy2","bow"],["噬生潜猎者","mirehide","enemy1","dagger"]],"boss":"暮雾猎王","boss_trait":"venom","intent":"腐花绽放","kind":"bloom","damage":6,"debuff":"poison","counter":"毒弓首次伤害施加两次毒伤，潜猎者普攻吸取实际伤害20%生命。净护清毒，护盾挡住攻击可防附毒；治疗、调息与续航遗物减少损耗。","boss_tip":"猎王预告至多三格腐花，下次行动造成6基础伤害并附两次毒伤；每次毒伤基础2，不叠层。可避开、护盾抵挡或用净护解除。"},
 "ruins":{"name":"星陨遗城","theme":"遗械回廊","ground":"4e5967","tile":"647489","accent":"9dc8ed","sky":"899cac","light":"c6d9ff","enemies":[["遗械汲能者","drainer","enemy2","crossbow"],["城心构装卫","capacitor","enemy0","sword"]],"boss":"星陨监守","boss_trait":"core","intent":"星核过载","kind":"overload","damage":12,"debuff":"","counter":"构装卫每次行动补6点屏障，破甲阻止续盾；汲能者普攻首次伤害耗蓝3，主动吸能造成生命伤害时耗蓝4、护盾全挡时仍耗蓝1。机关消耗屏障，远程武器、军心回响与收割骨笛维持法力。","boss_tip":"监守每次行动补10点屏障；过载预告至多三格，下次行动造成12基础伤害并耗蓝4。钉足箭、盾击或震慑重击可在结算前打断过载。"}}
const TRAITS={
 "formation":"结阵：相邻存活同伴时，直接伤害减2；机关不受此减伤。",
 "spotter":"指认：每次自身行动首次造成生命伤害后标记目标，至自身下次行动。",
 "camouflage":"伏隐：3格及以外直接伤害减4；被标记或破甲后失效，机关绕过。",
 "ambush":"伏击：对满生命目标的普通攻击+3。",
 "raider":"狂战：半血及以下时普通攻击+3。",
 "sapper":"掠能：每次自身行动首次造成生命伤害额外耗目标2法力。",
 "frost_armor":"霜甲：每次自身行动间首次直接受伤减4；破甲或机关绕过。",
 "frostshot":"寒矢：每次自身行动首次造成生命伤害附寒冷，目标下次行动少1点。",
 "ice_king":"冰冠：每次行动补10点冰盾；破甲时无法续盾。",
 "venom":"毒刃：每次自身行动首次造成生命伤害附两次基础2毒伤，不叠层。",
 "mirehide":"噬生：普通攻击恢复实际生命伤害的20%。",
 "capacitor":"蓄能甲：每次行动补6点屏障；破甲时无法续盾。",
 "drainer":"汲能：每次自身行动首次造成生命伤害额外耗目标3法力。",
 "core":"星核屏障：每次行动补10点屏障；破甲时无法续盾，盾击可打断过载。"}
static func definition(id: String) -> Dictionary:
 return CATALOG.get(id,CATALOG.border)
static func trait_description(id: String) -> String:
 return TRAITS.get(id,"")
static func enemy_profile(unit: Dictionary) -> Dictionary:
 var region=definition(unit.get("biome","border"))
 var ranged=unit.get("archetype","")==region.enemies[0][0] if unit.has("archetype") else unit.get("range",1)>1
 var row=region.enemies[0 if ranged else 1]
 var weapon=row[3]
 if unit.get("boss",false):weapon="staff" if unit.biome in ["wood","marsh","ruins"] else "sword"
 return {"appearance":row[2],"mainhand":weapon,"offhand":"shield" if unit.biome in ["border","frost","ruins"] and not ranged else "","armor":"plate" if unit.biome in ["frost","ruins"] else "leather"}

const PHASES={
 "border":{"names":["战旗统御","破旗死战"],"name":"督军亲征","damage":5,"shape":"command","passive":"standard","passive_desc":"战旗誓约：有存活随从时，每次自身行动间首次直接受伤减2。","change":"半血后号令附带5基础齐射伤害；强化随从由2名降至1名。","glyph":"令","color":"f6bf61"},
 "wood":{"names":["静林守望","枯根怒放"],"name":"枯根怒放","damage":8,"shape":"fan","passive":"rootheart","passive_desc":"树心：自身行动开始恢复2生命；破甲可阻止。","change":"半血后藤根扩展至多5格，基础伤害6→8；伏隐减伤4→2。","glyph":"藤","color":"a6e178"},
 "waste":{"names":["沙寨军阀","赤砂狂猎"],"name":"交叉沙矛","damage":11,"shape":"cross","passive":"sandguard","passive_desc":"流沙护身：每次自身行动间首次远距直接受伤减2；标记或破甲时失效。","change":"半血后单线变为至多7格交叉沙矛，基础伤害10→11、耗蓝2→3。","glyph":"矛","color":"ffb267"},
 "frost":{"names":["冰冠守御","碎冠凛冬"],"name":"碎冠凛冬","damage":11,"shape":"fan","passive":"coldheart","passive_desc":"冰心反震：2格内直接命中冰盾会让攻击者下一次移动首格+1点。","change":"半血后冰盾10→6，寒潮扩展至多5格，基础伤害8→11。","glyph":"冰","color":"9fe7ff"},
 "marsh":{"names":["雾沼潜猎","腐林孢潮"],"name":"腐林孢潮","damage":7,"shape":"fan","passive":"sporeveil","passive_desc":"腐花滋养：自身行动开始若有中毒的存活对手，恢复3生命；净护清毒可阻止。","change":"半血后腐花扩展至多5格，基础伤害6→7；毒伤仍为两次且不叠层。","glyph":"毒","color":"d1e87b"},
 "ruins":{"names":["星核戒备","临界星核"],"name":"临界过载","damage":14,"shape":"fan","passive":"feedback","passive_desc":"屏障反馈：带屏障施放汲星射线并造成生命伤害，额外消耗目标1法力。","change":"半血后屏障10→6，过载至多5格，基础伤害12→14；仍可盾击打断。","glyph":"雷","color":"afcaff"}}
static func phase_data(region: String,phase: int) -> Dictionary:
 var data=PHASES.get(region,PHASES.border).duplicate(true)
 data.phase=phase
 data.title=data.names[clampi(phase-1,0,1)]
 return data
