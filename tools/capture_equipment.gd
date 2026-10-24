extends SceneTree
const Visual=preload("res://game/character_visual.gd")
const Portraits=preload("res://game/portraits.gd")
var captures=[]
func _initialize():call_deferred("run")
func label(text: String) -> Label:
 var node=Label.new();node.text=text;node.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 node.add_theme_font_size_override("font_size",22)
 return node
func render_pawn(profile: Dictionary) -> Texture2D:
 var viewport=SubViewport.new();viewport.size=Vector2i(230,380);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var world=Node3D.new();viewport.add_child(world)
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("243b43");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("e5dfce");env.environment.ambient_light_energy=0.8;world.add_child(env)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-25,0);light.light_energy=1.5;world.add_child(light)
 var pawn=Node3D.new();world.add_child(pawn);Visual.create(pawn,profile.appearance,profile)
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.94;world.add_child(camera);camera.position=Vector3(0.7,1.3,3.2);camera.look_at(Vector3(0,0.83,0));camera.current=true
 return viewport.get_texture()
func run():
 root.size=Vector2i(1440,1000)
 var portraits=Portraits.new();root.add_child(portraits)
 var panel=ColorRect.new();panel.color=Color("111c24");panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(panel)
 var grid=GridContainer.new();grid.columns=6;grid.position=Vector2(16,16);grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",14);panel.add_child(grid)
 var weapons=["","sword","dagger","bow","staff","crossbow"]
 var names=["空手 / 便装","剑 / 皮甲","短刃 / 板甲","弓 / 板甲","医杖 / 板甲","遗械弩 / 板甲"]
 for i in 6:
  var profile={"appearance":"hero","mainhand":weapons[i],"offhand":"shield" if i>0 else "","armor":"leather" if i==1 else ("plate" if i>1 else "")}
  var column=VBoxContainer.new();grid.add_child(column);column.add_child(label(names[i]))
  var texture=TextureRect.new();texture.custom_minimum_size=Vector2(230,230);texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;texture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;texture.texture=portraits.portrait("sample"+str(i),profile);column.add_child(texture)
  captures.append({"name":"hero-"+(weapons[i] if i>0 else "bare"),"texture":texture.texture})
 for i in 6:
  var character=["hero","blade","ranger","medic","engineer","warden"][i]
  var profile={"appearance":character,"mainhand":["sword","dagger","bow","staff","crossbow","sword"][i],"offhand":"shield","armor":"plate"}
  var column=VBoxContainer.new();grid.add_child(column);column.add_child(label(["沈烬","岚","鸦","白芷","铁九","奥伦"][i]+" · 板甲"))
  var texture=TextureRect.new();texture.custom_minimum_size=Vector2(230,460);texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;texture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;texture.texture=render_pawn(profile);column.add_child(texture)
 for i in 25:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/equipment-appearance-lineup.png")
 for capture in captures:capture.texture.get_image().save_png("res://artifacts/equipment-"+capture.name+".png")
 panel.queue_free()
 var scene=load("res://game/main.tscn").instantiate();root.add_child(scene)
 await process_frame
 scene.set_process(false)
 scene.campaign=load("res://game/campaign.gd").new("user://equipment-capture-only.json")
 for pair in [[0,"hero"],[1,"blade"],[2,"ranger"],[3,"medic"],[4,"engineer"],[5,"warden"],[6,"blade"],[7,"hero"]]:scene.campaign.equip_item(pair[0],pair[1])
 scene.enter_campaign();scene.show_party_menu("角色","hero")
 for i in 12:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/equipment-dossier.png")
 root.get_texture().get_image().save_png("res://artifacts/character-details.png")
 scene.show_party_menu("装备","hero")
 for i in 8:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/character-equipment.png")
 scene.campaign.books=["focus","sniper"]
 scene.show_party_menu("技能","medic")
 for i in 8:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/character-skills.png")
 scene.close_modal();scene.campaign.depart();scene.selected_ids=["hero","medic","ranger","engineer","warden"];scene.begin_battle(0)
 for i in 12:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/equipment-battle.png")
 print("EQUIPMENT_CAPTURE_READY")
 quit()
