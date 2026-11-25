shader_type canvas_item;
render_mode unshaded;
#include "res://qingxi-live/village-center/fire_light.gdshaderinc"
uniform vec4 sky_tint:source_color=vec4(1.0);
uniform vec4 shade_tint:source_color=vec4(1.0);
uniform vec4 sun_tint:source_color=vec4(1.0);
uniform float light_strength=0.0;
uniform float sun_side=0.0;
uniform float night_level=0.0;
varying vec4 instance_tint;
varying vec2 world_point;
void vertex(){instance_tint=COLOR;world_point=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;}
void fragment(){
    // Keep the Studio artwork's original face, colors and antialiased alpha.
    // Environment palette bands and alpha clipping do not belong on the actor.
    vec4 c=texture(TEXTURE,UV);
    vec3 ambient=mix(vec3(1.0),sky_tint.rgb,0.75);
    float lamp_a=pow(clamp(1.0-distance(world_point,vec2(620.0,490.0))/88.0,0.0,1.0),1.3);
    float lamp_b=pow(clamp(1.0-distance(world_point,vec2(443.0,532.0))/60.0,0.0,1.0),1.3);
    
    vec3 sun=mix(vec3(1.0),mix(shade_tint.rgb,sun_tint.rgb,0.65),light_strength*0.12);
    COLOR=vec4(c.rgb*fire_illumination(ambient,world_point)*sun,c.a)*instance_tint;
}
