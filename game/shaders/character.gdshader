shader_type spatial;
render_mode specular_disabled;
uniform sampler2D source_texture : source_color,filter_linear_mipmap;
uniform bool has_texture=true;
uniform vec4 base_color : source_color=vec4(1.0);
uniform vec4 tint : source_color=vec4(1.0);
void fragment(){
 vec3 c=has_texture?texture(source_texture,UV).rgb*base_color.rgb:base_color.rgb;
 // Lift shadows painted into the source texture while preserving its material detail.
 c=pow(max(c,vec3(0.001)),vec3(0.76));
 ALBEDO=clamp(c*tint.rgb,vec3(0.0),vec3(0.94));
 ROUGHNESS=0.95;
 EMISSION=ALBEDO*0.065;
}
void light(){
 float ndl=dot(NORMAL,LIGHT);
 float band=mix(0.58,1.12,smoothstep(-0.12,0.58,ndl));
 DIFFUSE_LIGHT+=LIGHT_COLOR/PI*band*ATTENUATION;
}
