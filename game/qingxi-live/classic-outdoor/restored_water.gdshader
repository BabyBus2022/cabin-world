shader_type spatial;
render_mode specular_disabled,cull_disabled;
uniform vec2 shore[32];
uniform int shore_count=0;
uniform float clock=0.0;
uniform float feed_age=100.0;
varying vec2 pos;
void vertex(){pos=(VERTEX.xz-vec2(30,-40))/vec2(.03,.04)+vec2(744,447);}
void fragment(){
 vec2 q=floor(pos/2.0)*2.0;float bank=10000.0;
 for(int i=0;i<32;i++){
  if(i>=shore_count)break;
  vec2 a=shore[i],b=shore[(i+1)%shore_count],ab=b-a;
  float h=clamp(dot(q-a,ab)/max(dot(ab,ab),.01),0.0,1.0);
  bank=min(bank,length(q-a-ab*h));
 }
 float wave=sin(q.y*.10+sin(q.x*.025+clock*.33)*1.6-clock*.8);
 float broad=sin(q.x*.018+q.y*.023+clock*.14);
 vec3 base=mix(vec3(.37,.65,.56),vec3(.18,.43,.48),clamp(floor(bank/10.0)/5.0,0.0,1.0));
 base+=floor(broad*2.0)/2.0*vec3(.018,.035,.028);
 float rim=1.0-step(3.0+wave*1.4,bank);
 base=mix(base,vec3(.61,.76,.62),rim*.62);
 float glint=step(.94,wave)*step(.62,sin(q.x*.052+sin(q.y*.08)+clock*.39))*step(9.0,bank);
 base=mix(base,vec3(.70,.84,.69),glint*.43);
 float reflection=(1.0-step(30.0,bank))*step(.40,sin(q.x*.036+wave*.8))*step(q.y,425.0);
 base=mix(base,vec3(.20,.39,.32),reflection*.24);
 for(int r=0;r<3;r++){
  float age=feed_age-float(r)*.35;
  float radius=5.0+age*14.0;
  float ring=1.0-smoothstep(1.0,3.0,abs(length(q-vec2(677,587))-radius));
  if(age>0.0 && age<3.0)base=mix(base,vec3(.78,.86,.67),ring*(1.0-age/3.0)*.65);
 }
 ALBEDO=base*.85;ROUGHNESS=1.0;SPECULAR=0.0;
}

