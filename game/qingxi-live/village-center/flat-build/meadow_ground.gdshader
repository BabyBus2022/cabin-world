shader_type canvas_item;
render_mode unshaded;
#include "res://qingxi-live/village-center/flat-build/pond_waves.gdshaderinc"
uniform sampler2D earth_art:source_color,filter_nearest;
uniform sampler2D streambed:source_color,filter_nearest,repeat_enable;
uniform vec4 tint:source_color=vec4(1.);
uniform float sunlight=.8;
uniform float rainfall=0.;
uniform float sky_time=.54;
vec2 mirrored(vec2 p){return clamp(1.-abs(mod(p,2.)-1.),vec2(.004),vec2(.996));}
float light_web(vec2 p,float t){
 // Distance between nearest and second-nearest moving wave foci forms broken light nets.
 p=p/vec2(14.,9.)+vec2(.43*sin(p.y*.091+t*.32),.53*sin(p.x*.081-t*.25)+.16*sin(p.y*.19+t*.43));
 vec2 tile=floor(p),f=fract(p);
 float first=9.,second=9.;
 for(int j=-1;j<=1;j++){
  for(int i=-1;i<=1;i++){
   vec2 d=vec2(float(i),float(j));
   float seed=rand2(tile+d)*6.283;
   vec2 xy=d+.5+.30*sin(vec2(seed,seed*2.81)+vec2(t*.29,-t*.34))-f;
   float dist=dot(xy,xy);
   second=min(second,max(first,dist));first=min(first,dist);
  }
 }
 return 1.-smoothstep(.018,.16,second-first);
}
// Each patch has its own clock. Every new impact gets a fresh position and radius.
// Keep the whole ellipse inside its patch so a crest never cuts off at a seam.
vec3 rain_hash(vec3 seed){
 vec3 v=fract(seed*vec3(.1031,.1030,.0973));
 v+=dot(v,v.yxz+33.33);
 return fract((v.xxy+v.yxx)*v.zyx);
}
float rain_impact(vec2 p,vec2 spacing,float t,float intensity,float salt){
 vec2 q=p/spacing;
 vec2 cell=floor(q);
 vec3 timing=rain_hash(vec3(cell,salt));
 float clock=t*mix(.59,1.28,timing.y)*mix(.62,1.,intensity)+timing.x;
 vec3 event=rain_hash(vec3(cell+vec2(salt,19.7),floor(clock)+salt));
 float age=fract(clock)/mix(.39,.79,event.y);
 if(age>=1. || event.z>mix(.32,.89,intensity))return 0.;
 float radius=mix(2.8,8.8,event.x);
 vec2 axes=vec2(radius,radius*mix(.50,.72,timing.z));
 vec2 inset=(axes+1.2)/spacing;
 vec2 center=mix(inset,1.-inset,rain_hash(vec3(cell.yx,floor(clock)+salt+82.)).xy);
 vec2 offset=(fract(q)-center)*spacing/axes;
 float dist=length(offset);
 float front=mix(.09,1.,age*(1.52-.52*age));
 float crest=1.-smoothstep(.16,1.10,abs(dist-front)*radius);
 float echo=(1.-smoothstep(.14,.94,abs(dist-front*.61)*radius))*smoothstep(.20,.52,age)*.33;
 float fade=smoothstep(0.,.10,age)*(1.-smoothstep(.40,1.,age));
 return (crest+echo)*fade*mix(.45,1.,timing.y);
}
void fragment(){
 vec2 p=floor(UV/TEXTURE_PIXEL_SIZE*32.);
 vec2 pos=floor(UV/TEXTURE_PIXEL_SIZE*64.);
 vec3 field=ground_field(TEXTURE_PIXEL_SIZE,p).rgb;
 float road=field.r+.015*sin(p.x*.29+p.y*.13)+.014*sin(p.y*.4);
 float water=field.g+shoreline(p);
 vec3 color=texture(earth_art,mirrored((p+vec2(81,47))/220.)).rgb;
 float alpha=step(.61,road);
 if(road<.65){color*=vec3(.87,.89,.80);}
 if(water>.25){
  float shelf=smoothstep(.49,.98,water);
  // A shallow shelf remains transparent for roughly half a tile.
  float aspect=1.+.16*sin(pos.x*.012+pos.y*.009)+.09*sin(pos.y*.019);
  float distance_tiles=field.b*5.*shelf*aspect;
  float depth=1.-exp(-1.24*pow(distance_tiles,1.65));
  vec2 slope=lake_slope(pos,TIME);
  vec2 rockpos=pos+vec2(4.*sin(pos.y*.021),5.*sin(pos.x*.018));
  vec2 bedpos=rockpos+slope*(.2+1.35*shelf);
  vec3 bed=texture(streambed,bedpos/vec2(191.,178.)).rgb;
  // The colonies refract with the stones. Depth attenuation below hides them in deep water.
  float detail=dot(bed,vec3(.30,.58,.12));
  float growth=.56*pond_noise(bedpos/26.)+.30*pond_noise(bedpos/6.)+.14*pond_noise(bedpos/2.);
  float moss=smoothstep(.48,.67,growth)*smoothstep(.16,.45,detail)*smoothstep(.33,.5,water);
  vec3 algae=vec3(.085,.19,.062)+detail*vec3(.43,.60,.24);
  bed=mix(bed,algae,moss*.90);
  vec3 dry=bed*vec3(1.08,1.05,.87)+vec3(.05,.055,.022);
  float wet=smoothstep(.48,.59,water);
  vec3 trans=exp(-vec3(5.4,4.2,3.8)*depth)*(1.-smoothstep(.70,.99,depth));
  vec3 lake=mix(vec3(.075,.44,.38),vec3(.025,.185,.285),depth);
  vec3 submerged=bed*vec3(.94,1.11,.91)*trans+lake*(1.-trans);
  float web=light_web(pos,TIME);
  float beam=.5+.28*sin(pos.x*.042+pos.y*.073+.8*slope.x)+.22*sin(-pos.x*.11+pos.y*.04+.65*slope.y);
  float flicker=smoothstep(.17,.82,beam)*(.5+.5*beam);
  submerged+=vec3(.30,.43,.25)*web*flicker*pow(1.-.92*depth,1.4)*(.12+.83*sunlight)*(1.-.7*rainfall);
  float shade=.5+.5*slope.y;
  submerged+=vec3(.031,.082,.089)*(shade-.45)*(.24+depth);
  submerged+=vec3(.009,.018,.023)*slope.x*depth;
  if(shelf<.999 || field.b<.26){
   float hour_angle=(sky_time-.25)*6.283185;
   vec2 toward_bank=vec2(cos(hour_angle)*14.,-3.-5.*max(sin(hour_angle),0.));
   float blocker=ground_field(TEXTURE_PIXEL_SIZE,p+toward_bank).g;
   float shade_alpha=(1.-smoothstep(.31,.85,blocker))*wet*(.13+.30*sqrt(sunlight));
   submerged*=mix(vec3(1.),vec3(.49,.63,.74),shade_alpha);
  }
  if(rainfall>.001 && wet>.01){
   float rain=clamp(rainfall,0.,1.);
   float rings=rain_impact(pos,vec2(37.,29.),TIME,rain,13.6);
   rings+=rain_impact(vec2(pos.x+.18*pos.y,pos.y)+vec2(81.,23.),vec2(49.,31.),TIME,rain,47.2);
   submerged+=vec3(.16,.24,.26)*min(rings,1.2)*sqrt(rain);
  }
  color=mix(dry,submerged,wet);
  if(water<.85){
   float along=sin(pos.x*.032+pos.y*.021)+.6*sin(pos.y*.074-pos.x*.037);
   float lap=.5+.5*sin(TIME*1.24+along*2.);
   float reach=.518+.105*lap+.009*sin(pos.x*.31+pos.y*.18+TIME*.85);
   float broken=smoothstep(-.52,.54,along+.54*sin(pos.x*.13-pos.y*.09-TIME*.62));
   float crest=1.-smoothstep(.009,.042,abs(water-reach));
   float trail=1.-smoothstep(.005,.026,abs(water-reach-.089));
   float foam=(crest*(.16+.84*broken)+trail*.36*broken*lap)*(.58+.30*lap);
   float wet_bank=smoothstep(.38,.51,water)*(1.-wet)*(.42+.35*lap);
   color*=mix(vec3(1.),vec3(.68,.76,.74),wet_bank);
   color=mix(color,mix(vec3(.65,.78,.77),vec3(.91,.97,.90),sunlight),clamp(foam,0.,1.));
  }
  alpha=max(alpha,smoothstep(.30,.50,water+(bed.g-.4)*.16));
 }
 COLOR=vec4(color*tint.rgb,alpha);
}

