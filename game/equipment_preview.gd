extends VBoxContainer
# Preview owns its render world; inventory and combat remain authoritative elsewhere.
signal view_changed(state: Dictionary)
const Visual=preload("res://game/character_visual.gd")
const Equipment=preload("res://game/equipment_visual.gd")
const DEFAULT_YAW=0.20
const DEFAULT_PITCH=0.10
const DEFAULT_ZOOM=2.05
const MIN_ZOOM=0.75
const MAX_ZOOM=3.0
const MIN_PITCH=-0.10
const MAX_PITCH=0.65
var viewport: SubViewport
var camera: Camera3D
var world: Node3D
var pawn: Node3D
var surface: TextureRect
var character_id=""
var yaw=DEFAULT_YAW
var pitch=DEFAULT_PITCH
var zoom=DEFAULT_ZOOM
var dragging=false
var profile_key=""
var font: Font

func _ready():
 name="EquipmentPreview"
 custom_minimum_size.x=270
 size_flags_vertical=Control.SIZE_EXPAND_FILL
 add_theme_constant_override("separation",8)
 var title=label("全身预览",19)
 title.add_theme_color_override("font_color",Color("d5b57a"))
 add_child(title)
 surface=TextureRect.new()
 surface.name="PreviewSurface"
 surface.custom_minimum_size=Vector2(260,300)
 surface.size_flags_vertical=Control.SIZE_EXPAND_FILL
 surface.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 surface.stretch_mode=TextureRect.STRETCH_SCALE
 surface.mouse_filter=Control.MOUSE_FILTER_STOP
 surface.mouse_force_pass_scroll_events=false
 surface.tooltip_text="按住鼠标左键拖动旋转；上下拖动改变观察高度；滚轮放大或缩小。"
 add_child(surface)
 viewport=SubViewport.new()
 viewport.name="PreviewWorld"
 viewport.own_world_3d=true
 viewport.size=Vector2i(520,720)
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 surface.add_child(viewport)
 surface.texture=viewport.get_texture()
 surface.resized.connect(resize_render)
 surface.gui_input.connect(handle_input)
 world=Node3D.new();viewport.add_child(world)
 var environment=WorldEnvironment.new();environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR
 environment.environment.background_color=Color("22373f")
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color=Color("e5dfce")
 environment.environment.ambient_light_energy=0.8
 world.add_child(environment)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-25,0);light.light_energy=1.5;world.add_child(light)
 var fill=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-15,140,0);fill.light_color=Color("a0bbc5");fill.light_energy=0.45;world.add_child(fill)
 var pedestal=MeshInstance3D.new();var stage=CylinderMesh.new()
 stage.top_radius=0.58;stage.bottom_radius=0.61;stage.height=0.045;stage.radial_segments=48
 pedestal.mesh=stage;pedestal.position.y=-0.035
 var mat=StandardMaterial3D.new();mat.albedo_color=Color("344950");mat.roughness=1.0;pedestal.material_override=mat;world.add_child(pedestal)
 camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_HEIGHT;world.add_child(camera);camera.current=true
 update_camera(false)
 var controls=HBoxContainer.new();controls.add_theme_constant_override("separation",5);add_child(controls)
 for entry in [["左转","向左旋转"],["右转","向右旋转"],["−","缩小"],["＋","放大"],["重置","恢复全身视角"]]:
  var action=entry[0]
  var button=Button.new();button.text=action;button.tooltip_text=entry[1];button.custom_minimum_size=Vector2(50 if action in ["左转","右转"] else (64 if action=="重置" else 36),36);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  if font!=null:button.add_theme_font_override("font",font)
  button.add_theme_font_size_override("font_size",16)
  var box=StyleBoxFlat.new();box.bg_color=Color("273e47");box.border_color=Color("4c6870");box.set_border_width_all(1);box.set_corner_radius_all(5);button.add_theme_stylebox_override("normal",box)
  preload("res://game/compact_ui.gd").symbolize(button,{"左转":"rotate_left","右转":"rotate_right","−":"zoom_out","＋":"zoom_in","重置":"reset"}[action],(action+" · " if action in ["左转","右转","重置"] else "")+entry[1])
  button.pressed.connect(activate.bind(action))
  controls.add_child(button)
 var hint=label("拖动旋转 · 滚轮缩放\n换装实时更新，保留查看角度",14)
 hint.add_theme_color_override("font_color",Color("93a5aa"));add_child(hint)

func activate(action: String):
 match action:
  "左转":yaw-=PI/8;update_camera()
  "右转":yaw+=PI/8;update_camera()
  "−":change_zoom(1.15)
  "＋":change_zoom(1/1.15)
  "重置":reset_view()

func label(text: String,size: int) -> Label:
 var result=Label.new();result.text=text;result.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 result.add_theme_font_size_override("font_size",size)
 if font!=null:result.add_theme_font_override("font",font)
 return result

func resize_render():
 if is_instance_valid(viewport):viewport.size=Vector2i(maxi(1,roundi(surface.size.x*1.5)),maxi(1,roundi(surface.size.y*1.5)))

func show_character(id: String,profile: Dictionary,state: Dictionary={}):
 var changed_character=character_id!=id
 character_id=id
 var key=id+":"+Equipment.signature(profile)
 if key!=profile_key:
  if is_instance_valid(pawn):world.remove_child(pawn);pawn.queue_free()
  pawn=Node3D.new();pawn.name="PreviewCharacter";world.add_child(pawn)
  Visual.create(pawn,id,profile)
  profile_key=key
 if changed_character or not state.is_empty():
  yaw=float(state.get("yaw",DEFAULT_YAW))
  pitch=clampf(float(state.get("pitch",DEFAULT_PITCH)),MIN_PITCH,MAX_PITCH)
  zoom=clampf(float(state.get("zoom",DEFAULT_ZOOM)),MIN_ZOOM,MAX_ZOOM)
 update_camera(false)

func view_state() -> Dictionary:
 return {"yaw":yaw,"pitch":pitch,"zoom":zoom}

func update_camera(emit_change: bool=true):
 yaw=wrapf(yaw,-PI,PI)
 pitch=clampf(pitch,MIN_PITCH,MAX_PITCH)
 zoom=clampf(zoom,MIN_ZOOM,MAX_ZOOM)
 var focus=Vector3(0,0.87,0)
 camera.size=zoom
 camera.position=focus+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*3.3
 camera.look_at(focus)
 if emit_change:view_changed.emit(view_state())

func change_zoom(factor: float):
 zoom*=factor
 update_camera()

func reset_view():
 yaw=DEFAULT_YAW;pitch=DEFAULT_PITCH;zoom=DEFAULT_ZOOM
 update_camera()

func handle_input(event: InputEvent):
 if event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_LEFT:dragging=event.pressed
  elif event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP:change_zoom(1/1.12)
  elif event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_DOWN:change_zoom(1.12)
  else:return
  surface.accept_event()
 elif event is InputEventMouseMotion and dragging:
  if not event.button_mask&MOUSE_BUTTON_MASK_LEFT:
   dragging=false;return
  yaw-=event.relative.x*0.01
  pitch+=event.relative.y*0.006
  update_camera()
  surface.accept_event()

func _input(event: InputEvent):
 # Stop even when a release occurs outside the preview surface.
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:dragging=false

func _notification(what: int):
 if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:dragging=false
