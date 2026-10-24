extends SceneTree
# Native asset lineup, isolated from campaign/save data.
func _initialize():call_deferred("run")
func run():
 var stage=Node3D.new()
 root.add_child(stage)
 var environment=WorldEnvironment.new()
 environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR
 environment.environment.background_color=Color("c2cbb9")
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color=Color("c5d1c4")
 environment.environment.ambient_light_energy=0.32
 stage.add_child(environment)
 var sun=DirectionalLight3D.new()
 stage.add_child(sun)
 sun.rotation_degrees=Vector3(-45,-30,0)
 sun.light_color=Color("fff0d4")
 sun.light_energy=0.55
 sun.shadow_enabled=true
 var art=load("res://game/art.gd").new()
 var floor=MeshInstance3D.new()
 floor.mesh=PlaneMesh.new()
 floor.mesh.size=Vector2(50,50)
 var material=StandardMaterial3D.new()
 material.albedo_color=Color("9da789")
 material.roughness=1
 floor.material_override=material
 stage.add_child(floor)
 var font=FontFile.new()
 font.data=FileAccess.get_file_as_bytes("/System/Library/Fonts/STHeiti Medium.ttc")
 var roles=["hero","blade","ranger","medic","engineer","warden"]
 var names=["沈烬 · 行旅披肩","岚 · 游侠围巾","鸦 · 林地猎手","白芷 · 医者披帛","铁九 · 工匠行囊","奥伦 · 守卫长披"]
 for i in range(roles.size()):
  var pawn=Node3D.new()
  pawn.position=Vector3((i-2.5)*1.32,0,0)
  stage.add_child(pawn)
  load("res://game/character_visual.gd").create(pawn,roles[i])
  art.ring(pawn,Vector3(0,0.01,0),0.39,Color("d1c79f"),0.02,48)
  var label=Label3D.new()
  label.text=names[i]
  label.font=font
  label.font_size=26
  label.pixel_size=0.003
  label.modulate=Color("2b3f3c")
  label.outline_size=0
  label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
  label.position=Vector3(0,2.05,0)
  pawn.add_child(label)
 var camera=Camera3D.new()
 stage.add_child(camera)
 camera.position=Vector3(0,3.3,8)
 camera.look_at(Vector3(0,1.0,0))
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=5.8
 root.msaa_3d=Viewport.MSAA_4X
 for i in range(30):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/characters-polished.png")
 print("CHARACTER_CAPTURE_READY")
 quit()
