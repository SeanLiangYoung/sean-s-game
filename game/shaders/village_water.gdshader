shader_type spatial;
render_mode specular_disabled,cull_disabled;
uniform vec4 water_color : source_color=vec4(0.22,0.34,0.38,1.0);
varying vec3 world_pos;
void vertex(){
 world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.y+=sin(world_pos.z*0.9+TIME*0.4)*0.008;
}
void fragment(){
 float broad=sin(world_pos.x*0.27+world_pos.z*0.7+TIME*0.24);
 float ripple=sin(world_pos.x*0.8+world_pos.z*2.1+sin(world_pos.x*0.25)+TIME*0.6);
 float stroke=smoothstep(0.88,1.0,ripple)*smoothstep(-0.1,0.8,broad);
 ALBEDO=water_color.rgb*(0.96+broad*0.035)+vec3(stroke*0.025);
 ROUGHNESS=0.88;
}
