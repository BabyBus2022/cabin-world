shader_type canvas_item;
render_mode unshaded;
uniform sampler2D gravel : source_color,filter_linear,repeat_enable;
uniform sampler2D stones : source_color,filter_linear,repeat_disable;

float seed(vec2 p){return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.54);}
float bed_corner(ivec2 cell){
 uint h=uint(cell.x)*1597334677u ^ uint(cell.y)*3812015801u;
 h=(h^(h>>16u))*2246822519u;
 return float((h^(h>>13u))&65535u)/65535.;
}
float patches(vec2 p){
 ivec2 i=ivec2(floor(p));
 vec2 f=fract(p);f=f*f*(3.-2.*f);
 return mix(mix(bed_corner(i),bed_corner(i+ivec2(1,0)),f.x),
            mix(bed_corner(i+ivec2(0,1)),bed_corner(i+ivec2(1,1)),f.x),f.y);
}

vec2 mirror_uv(vec2 p){return .005+.99*(1.-abs(mod(p,2.)-1.));}

// Each patch hosts a sequence of wave packets. Separate phases let consecutive
// patches form, drift and dissolve without all flashing on the same beat.
float crossing_foam(vec2 p,vec2 flow,float t,vec2 offset){
 vec2 spacing=vec2(98.,76.);
 vec2 cell=floor((p+offset)/spacing);
 vec2 local=mod(p+offset,spacing);
 float interval=mix(5.8,10.2,seed(cell+offset+3.));
 float cycle=t/interval+seed(cell+offset)*11.;
 float age=fract(cycle);
 vec2 id=cell+offset+floor(cycle)*vec2(13.,27.);
 vec2 center=spacing*vec2(.36+.28*seed(id+3.),.36+.28*seed(id+7.));
 vec2 facing=normalize(mix(vec2(1.,0.),vec2(-flow.y,flow.x)*sign(-flow.y+.0001),.48));
 vec2 normal=vec2(-facing.y,facing.x);
 vec2 q=local-center-flow*((age-.5)*10.);
 float x=dot(q,facing),y=dot(q,normal);
 float span=mix(7.,24.,seed(id+9.));
 float width=mix(.55,1.5,seed(id+11.));
 float variant=seed(id+19.);
 float life=smoothstep(.04,.36,age)*(1.-smoothstep(.54,.93,age));
 float extent=span*(.29+.71*life);
 float edge=1.-smoothstep(.58,1.,abs(x)/max(extent,1.));
 float bend=(x*x/(span*span))*(2.+3.*variant)+sin(x*.17+t*.76+id.x)*.72;
 float drift=age*3.-1.5;
 float primary=1.-smoothstep(width*.45,width+.55,abs(y-bend-drift));
 float secondary=1.-smoothstep(.35,width+.35,abs(y+bend+x*mix(-.29,.29,variant)+drift+1.7));
 float crossing=1.-smoothstep(1.1,5.1,abs(2.*bend+x*mix(-.29,.29,variant)+2.*drift+1.7));
 float breakup=smoothstep(.16,.52,patches(vec2(x*.22-t*.67,id.y)));
 float fringe=variant>.62 ? (1.-smoothstep(.4,1.2,abs(y-bend-drift-2.8)))*.44 : 0.;
 return life*edge*breakup*(max(primary,max(secondary*.72,fringe))*(.54+.46*crossing));
}
void fragment(){
 vec4 field=texture(TEXTURE,UV);
 if(field.a<.1){discard;}
 vec2 p=floor(UV/TEXTURE_PIXEL_SIZE);
 vec2 flow=normalize(field.gb*2.-1.+vec2(.00001));
 float bank=field.r*255.;
 float depth=smoothstep(1.,31.,bank);
 vec2 along=flow*TIME;
 // Keep the bed anchored while the surface refracts it and moves downstream.
 vec2 q=p-along*3.2;
 float a=sin(dot(q,vec2(.053,.089))+1.4*sin(q.x*.027-q.y*.011));
 float b=sin(q.y*.22+q.x*.043+a*1.7+sin(q.x*.079));
 vec2 lens=vec2(a,b)*mix(.6,1.45,depth);
 // Refract the original painted bed at its continuous texture coordinates.
 vec2 bedpos=UV/TEXTURE_PIXEL_SIZE+lens*.60;
 // Smooth, anchored changes of scale and orientation keep whole painted faces legible.
 // Use map coordinates so adjacent river sections join without texture seams.
 vec2 bend=vec2(sin(dot(bedpos,vec2(.017,.006))+1.4*sin(bedpos.y*.012)),
                sin(dot(bedpos,vec2(-.009,.019))+.85*sin(bedpos.x*.016)))*.54;
 vec2 course=vec2(.94*bedpos.x+.34*bedpos.y,-.34*bedpos.x+.94*bedpos.y);
 vec2 stone_map=course+22.*bend+vec2(9.*sin(course.y/68.),12.*sin(course.x/94.));
 vec3 bed=texture(gravel,mirror_uv(stone_map/164.+vec2(.27,.36))).rgb;
 float detail=dot(bed,vec3(.3,.58,.12));
 // Coherent patches stay attached to the lit faces of the stones rather than filling the gaps.
 float growth=patches(bedpos/23.)*.57+patches(bedpos/5.3)*.30+patches(bedpos/2.1)*.13;
 float moss=smoothstep(.52,.71,growth)*smoothstep(.24,.47,detail);
 bed=mix(bed,vec3(.115,.24,.10)+detail*vec3(.38,.44,.21),moss*.85);
 // Scattered submerged cobbles have stable positions and their own upstream bow waves.
 vec2 pitch=vec2(67.,53.);
 float row_shift=pitch.x*seed(vec2(floor(p.y/pitch.y),79.));
 vec2 cell=floor((p+vec2(row_shift,0.))/pitch);
 vec2 span=vec2(mix(11.,32.,seed(cell+2.)),mix(6.,15.,seed(cell+21.)));
 vec2 inset=span*.69+2.;
 vec2 middle=cell*pitch+mix(inset,pitch-inset,vec2(seed(cell+5.),seed(cell+8.)))-vec2(row_shift,0.);
 vec2 stoneUV=(bedpos-middle)/span+.5;
 vec4 stone=texture(stones,clamp(stoneUV,vec2(0.),vec2(1.)));
 float shoal=step(.57,seed(cell+17.))*(1.-smoothstep(12.,28.,bank))*step(2.,bank);
 bed=mix(bed,stone.rgb,shoal*stone.a*.90);
 vec3 shallow=bed*vec3(.68,.90,.80)+vec3(.04,.125,.135);
 vec3 deep=mix(vec3(.062,.27,.34),vec3(.09,.39,.43),detail);
 vec3 water=mix(shallow,deep,depth*.86);
 float caustic=1.-smoothstep(.025,.16,abs(a+.56*b-.27));
 water+=vec3(.16,.25,.16)*caustic*(.17+.58*(1.-depth));
 float crest=smoothstep(.90,.985,b)*smoothstep(.27,.72,a);
 float breaks=patches((p-along*4.)/vec2(25.,9.)+vec2(0.,TIME*.1));
 water=mix(water,vec3(.78,.92,.90),crest*smoothstep(.45,.68,breaks)*(.32+.21*(1.-depth)));
 vec2 wake=(p-middle)/span;
 float ring=length(wake)+.05*sin(dot(p-along*4.,vec2(.4,.26)));
 float bow=(1.-smoothstep(.055,.17,abs(ring-.52)))*smoothstep(-.05,.34,-dot(wake,flow));
 water=mix(water,vec3(.86,.94,.88),shoal*bow*(.46+.25*b));
 float crossing=max(crossing_foam(p,flow,TIME,vec2(0.)),crossing_foam(p,flow,TIME,vec2(47.,29.))*.86);
 water=mix(water,vec3(.86,.95,.93),crossing*smoothstep(1.,7.,bank)*.88);
 float rim=1.-smoothstep(.4,1.75,abs(bank-(1.45+.8*a)));
 water=mix(water,vec3(.73,.85,.76),rim*(.20+.49*smoothstep(-.32,.83,b)));
 if(field.a<.5){
  COLOR=vec4(mix(bed,vec3(.57,.55,.34),.29),.78);
 }else{
  COLOR=vec4(water,1.);
 }
}
