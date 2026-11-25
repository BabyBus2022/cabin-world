shader_type canvas_item;
render_mode unshaded;
#include "res://qingxi-live/village-center/fire_light.gdshaderinc"
uniform vec4 sky_tint:source_color=vec4(1.0);
uniform vec4 shade_tint:source_color=vec4(0.86,0.93,1.0,1.0);
uniform vec4 sun_tint:source_color=vec4(1.0);
uniform float sun_side=-0.5;
uniform float light_strength=0.0;
uniform float is_tree=0.0;
uniform float night_level=0.0;
uniform float emissive_mode=0.0;
uniform float festival_lamp=0.0;
uniform float lamp_glow=0.0;
varying vec2 world_point;
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;}
float nearby_light(vec2 p){
    float a=pow(clamp(1.0-distance(p,vec2(620.0,490.0))/88.0,0.0,1.0),1.3);
    float b=pow(clamp(1.0-distance(p,vec2(443.0,532.0))/60.0,0.0,1.0),1.3);
    return max(a,b);
}
void fragment(){
    vec4 c=texture(TEXTURE,UV);
    float lum=dot(c.rgb,vec3(0.299,0.587,0.114));
    float side=clamp(0.5+(UV.x-0.5)*sun_side*1.4+(0.5-UV.y)*0.4,0.0,1.0);
    float band=floor(clamp(lum*0.32+side*0.68,0.0,0.999)*4.0)/3.0;
    vec3 relight=mix(shade_tint.rgb,sun_tint.rgb,band);
    vec3 illumination=sky_tint.rgb*mix(vec3(1.0),relight,light_strength);
    illumination=fire_illumination(illumination,world_point);
    float window_mask=0.0;
    if(emissive_mode>0.5 && emissive_mode<1.5){
        bool front=UV.y>0.58 && UV.y<0.83;
        bool side_windows=(UV.x>0.14 && UV.x<0.31)||(UV.x>0.72 && UV.x<0.88);
        bool door=UV.x>0.39 && UV.x<0.63 && UV.y>0.66 && UV.y<0.84;
        bool gable=UV.x>0.4 && UV.x<0.62 && UV.y>0.30 && UV.y<0.40;
        window_mask=float((front && side_windows)||door||gable)*step(0.57,c.g)*step(0.7,c.r);
    }
    if(emissive_mode>1.5 && emissive_mode<2.5){
        window_mask=float(UV.x<0.65 && UV.y>0.30 && UV.y<0.66)*step(0.6,c.r)*step(0.5,c.g)*(1.0-step(0.60,c.b));
    }
    if(emissive_mode>2.5){
        // Separate panes, not whole window bounds: frames and balcony rails
        // must remain dark even when they share a gray-green glass color.
        bool upper_left_x=(UV.x>0.238 && UV.x<0.289)||(UV.x>0.307 && UV.x<0.366);
        bool upper_left=upper_left_x && UV.y>0.273 && UV.y<0.386;
        bool upper_right_x=(UV.x>0.658 && UV.x<0.727)||(UV.x>0.751 && UV.x<0.830);
        bool upper_right_y=(UV.y>0.285 && UV.y<0.383)||(UV.y>0.404 && UV.y<0.439)||(UV.y>0.459 && UV.y<0.475);
        bool upper_right=upper_right_x && upper_right_y;
        bool lower_x=(UV.x>0.500 && UV.x<0.644)||(UV.x>0.667 && UV.x<0.819);
        bool lower_y=(UV.y>0.659 && UV.y<0.740)||(UV.y>0.765 && UV.y<0.858);
        bool lower=lower_x && lower_y;
        bool entry_lamp=UV.x>0.218 && UV.x<0.275 && UV.y>0.604 && UV.y<0.657;
        window_mask=float(upper_left||upper_right||lower)*0.9;
        window_mask=max(window_mask,float(entry_lamp)*step(0.7,c.r)*step(0.6,c.g));
    }
    c.rgb=mix(c.rgb*illumination,vec3(1.0,0.76,0.34),window_mask*night_level*0.96);
    if(festival_lamp>0.5 && UV.x<0.57 && UV.y>0.10 && UV.y<0.43 && c.r>0.52){c.rgb=mix(c.rgb,vec3(1.0,.87,.55),lamp_glow*.85);}
    c.a=step(0.5,c.a)*COLOR.a;
    COLOR=c;
}
