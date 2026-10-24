shader_type spatial;
render_mode specular_disabled,cull_disabled;
uniform vec4 water_color : source_color=vec4(0.17,0.37,0.40,1.0);
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;VERTEX.y+=sin(world_pos.z*2.0+TIME*1.3)*0.018;}
void fragment(){
 float waves=sin(world_pos.x*6.0+world_pos.z*2.5+TIME*1.4)*sin(world_pos.z*8.0-TIME*1.1);
 float sparkle=smoothstep(0.86,0.98,waves);
 float shore=smoothstep(0.85,1.0,abs(UV.x*2.0-1.0));
 ALBEDO=mix(water_color.rgb,vec3(0.62,0.74,0.65),sparkle*0.5+shore*0.25);
 ROUGHNESS=0.6;
}
