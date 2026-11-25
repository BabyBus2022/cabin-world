shader_type spatial;
render_mode specular_disabled, cull_disabled;
uniform sampler2D base_atlas : source_color, filter_nearest, repeat_disable;
uniform sampler2D detail_atlas : source_color, filter_nearest, repeat_disable;
uniform vec2 cell=vec2(0.0);
uniform float tile_pixels=16.0;
uniform float details=1.0;
uniform float relief=0.35;
uniform float stepped_light=1.0;
uniform bool roof_mapping=false;
uniform bool soft_style=false;
uniform bool soft_lighting=false;
uniform bool is_window=false;
uniform int style_mode=1;
uniform float night_glow=0.0;
uniform vec4 soft_base:source_color=vec4(0.7,0.7,0.7,1.0);
uniform vec4 tint:source_color=vec4(0.78,0.78,0.78,1.0);
varying float ridge_cap;
varying float building_height;
void vertex(){
 // Narrow rectangular ridge beams cannot carry a full repeating roof atlas.
 // Their tiny projected top/side faces otherwise alias into black stippling.
 ridge_cap=roof_mapping && (abs(NORMAL.y)>0.98 || abs(NORMAL.y)<0.15)?1.0:0.0;
 building_height=(MODEL_MATRIX*vec4(VERTEX,1.0)).y;
}
vec2 address(vec2 uv, float pixels){
 return (cell+(floor(fract(uv)*pixels)+0.5)/pixels)/4.0;
}
float height_at(vec2 uv){
 // A restrained luminance-derived relief approximation for this comparison.
 // Production art should supply authored height/normal maps per material.
 return dot(texture(detail_atlas,address(uv,tile_pixels)).rgb,vec3(0.299,0.587,0.114));
}
void fragment(){
 // The tool's original roof U runs along the ridge and V down the slope.
 // Undo the older village import's rotation and use physically smaller tiles.
 vec2 uv=roof_mapping?UV.yx*vec2(3.6,2.8):UV;
 vec3 base=texture(base_atlas,address(uv,16.0)).rgb;
 vec3 detail=texture(detail_atlas,address(uv,tile_pixels)).rgb;
 ALBEDO=mix(base,detail,details)*tint.rgb;
 if(ridge_cap>0.5){ALBEDO=vec3(0.25,0.27,0.38)*tint.rgb;}
 if(soft_style){
  // Keep the supplied atlas structure, but group its small, dark marks into
  // restrained paint tones; the scene light supplies the broad shaded forms.
  float value=dot(mix(base,detail,details),vec3(0.299,0.587,0.114));
  float tones=floor(clamp(value*2.2,0.0,0.999)*3.0)/2.0;
  ALBEDO=soft_base.rgb*(style_mode==0?mix(0.77,1.08,tones):mix(0.88,1.015,tones));
  if(ridge_cap>0.5){ALBEDO=soft_base.rgb*0.82;}
 }
 ROUGHNESS=1.0;SPECULAR=0.0;
 float step_=1.0/tile_pixels;
 float dx=height_at(uv-vec2(step_,0.0))-height_at(uv+vec2(step_,0.0));
 float dy=height_at(uv-vec2(0.0,step_))-height_at(uv+vec2(0.0,step_));
 if(roof_mapping){float temp=dx;dx=dy;dy=temp;}
 NORMAL_MAP=normalize(vec3(dx*relief*(1.0-ridge_cap),dy*relief*(1.0-ridge_cap),1.0))*0.5+0.5;
 NORMAL_MAP_DEPTH=1.0;
 if(is_window){
  vec2 pane=(floor(clamp(UV,vec2(0.0),vec2(0.999))*48.0)+0.5)/48.0;
  vec3 glass=mix(vec3(0.16,0.29,0.30),vec3(0.36,0.48,0.41),pane.y);
  float reflection=1.0-smoothstep(0.035,0.085,abs(pane.x+pane.y*0.55-0.62));
  glass+=vec3(0.09,0.10,0.08)*reflection;
  ALBEDO=mix(glass,vec3(0.56,0.37,0.16),night_glow*2.0);
  EMISSION=vec3(1.0,0.54,0.20)*night_glow;
  NORMAL_MAP=vec3(0.5,0.5,1.0);
 }
}
void light(){
 float ndl=max(dot(NORMAL,LIGHT),0.0);
 float bands=floor(ndl*4.0+0.5)/4.0;
 float illumination=mix(ndl,bands,stepped_light);
 if(soft_lighting){
  // Broad artist-directed fill gradient (not baked texture lighting or blur).
  // Higher exposed surfaces receive more fill; lower walls remain restrained.
  float fill=mix(0.68,1.12,smoothstep(0.0,10.5,building_height));
  illumination=smoothstep(-0.12,0.95,ndl)*fill;
 }
 if(style_mode>0){
  float shade=mix(0.38,0.69,smoothstep(0.12,0.23,ndl));
  shade=mix(shade,0.94,smoothstep(0.61,0.73,ndl));
  illumination=mix(illumination,shade,style_mode==1?0.7:0.35);
 }
 DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*illumination*ATTENUATION/3.14159265;
}

