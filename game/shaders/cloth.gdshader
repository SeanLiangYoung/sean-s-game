shader_type spatial;
render_mode cull_disabled,specular_disabled;
uniform vec4 base_color : source_color=vec4(0.25,0.39,0.38,1.0);
void vertex(){VERTEX.y+=sin(TIME*2.3+UV.y*5.0+UV.x*3.0)*0.06*UV.y;}
void fragment(){ALBEDO=base_color.rgb*(0.93+0.07*sin(UV.x*22.0));ROUGHNESS=1.0;}
void light(){DIFFUSE_LIGHT+=LIGHT_COLOR / PI*mix(0.35,1.0,smoothstep(0.0,0.5,dot(NORMAL,LIGHT)))*ATTENUATION;}
