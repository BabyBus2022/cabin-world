shader_type spatial;
render_mode unshaded,cull_disabled;
uniform sampler2D base_atlas:source_color,filter_nearest,repeat_disable;
uniform sampler2D detail_atlas:source_color,filter_nearest,repeat_disable;
uniform vec2 cell=vec2(0.0);
uniform float tile_pixels=64.0;
uniform float details=1.0;
uniform float relief=0.0;
uniform float stepped_light=0.0;
uniform bool roof_mapping=false;
uniform bool soft_style=true;
uniform bool soft_lighting=true;
uniform bool is_window=false;
uniform float night_glow=0.0;
uniform vec4 soft_base:source_color=vec4(.7,.7,.7,1.0);
uniform vec4 tint:source_color=vec4(1.0);
uniform vec4 daylight:source_color=vec4(1.0);
varying vec3 face_normal;
void vertex(){face_normal=normalize((MODEL_MATRIX*vec4(NORMAL,0.0)).xyz);}
void fragment(){
 vec2 uv=roof_mapping?UV.yx*vec2(3.6,2.8):UV;
 vec2 address=(cell+(floor(fract(uv)*min(tile_pixels,64.0))+.5)/min(tile_pixels,64.0))/4.0;
 vec3 art=texture(detail_atlas,address).rgb;
 float value=dot(art,vec3(.299,.587,.114));
 float shade=mix(.78,1.12,smoothstep(.05,.85,value));
 vec3 color=soft_base.rgb*shade;
 float face=face_normal.x<-.5?.92:1.0;
 // The authored texture carries the shading; avoid moving smooth highlights and relief.
 ALBEDO=color*face*daylight.rgb;
 if(is_window)ALBEDO=mix(vec3(.36,.47,.45)*daylight.rgb,vec3(.94,.69,.35),night_glow*3.0);
}
