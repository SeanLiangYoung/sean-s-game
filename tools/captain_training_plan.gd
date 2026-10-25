extends RefCounted
const BUDGET=105
const PLAN=[["strike",2],["hero_heal",1],["mark",1]]
static func apply(c) -> Dictionary:
 var hero=c.roster.filter(func(unit):return unit.id=="hero")[0]
 var result={"budget":BUDGET,"spent":0,"remaining":0,"ledger":[],"error":""}
 if hero.xp!=0 or hero.skill_ranks!={"strike":1}:
  result.error="training requires a fresh captain";return result
 hero.xp=BUDGET
 for target in PLAN:
  while c.Professions.skill_rank(hero,target[0])<target[1]:
   var cost=c.Professions.skill_cost(hero,target[0])
   var before=hero.xp
   if not c.train_skill("hero",target[0]):result.error="legal training rejected: "+target[0];return result
   result.spent+=cost
   result.ledger.append({"skill":target[0],"rank":c.Professions.skill_rank(hero,target[0]),"cost":cost,"xp_before":before,"xp_after":hero.xp})
 result.remaining=hero.xp
 if result.spent!=BUDGET or result.remaining!=0:result.error="unequal training expenditure"
 return result
