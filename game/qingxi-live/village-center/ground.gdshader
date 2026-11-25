shader_type canvas_item;
render_mode unshaded;
#include "res://qingxi-live/village-center/fire_light.gdshaderinc"
uniform sampler2D grass_tex:source_color,filter_nearest,repeat_enable;
uniform sampler2D grass_b:source_color,filter_nearest,repeat_enable;
uniform sampler2D grass_c:source_color,filter_nearest,repeat_enable;
uniform sampler2D grass_d:source_color,filter_nearest,repeat_enable;
uniform sampler2D dirt_tex:source_color,filter_nearest,repeat_enable;
uniform vec4 tint:source_color=vec4(1.0);
uniform float seed=17.0;
uniform float night_level=0.0;
uniform float rural_layout=0.0;
uniform vec2 world_size=vec2(1280.0,900.0);
uniform sampler2D path_mask:filter_nearest;
varying vec2 p;
float hash(vec2 x){return fract(sin(dot(x,vec2(127.1,311.7))+seed*19.3)*43758.5453);}
vec4 variant(sampler2D tex,vec2 q){
    // Overlapping quiet macro-patches vary hue without a grid of tile seams.
    vec2 block=floor(q/128.0);
    vec2 local=fract(q/128.0);
    float h=hash(block);
    // Mirrored repeat keeps the original patch edges continuous.
    vec2 uv=abs(mod(q/128.0,2.0)-1.0);
    vec4 c=texture(tex,uv);
    float m=sin(q.x*0.011+seed)*sin(q.y*0.015)+sin(q.x*0.024-q.y*0.019)*0.35;
    float v=floor(m*2.0)/2.0;
    c.rgb*=1.0+v*0.035;
    return c;
}
vec4 meadow(vec2 q){
    vec2 cell=floor(q/96.0);
    vec2 uv=fract(q/96.0);
    float pick=floor(hash(cell)*4.0);
    if(hash(cell+vec2(41.0,13.0))>0.5)uv.x=1.0-uv.x;
    if(hash(cell+vec2(14.0,31.0))>0.5)uv.y=1.0-uv.y;
    vec4 c=texture(grass_tex,uv);
    if(pick>0.5)c=texture(grass_b,uv);
    if(pick>1.5)c=texture(grass_c,uv);
    if(pick>2.5)c=texture(grass_d,uv);
    // The generated squares have baked perimeter shading. Never use that as
    // terrain color. Only their high-contrast grass/flower marks are overlaid.
    float lum=dot(c.rgb,vec3(0.299,0.587,0.114));
    float decor=max(1.0-step(0.47,lum),step(0.72,lum));
    float broad=sin(q.x*0.007+seed*0.12)*sin(q.y*0.009);
    vec3 continuous=vec3(0.565,0.655,0.362)*(1.0+floor(broad*6.0)/6.0*0.018);
    return vec4(mix(continuous,c.rgb,decor),1.0);
}
void vertex(){p=VERTEX;}
void fragment(){
    vec2 q=floor(p);
    vec4 grass=meadow(q);
    vec4 dirt=variant(dirt_tex,q+vec2(33.0,41.0));
    float route=texture(path_mask,q/world_size).r;
    float edge=step(0.06,route);
    float path=step(0.46,route);
    vec3 base=mix(grass.rgb,grass.rgb*vec3(0.91,0.90,0.87),edge);
    base=mix(base,dirt.rgb,path);
    float lamp_a=pow(clamp(1.0-distance(q,vec2(620.0,490.0))/88.0,0.0,1.0),1.3);
    float lamp_b=pow(clamp(1.0-distance(q,vec2(443.0,532.0))/60.0,0.0,1.0),1.3);
    float pool=max(lamp_a,lamp_b);
    COLOR=vec4(base*fire_illumination(tint.rgb,q),1.0);
}
