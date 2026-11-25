shader_type canvas_item;
render_mode unshaded;
uniform sampler2D grass_art : source_color, filter_nearest, repeat_disable;
uniform sampler2D earth_art : source_color, filter_nearest, repeat_disable;
uniform sampler2D paving_art : source_color, filter_nearest, repeat_disable;
uniform sampler2D water_art : source_color, filter_nearest, repeat_disable;
uniform bool village=false;
uniform vec4 bridge_bounds[5];
uniform vec2 bridge_sample_shift[5];
uniform int bridge_count=0;
// Mirrored sampling joins tile boundaries without a visible cut.
vec2 mirrored(vec2 p) { return clamp(1.0-abs(mod(p,2.0)-1.0),vec2(.004),vec2(.996)); }
float near_color(vec3 a, vec3 b) { return 1.0-step(.022,distance(a,b/255.0)); }
void fragment() {
 vec4 original=texture(TEXTURE,UV);
 vec3 c=original.rgb;
 vec2 pixel=floor(UV/TEXTURE_PIXEL_SIZE);
 // Old baked decks must not show through the new bridge arches or beside rails.
 for(int i=0;i<bridge_count;i++){
  vec4 r=bridge_bounds[i];
  if(pixel.x>r.x && pixel.y>r.y && pixel.x<r.x+r.z && pixel.y<r.y+r.w){
   c=texture(TEXTURE,UV+bridge_sample_shift[i]*TEXTURE_PIXEL_SIZE).rgb;
   bool water_color=c.b>c.r+.08 && c.g>c.r+.08;
   bool horizontal=abs(bridge_sample_shift[i].y)>abs(bridge_sample_shift[i].x);
   float across=horizontal ? abs(pixel.y-r.y-r.w*.5)/r.w : abs(pixel.x-r.x-r.z*.5)/r.z;
   if(!water_color && across<.35)c=vec3(226.0,187.0,125.0)/255.0;
  }
 }
 float grass=max(max(near_color(c,vec3(95,165,72)),near_color(c,vec3(118,187,85))),max(near_color(c,vec3(140,203,96)),near_color(c,vec3(162,216,107))));
 grass=max(grass,max(near_color(c,vec3(191,229,127)),max(near_color(c,vec3(90,156,68)),near_color(c,vec3(201,236,140)))));
 grass=max(grass,max(near_color(c,vec3(79,154,68)),max(near_color(c,vec3(104,176,79)),near_color(c,vec3(124,192,90)))));
 float earth=max(max(near_color(c,vec3(184,135,82)),near_color(c,vec3(207,159,99))),max(near_color(c,vec3(226,187,125)),near_color(c,vec3(237,207,150))));
 earth=max(earth,max(near_color(c,vec3(246,226,180)),max(near_color(c,vec3(191,154,104)),near_color(c,vec3(255,240,200)))));
 float stone=max(max(near_color(c,vec3(240,234,219)),near_color(c,vec3(221,213,194))),max(near_color(c,vec3(196,186,163)),near_color(c,vec3(159,149,127))));
 vec3 g=texture(grass_art,mirrored(pixel/190.0)).rgb;
 vec3 e=texture(earth_art,mirrored((pixel+vec2(81,47))/220.0)).rgb;
 vec3 p=texture(paving_art,mirrored(pixel/65.0)).rgb;
 // Keep the baked shoreline, water, flowers, rice fields, and road geometry.
 c=mix(c,g,grass);
 c=mix(c,e,earth);
 c=mix(c,p,stone*.82);
 if(c.b>c.r+.08 && c.g>c.r+.08) {
  vec2 drift=vec2(floor(TIME*1.2),floor(TIME*.45));
  vec3 surface=texture(water_art,mirrored((pixel+drift)/210.0)).rgb;
  vec3 depth=vec3(c.r*.92+.025,c.g*.93+.025,c.b*.88+.035);
  c=mix(depth,surface,.24)+(surface.g-.62)*.10;
 }
 if(village) {
  float plaza_radius=length(pixel-vec2(885.0,750.0));
  // Replace the whole original paving ring, including the old mortar.
  if(plaza_radius>22.0 && plaza_radius<66.0)c=p;
 }
 COLOR=vec4(c,original.a);
}
