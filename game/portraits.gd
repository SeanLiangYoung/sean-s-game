extends Node
# Render each character once, sharing the resulting texture across all UI cards.
var textures: Dictionary = {}
func portrait(character_id: String) -> Texture2D:
 if textures.has(character_id):return textures[character_id]
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
 preload("res://game/character_visual.gd").create(pawn,character_id)
 pawn.process_mode=Node.PROCESS_MODE_DISABLED
 var camera=Camera3D.new()
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=0.96
 world.add_child(camera)
 camera.position=Vector3(0.22,1.12,2.8)
 camera.look_at(Vector3(0,1.02,0))
 camera.current=true
 textures[character_id]=viewport.get_texture()
 return textures[character_id]
