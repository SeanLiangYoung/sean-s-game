shader_type spatial;
render_mode specular_disabled,cull_disabled;
uniform vec4 base_color : source_color = vec4(0.4,0.55,0.3,1.0);
uniform float variation = 0.08;
uniform float texture_scale = 0.7;
uniform float safe_radius = -1.0;
varying vec3 world_pos;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float brush=noise(world_pos.xz*texture_scale)*0.65+noise(world_pos.xz*texture_scale*5.0)*0.35;
 vec3 c=base_color.rgb*(1.0+(brush-0.5)*variation);
 if(safe_radius>=0.0){
  float r=world_pos.z/1.17;
  float q=world_pos.x/1.351-r*0.5;
  float edge=max(abs(q),max(abs(r),abs(q+r)));
  float ash=smoothstep(safe_radius+0.5,safe_radius+1.0,edge);
  c=mix(c,vec3(0.38,0.41,0.38),ash*0.8);
 }
 ALBEDO=c*0.72;
 ROUGHNESS=1.0;
}
void light(){
 float diffuse=dot(NORMAL,LIGHT);
 float band=mix(0.30,0.78,smoothstep(-0.12,0.10,diffuse));
 band=mix(band,1.0,smoothstep(0.48,0.60,diffuse));
 DIFFUSE_LIGHT+=LIGHT_COLOR / PI*band*ATTENUATION;
}
