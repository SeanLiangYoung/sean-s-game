extends SceneTree
const Art=preload("res://game/art.gd")
const Character=preload("res://game/character_visual.gd")
var failures=0
var checks=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;print("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
 check(ResourceLoader.exists("res://game/boss_visual.gd"),"boss ornaments helper exists")
 check(ResourceLoader.exists("res://game/boss_effects.gd"),"boss effects helper exists")
 if failures:quit(1);return
 var visual=load("res://game/boss_visual.gd")
 var art=Art.new()
 for biome in ["border","wood","waste","frost","marsh","ruins"]:
  var counts=[]
  for phase in [1,2]:
   var pawn=Node3D.new();root.add_child(pawn);Character.create(pawn,"enemy1")
   var unit={"id":"boss","biome":biome,"boss":true,"boss_phase":phase,"hp":10,"max_hp":20}
   var before=unit.duplicate(true)
   var insignia=visual.decorate(art,pawn,unit)
   check(insignia!=null and insignia.name=="BossInsignia","named root "+biome)
   var attachments=pawn.find_children("BossMount*","BoneAttachment3D",true,false)
   check(attachments.size()>=1,"boss ornaments follow bones "+biome)
   var meshes=0
   for attachment in attachments:meshes+=attachment.find_children("*","MeshInstance3D",true,false).size()
   counts.append(meshes)
   check(meshes>=4,"distinct substantial silhouette "+biome)
   check(unit==before,"decoration leaves rules untouched")
   visual.decorate(art,pawn,unit)
   var actual_mounts=0
   for node in pawn.find_child("Skeleton3D",true,false).get_children():
    if node.get_meta("boss_ornament",false):actual_mounts+=1
   check(actual_mounts==attachments.size(),"phase rebuild replaces bone ornaments")
   pawn.free()
  check(counts[1]>counts[0],"phase two expands silhouette "+biome)
 var effects=load("res://game/boss_effects.gd")
 var p=load("res://game/combat_presentation.gd").new()
 # A real presentation with a minimal host provides board positions, without pawns.
 p.host=EffectHost.new();p.host.art=art;root.add_child(p.host);root.add_child(p)
 var actor=Node3D.new();actor.name="Character_other_boss";p.host.add_child(actor);p.host.pawn_nodes.append(actor)
 Character.create(actor,"enemy1")
 for biome in ["border","wood","waste","frost","marsh","ruins"]:
  for cue_type in ["charge","release","phase","interrupt","enemy_skill"]:
   var cues=[{"type":cue_type,"source":"other_boss","biome":biome,"phase":2,"kind":"strike","cells":[Vector2i(2,3)],"name":"Test"}]
   p.source_id="unrelated_player"
   var before_count=p.get_child_count()
   effects.begin(p,cues);effects.impact(p,cues);effects.advance(p,cues,0.5,0.1)
   check(p.get_child_count()>before_count,"empty warned cell visible "+biome+" "+cue_type)
   var found=false
   for child in p.get_children():
    if child.get_meta("boss_effect",false) and child.get_meta("biome")==biome and child.get_meta("cue_type")==cue_type:
     found=child.position==Vector3(2,0,3) and child.get_child_count()>=4
   check(found,"cue follows its own source and warned cell "+biome+" "+cue_type)
 effects.advance(p,[],2.0,2.0)
 await process_frame
 var live_effects=0
 for child in p.get_children():
  if child.get_meta("boss_effect",false):live_effects+=1
 check(live_effects==0,"expired effect geometry is cleaned up")
 check(actor.get_node("Body").position.is_equal_approx(Vector3.ZERO),"procedural weight shift settles back")
 p.host.free();p.free()
 print("CHECKS: %d FAILURES: %d"%[checks,failures]);quit(1 if failures else 0)
class EffectHost extends Node3D:
 var art
 var pawn_nodes=[]
 func cell_position(cell):return Vector3(cell.x,0,cell.y)
