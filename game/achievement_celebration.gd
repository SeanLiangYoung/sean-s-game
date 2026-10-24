extends Control
# One-shot UI feedback; its tweens and audio belong to the dialog's lifetime.
const DURATION=0.7
static var cached_chime: AudioStreamWAV
var progress=0.0:
 set(value):
  progress=value
  queue_redraw()

func play(label: Label,sound_enabled: bool=true,volume: float=1.0):
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 label.pivot_offset=label.size*0.5
 label.scale=Vector2.ONE*0.86
 label.modulate.a=0.0
 var entrance=create_tween().set_parallel(true)
 entrance.tween_property(label,"scale",Vector2.ONE,0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
 entrance.tween_property(label,"modulate:a",1.0,0.25)
 create_tween().tween_property(self,"progress",1.0,DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
 var sound=AudioStreamPlayer.new()
 sound.name="UnlockChime"
 sound.stream=chime()
 sound.volume_db=-10.0+linear_to_db(maxf(clampf(volume,0.0,1.0),0.0001))
 add_child(sound)
 if sound_enabled and volume>0.0:sound.play()

func _draw():
 if progress>=1.0:return
 var center=Vector2(size.x*0.5,size.y*0.34)
 var gold=Color("f3d58c")
 gold.a=0.6*(1.0-progress)
 draw_arc(center,24.0+progress*80.0,0.0,TAU,64,gold,2.0,true)
 for i in range(18):
  var angle=TAU*float(i)/18.0
  var direction=Vector2(cos(angle),sin(angle))
  var distance=30.0+progress*(75.0+float(i%3)*18.0)
  var point=center+direction*distance+Vector2(0.0,progress*progress*16.0)
  var radius=(2.0+float(i%3))*(1.0-progress)
  draw_line(point-direction*4.0,point+direction*4.0,gold,maxf(1.0,radius),true)
  draw_circle(point,radius,gold)

static func chime() -> AudioStreamWAV:
 if cached_chime!=null:return cached_chime
 var sample_rate=22050
 var duration=1.25
 var data=PackedByteArray()
 data.resize(int(sample_rate*duration)*2)
 var notes=[523.25,659.25,783.99,1046.5]
 var starts=[0.0,0.09,0.18,0.30]
 for i in range(data.size()/2):
  var time=float(i)/sample_rate
  var sample=0.0
  for j in notes.size():
   var age=time-starts[j]
   if age<0.0:continue
   var envelope=minf(age/0.012,1.0)*exp(-age*6.5)
   # A quiet overtone adds a bell-like attack without a sharp click.
   sample+=(sin(TAU*notes[j]*age)+0.18*sin(TAU*notes[j]*2.0*age))*envelope*0.16
  sample*=clampf((duration-time)/0.12,0.0,1.0)
  data.encode_s16(i*2,int(clampf(sample,-0.9,0.9)*32767.0))
 cached_chime=AudioStreamWAV.new()
 cached_chime.format=AudioStreamWAV.FORMAT_16_BITS
 cached_chime.mix_rate=sample_rate
 cached_chime.stereo=false
 cached_chime.loop_mode=AudioStreamWAV.LOOP_DISABLED
 cached_chime.data=data
 return cached_chime
