shader_type spatial;
render_mode cull_disabled,specular_disabled;
uniform vec4 root_color : source_color=vec4(0.23,0.36,0.16,1.0);
uniform vec4 tip_color : source_color=vec4(0.62,0.70,0.31,1.0);
uniform float wind_strength=0.16;
varying float height;
void vertex(){
 height=UV.y;
 vec3 w=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float gust=sin(TIME*1.5+w.x*0.7+w.z*0.5)+0.4*sin(TIME*2.5+w.z*1.3);
 VERTEX.x+=gust*wind_strength*UV.y*UV.y;
 VERTEX.z+=sin(TIME+w.x)*wind_strength*0.4*UV.y;
}
void fragment(){ALBEDO=mix(root_color.rgb,tip_color.rgb,height);ROUGHNESS=1.0;}
void light(){float band=mix(0.5,1.0,smoothstep(0.0,0.5,dot(NORMAL,LIGHT)));DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*band*ATTENUATION;}
