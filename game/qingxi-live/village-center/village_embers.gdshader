shader_type canvas_item;
render_mode unshaded;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.545);}
float noise2(vec2 p){
 vec2 i=floor(p), f=fract(p);f=f*f*(3.-2.*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
float tongue(vec2 p,float center,float height,float width,float t){
 float y=p.y/height;
 float sway=(noise2(vec2(y*2.8-t,center*67.))-.5)*.31*y+sin(y*9.-t*2.)*.035*y;
 float taper=width*pow(max(0.,1.-y),.72);
 return taper-abs(p.x-center-sway)+.033*(noise2(vec2(p.x*13.,p.y*6.-t*3.))-.5);
}
void fragment(){
 vec2 p=(floor(UV*vec2(36,44))+.5)/vec2(36,44);
 p=vec2(p.x-.5,1.-p.y);
 float t=floor(TIME*14.)/14.;
 float l=tongue(p,-.19,.40+.12*sin(t*4.8),.19,t+.8);
 float m=tongue(p,-.035,.70+.18*sin(t*3.2),.22,t);
 float r=tongue(p,.175,.48+.15*cos(t*4.1),.17,t+2.);
 float body=max(m,max(l,r));
 float foot=.015+.074*pow(abs(p.x)*2.,2.);
 vec3 ink=vec3(.83,.213,.085);
 float opacity=step(foot,p.y)*step(0.,body);
 if(body>.027)ink=vec3(1.,.417,.119);
 if(body>.073+.028*sin(p.y*14.-t*4.))ink=vec3(1.,.66,.20);
 if(body>.133+.022*sin(p.x*23.+p.y*9.-t*3.))ink=vec3(1.,.855,.42);
 for(int i=0;i<7;i++){
  float k=float(i), age=fract(t*(.30+.018*k)+k*.37);
  float sx=(hash(vec2(k,floor(t*(.30+.018*k)+k*.37)))-.5)*.56+.10*sin(age*6.+k)*age;
  if(abs(p.x-sx)<.018 && abs(p.y-(.21+age*.77))<.023 && age<.94){
   ink=mix(vec3(1.,.74,.36),vec3(.95,.35,.12),age);opacity=1.;
  }
 }
 COLOR=vec4(ink,opacity);
}
