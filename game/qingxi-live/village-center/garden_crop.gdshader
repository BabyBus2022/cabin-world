shader_type canvas_item;
render_mode unshaded;
uniform vec2 planted_at;
uniform vec4 sky_tint:source_color=vec4(1.0);
uniform vec4 shade_tint:source_color=vec4(0.86,0.93,1.0,1.0);
uniform vec4 sun_tint:source_color=vec4(1.0);
uniform float sun_side=-0.5;
uniform float light_strength=0.0;
uniform float night_level=0.0;
varying float inclination;
void vertex(){
    float angle=0.65*sin(TIME*0.057)+0.22;
    vec2 path=vec2(cos(angle),sin(angle));
    float phase=dot(planted_at,path)*0.021-TIME*1.85;
    float crest=0.48+0.52*sin(phase*0.43+sin(planted_at.y*0.009-TIME*0.28));
    inclination=sin(phase)*crest+0.12*sin(TIME*3.2+planted_at.y);
}
void fragment(){
    float tip=pow(1.0-UV.y,1.65);
    vec2 leaf=UV-vec2(tip*inclination*0.058,tip*abs(inclination)*0.009);
    if(leaf.x<0.0 || leaf.x>1.0 || leaf.y<0.0 || leaf.y>1.0){discard;}
    vec4 c=texture(TEXTURE,leaf);
    float side=clamp(0.5+(leaf.x-0.5)*sun_side+(0.5-leaf.y)*0.4,0.0,1.0);
    vec3 illumination=sky_tint.rgb*mix(vec3(1.0),mix(shade_tint.rgb,sun_tint.rgb,side),light_strength);
    float shine=smoothstep(0.1,0.85,inclination*sun_side+(leaf.x-0.5)*0.65)*tip*(1.0-night_level);
    c.rgb=mix(c.rgb,vec3(.87,.93,.60),shine*0.29)*illumination;
    COLOR=vec4(c.rgb,c.a*COLOR.a);
}

