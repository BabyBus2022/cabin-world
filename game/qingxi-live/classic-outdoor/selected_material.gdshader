shader_type spatial;
render_mode specular_disabled, cull_disabled;
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform vec2 cell=vec2(0.0);
uniform bool roof=false;
uniform bool window=false;
uniform float night_glow=0.0;
uniform vec4 tint : source_color=vec4(1.0);
varying vec3 local_position;
varying vec3 local_normal;
void vertex(){local_position=VERTEX;local_normal=NORMAL;}
void fragment(){
 vec3 n=abs(local_normal);
 // Physical spacing avoids stretching a full swatch across narrow timber beams.
 vec2 uv=n.x>n.z?vec2(local_position.z,-local_position.y):vec2(local_position.x,-local_position.y);
 if(n.y>.65 || roof)uv=vec2(local_position.x,local_position.z);
 uv/=roof?3.5:2.5;
 vec2 sample_uv=(cell+(floor(fract(uv)*627.0)+.5)/627.0)/2.0;
 ALBEDO=texture(atlas,sample_uv).rgb*.86*tint.rgb;
 ROUGHNESS=1.0;SPECULAR=0.0;
 if(window){
  ALBEDO=mix(vec3(.08,.16,.18),vec3(.32,.39,.35),clamp(UV.y,0.0,1.0));
  EMISSION=vec3(1.0,.63,.32)*night_glow;
 }
}

