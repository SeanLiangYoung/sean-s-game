extends Node
# Share each character's current equipped look across all UI cards; retire superseded renders.
var textures: Dictionary = {}
var signatures: Dictionary = {}
var viewports: Dictionary = {}
const Equipment=preload("res://game/equipment_visual.gd")

func profile_signature(profile: Dictionary) -> String:
 return Equipment.signature(profile)
func portrait(character_id: String,profile: Dictionary={}) -> Texture2D:
 var key=profile_signature(profile)
 if textures.has(character_id) and signatures.get(character_id,"")==key:return textures[character_id]
 if viewports.has(character_id):
  var old=viewports[character_id]
  remove_child(old);old.queue_free()
 var viewport=SubViewport.new()
 viewport.size=Vector2i(192,192)
 viewport.own_world_3d=true
 viewport.transparent_bg=false
 viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
 add_child(viewport)
 var world=Node3D.new()
 viewport.add_child(world)
 var environment=WorldEnvironment.new()
 environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR
 environment.environment.background_color=Color("243b43")
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color=Color("e5dfce")
 environment.environment.ambient_light_energy=0.8
 world.add_child(environment)
 var light=DirectionalLight3D.new()
 light.rotation_degrees=Vector3(-35,-25,0)
 light.light_energy=1.5
 world.add_child(light)
 var pawn=Node3D.new()
 world.add_child(pawn)
 preload("res://game/character_visual.gd").create(pawn,character_id,profile)
 # Portraits are static snapshots: do not let wind phase alter the same outfit on a later render.
 for mesh in pawn.find_children("*","MeshInstance3D",true,false):
  var mat=mesh.material_override
  if mat is ShaderMaterial and mat.shader==preload("res://game/shaders/garment.gdshader"):
   mat.set_shader_parameter("motion_scale",0.0)
 pawn.process_mode=Node.PROCESS_MODE_DISABLED
 var camera=Camera3D.new()
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=1.52 if not profile.is_empty() else 0.96
 world.add_child(camera)
 camera.position=Vector3(0.75,1.12,3.1) if not profile.is_empty() else Vector3(0.22,1.12,2.8)
 camera.look_at(Vector3(0,0.96 if not profile.is_empty() else 1.02,0))
 camera.current=true
 signatures[character_id]=key
 viewports[character_id]=viewport
 textures[character_id]=viewport.get_texture()
 return textures[character_id]
