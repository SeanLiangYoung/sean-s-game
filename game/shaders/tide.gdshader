shader_type spatial;
render_mode unshaded,cull_disabled,blend_mix,depth_draw_never;
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;VERTEX.y+=sin(TIME*0.7+world_pos.x*0.9)*0.18*UV.y;}
void fragment(){
 float drift=sin(world_pos.x*1.5+world_pos.z*2.0-TIME)*0.15;
 vec3 low=vec3(0.54,0.37,0.26);
 vec3 high=vec3(0.43,0.51,0.54);
 ALBEDO=mix(low,high,UV.y);
 ALPHA=(1.0-UV.y)*(0.15+drift*0.25);
}
