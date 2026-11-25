shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform sampler2D grass_tex:source_color,filter_nearest,repeat_enable;
uniform sampler2D grass_alt:source_color,filter_nearest,repeat_enable;
uniform sampler2D stone_tex:source_color,filter_nearest,repeat_enable;
uniform sampler2D dirt_tex:source_color,filter_nearest,repeat_enable;
uniform sampler2D route_mask:filter_linear,repeat_disable;
varying vec3 world;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){
 vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 // Stable world pixels: no camera-dependent noise or vignette baked into tiles.
 vec2 p=floor(world.xz*16.0)/16.0;
 float broad=noise(p*.21);
 vec3 a=texture(grass_tex,p/6.0).rgb;
 vec3 b=texture(grass_alt,(p.yx+vec2(7.2,13.5))/7.7).rgb;
 vec3 grass=mix(a,b,smoothstep(.22,.78,broad))*.72;
 grass*=mix(.93,1.04,noise(p*.44));
 vec3 soil=texture(dirt_tex,p/4.2).rgb*.70;
 soil*=mix(.94,1.04,noise(p*.65));
 float route=texture(route_mask,(p+vec2(100.0))/200.0).r;
 float breakup=(noise(p*3.3)-.5)*.20+(noise(p*1.1)-.5)*.16;
 float edge=smoothstep(.16,.84,route+breakup);
 edge=floor(edge*5.0+.5)/5.0;
 vec3 ground=mix(grass,soil,edge);
 // Joined small courtyard pockets, replacing the rectangular grid stamp.
 float yard=min(length((p-vec2(-3,-2))/vec2(4.7,3.1)),length((p-vec2(-1,0))/vec2(3.5,2.8)));
 float stone_mask=1.0-smoothstep(.93,1.08,yard+(noise(p*2.5)-.5)*.10);
 vec3 stone=texture(stone_tex,(p+vec2(1.7,3.1))/4.5).rgb*.75;
 ALBEDO=mix(ground,stone,stone_mask);ROUGHNESS=1.0;SPECULAR=0.0;
}

