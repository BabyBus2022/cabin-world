shader_type canvas_item;
render_mode unshaded;
#include "res://qingxi-live/village-center/fire_light.gdshaderinc"
uniform sampler2D stone_tex:source_color,filter_nearest,repeat_enable;
uniform vec4 sky_tint:source_color=vec4(1.0);
uniform vec4 paving_rect=vec4(704.0,576.0,960.0,704.0);
varying vec2 world_point;
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;}
void fragment(){
 vec2 p=floor(world_point/2.0)*2.0;
 vec2 half_size=paving_rect.zw*.5;
 vec2 q=abs(p-(paving_rect.xy+half_size))-(half_size-vec2(24.0));
 float border=length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0)-24.0;
 float dance_ring=length((p-vec2(1120.0,928.0))/vec2(234.0,170.0));
 vec3 stone=texture(stone_tex,fract(p/184.0)).rgb;
 stone=mix(stone,vec3(.77,.69,.55),.12);
 if(border>-12.0)stone*=vec3(.74,.76,.77);
 if(dance_ring>.97 && dance_ring<1.0)stone*=vec3(.79,.76,.68);
 COLOR=vec4(stone*fire_illumination(sky_tint.rgb,p),1.0-step(0.0,border));
}
