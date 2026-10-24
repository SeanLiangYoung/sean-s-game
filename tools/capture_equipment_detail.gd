extends SceneTree
const Visual=preload("res://game/character_visual.gd")
func _initialize():call_deferred("run")
func render(profile: Dictionary,view: Vector3,action: String="idle") -> Texture2D:
 var viewport=SubViewport.new();viewport.size=Vector2i(340,420);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var world=Node3D.new();viewport.add_child(world)
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("243b43");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("e5dfce");env.environment.ambient_light_energy=0.8;world.add_child(env)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-25,0);light.light_energy=1.5;world.add_child(light)
 var pawn=Node3D.new();world.add_child(pawn);Visual.create(pawn,profile.appearance,profile)
 Visual.play(pawn,action)
 var player=pawn.find_child("AnimationPlayer",true,false)
 if action=="attack":
  var clip=player.current_animation
  player.stop();player.play(clip,0.0);player.seek(0.65,true);player.advance(0)
 else:player.advance(0)
 player.pause()
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.73;world.add_child(camera);camera.position=view;camera.look_at(Vector3(0,0.92,0));camera.current=true
 return viewport.get_texture()
func run():
 root.size=Vector2i(1440,1000)
 var bg=ColorRect.new();bg.color=Color("111c24");bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(bg)
 var grid=GridContainer.new();grid.columns=4;grid.position=Vector2(16,16);grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",16);bg.add_child(grid)
 var profiles=[
  ["板甲 · 正面","hero","sword","plate",Vector3(0.4,1.25,3.2),"idle"],
  ["板甲 · 侧面","hero","sword","plate",Vector3(3.2,1.25,0.5),"idle"],
  ["板甲 · 背面","hero","sword","plate",Vector3(0.5,1.25,-3.2),"idle"],
  ["皮甲 · 贴身剪裁","hero","dagger","leather",Vector3(0.4,1.25,3.2),"idle"],
  ["护甲 · 剑击姿势","hero","sword","plate",Vector3(0.6,1.25,3.2),"attack"],
  ["弓 · 弓臂与弦","ranger","bow","leather",Vector3(0.2,1.25,3.2),"idle"],
  ["医杖 · 晶石与箍环","medic","staff","plate",Vector3(0.4,1.25,3.2),"idle"],
  ["木盾 · 背部绑带","hero","","leather",Vector3(0.7,1.25,-3.2),"idle"]]
 for row in profiles:
  var column=VBoxContainer.new();grid.add_child(column)
  var label=Label.new();label.text=row[0];label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.add_theme_font_size_override("font_size",21);column.add_child(label)
  var rect=TextureRect.new();rect.custom_minimum_size=Vector2(340,420);rect.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;rect.texture=render({"appearance":row[1],"mainhand":row[2],"offhand":"shield","armor":row[3]},row[4],row[5]);column.add_child(rect)
 for i in 20:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/equipment-shapes-detail.png")
 quit()
