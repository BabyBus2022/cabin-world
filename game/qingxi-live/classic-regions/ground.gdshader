shader_type canvas_item;
render_mode unshaded;
uniform sampler2D grass_tex:source_color,filter_nearest,repeat_enable;
uniform sampler2D dirt_tex:source_color,filter_nearest,repeat_enable;
uniform sampler2D stone_tex:source_color,filter_nearest,repeat_enable;
uniform sampler2D path_mask:filter_linear,repeat_disable;
uniform vec2 world_size=vec2(1280,900);
uniform vec4 tint:source_color=vec4(1);
uniform float night_level=0.0;
uniform float paving=0.0;
varying vec2 p;
void vertex(){p=VERTEX;}
void fragment(){
 vec2 q=floor(p);
 vec3 grass=texture(grass_tex,q/64.0).rgb;
 float shade=sin(q.x*.007)*sin(q.y*.009);
 grass*=1.0+shade*.035;
 vec3 road=mix(texture(dirt_tex,q/64.0).rgb,texture(stone_tex,q/64.0).rgb,paving);
 float mask=texture(path_mask,p/world_size).r;
 float edge=smoothstep(.30,.70,mask);
 COLOR=vec4(mix(grass,road,edge)*tint.rgb,1.0);
}
