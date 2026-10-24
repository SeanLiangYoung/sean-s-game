shader_type spatial;
render_mode cull_disabled,specular_disabled;
uniform vec4 cloth_color : source_color=vec4(0.22,0.4,0.38,1);
uniform vec4 trim_color : source_color=vec4(0.73,0.64,0.44,1);
uniform float motion_scale=1.0;
void vertex(){
 float free_edge=UV.y*UV.y;
 VERTEX.z+=sin(TIME*1.8+UV.x*4.0+MODEL_MATRIX[3].x)*0.045*free_edge*motion_scale;
 VERTEX.x+=sin(TIME*1.4+UV.y*2.0)*0.02*free_edge*motion_scale;
}
void fragment(){
 float trim=max(smoothstep(0.93,0.97,UV.y),smoothstep(0.93,0.98,abs(UV.x*2.0-1.0)));
 vec3 color=mix(cloth_color.rgb,trim_color.rgb,trim);
 float weave=1.0+sin(UV.x*110.0)*sin(UV.y*130.0)*0.018;
 ALBEDO=color*weave;
 ROUGHNESS=1.0;
 EMISSION=color*0.04;
}
void light(){DIFFUSE_LIGHT+=LIGHT_COLOR/PI*mix(0.55,1.1,smoothstep(-0.1,0.6,dot(NORMAL,LIGHT)))*ATTENUATION;}
