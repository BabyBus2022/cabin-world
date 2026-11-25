shader_type canvas_item;

varying vec4 tint;
void vertex(){tint=COLOR;}
void fragment(){
 vec2 p=UV*vec2(640.,426.6667);
 vec4 base=texture(TEXTURE,UV);
 // Only the blue bath water refracts. Keep stones, tile lines and curtains steady.
 float water=smoothstep(.07,.20,base.b-base.r)*step(45.,p.x)*step(p.x,493.)*step(55.,p.y)*step(p.y,221.);
 vec2 shift=vec2(sin(p.y*.18+TIME*1.2),cos(p.x*.12+TIME*.7))*.64;
 vec3 rgb=mix(base.rgb,texture(TEXTURE,UV+shift/vec2(640.,426.6667)).rgb,water*.8);
 float steam=0.;
 for(int i=0;i<5;i++){
  float n=float(i);
  float phase=fract(TIME*.108+n*.37);
  vec2 at=vec2(112.+n*78.+4.*sin(phase*5.+n),158.+18.*sin(n*4.)-phase*37.);
  vec2 q=(p-at)/vec2(8.+8.*phase,7.+8.*phase);
  steam+=exp(-dot(q,q)*2.)*sin(3.14159*phase);
 }
 COLOR=vec4(mix(rgb,vec3(.92,.96,.95),clamp(.21*steam,0.,.3)),base.a)*tint;
}
