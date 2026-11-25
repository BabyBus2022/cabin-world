shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D ink:source_color,filter_nearest,repeat_enable;
uniform vec4 pigment:source_color=vec4(1.0);
uniform bool textured=false;
uniform bool world_uv=false;
uniform bool planks=false;
uniform bool grass=false;
uniform float texture_strength=1.0;
uniform float repeat_scale=1.0;
uniform vec4 daylight:source_color=vec4(1.0);
varying vec3 p;
varying vec3 n;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;n=normalize((MODEL_MATRIX*vec4(NORMAL,0.0)).xyz);}
void fragment(){
 vec2 uv=world_uv?p.xz*repeat_scale:UV*repeat_scale;
 uv=1.0-abs(mod(uv,2.0)-1.0);
 vec3 color=pigment.rgb;
 if(textured){
  vec3 pattern=texture(ink,uv).rgb;
  if(grass){
   vec2 alternate=1.0-abs(mod(p.zx*repeat_scale*.71+vec2(.37,.19),2.0)-1.0);
   pattern=mix(pattern,texture(ink,alternate).rgb,.42);
  }
  color*=mix(vec3(1.0),pattern,texture_strength);
 }
 // Painted face tones, without specular shine, normal-map bumps or moving PBR highlights.
 float face=abs(n.y)>.7?1.03:(n.x<-.5?.86:.96);
 if(planks){
  float seam=step(.91,fract((abs(n.x)>.5?p.z:p.x)*2.0));
  color*=mix(1.0,.79,seam);
 }
 ALBEDO=color*face*daylight.rgb;
}
