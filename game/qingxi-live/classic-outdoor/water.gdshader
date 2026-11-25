shader_type spatial;
render_mode specular_disabled,cull_disabled;
void fragment(){
 vec2 p=floor(UV*160.0)/160.0;
 float t=TIME*0.4;
 float wave=sin(p.x*57.0+p.y*35.0+t*2.0)+sin(p.y*81.0-p.x*20.0-t);
 float edge=length((UV-vec2(0.5))*vec2(2.0,2.0));
 if(edge>1.0+sin(p.y*38.0)*0.025)discard;
 float light=step(1.32,wave);
 ALBEDO=mix(vec3(0.10,0.28,0.31),vec3(0.27,0.48,0.46),smoothstep(0.0,1.0,edge));
 ALBEDO+=light*vec3(0.10,0.13,0.10);
 ROUGHNESS=1.0;
}

