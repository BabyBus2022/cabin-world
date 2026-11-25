shader_type canvas_item;
render_mode unshaded;
uniform vec4 tint:source_color=vec4(1.0);
uniform float clock=0.0;
uniform float night_level=0.0;
uniform vec2 shore[32];
uniform int shore_count=0;
varying vec2 pos;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){pos=VERTEX;}
void fragment(){
    vec2 q=floor(pos/2.0)*2.0;
    float bank=10000.0;
    for(int i=0;i<32;i++){
        if(i>=shore_count)break;
        vec2 a=shore[i],b=shore[(i+1)%shore_count],ab=b-a;
        float h=clamp(dot(q-a,ab)/max(dot(ab,ab),0.01),0.0,1.0);
        bank=min(bank,length(q-a-ab*h));
    }
    float wave=sin(q.y*0.10+sin(q.x*0.025+clock*0.33)*1.6-clock*0.8);
    float broad=sin(q.x*0.018+q.y*0.023+clock*0.14);
    vec3 shallow=vec3(0.37,0.65,0.56), deep=vec3(0.18,0.43,0.48);
    vec3 base=mix(shallow,deep,clamp(floor(bank/10.0)/5.0,0.0,1.0));
    float bend=sin(q.y*.067+clock*.32)+sin(q.x*.043+clock*.17);
    float net=abs(sin(q.y*.099+q.x*.025+bend)+.56*sin(q.x*.079-q.y*.047-clock*.22));
    float shelf=1.0-smoothstep(8.,71.,bank);
    base+=vec3(.15,.20,.12)*(1.-smoothstep(.04,.18,net))*shelf*.62;
    base=mix(base,vec3(.10,.33,.42),smoothstep(26.,110.,bank)*.4);
    base+=floor(broad*2.0)/2.0*vec3(0.018,0.035,0.028);
    float rim=1.0-step(3.0+wave*1.4,bank);
    base=mix(base,vec3(0.61,0.76,0.62),rim*0.62);
    float glint=step(0.94,wave)*step(0.62,sin(q.x*0.052+sin(q.y*0.08)+clock*0.39));
    glint*=step(9.0,bank);
    base=mix(base,vec3(0.70,0.84,0.69),glint*0.43);
    // Broken bank reflections, not a pasted mirror image or smooth glossy plane.
    float reflection=(1.0-step(30.0,bank))*step(0.40,sin(q.x*0.036+wave*0.8))*step(q.y,425.0);
    base=mix(base,vec3(0.20,0.39,0.32),reflection*0.24);
    float crest=sin(q.y*.23+1.6*sin(q.x*.027+q.y*.034+clock*.26)-clock*1.1);
    float sky=sin(q.x*.022+q.y*.014+sin(q.x*.012-clock*.15)+clock*.12);
    base+=vec3(.018,.040,.055)*sky;
    base=mix(base,vec3(.80,.94,.89),smoothstep(.82,.99,crest)*smoothstep(.15,.84,broad)*(.35-.23*night_level)*smoothstep(4.,20.,bank));
    vec3 light=mix(tint.rgb,vec3(0.36,0.49,0.67),night_level*0.35);
    COLOR=vec4(base*light,1.0);
}
