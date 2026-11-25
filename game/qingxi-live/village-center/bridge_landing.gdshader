shader_type canvas_item;
uniform sampler2D deck : source_color, filter_nearest;
uniform vec2 extent;
uniform float bank_seed;

// Stagger the courses toward the lane. The last few stones sit separately in the earth.
float rand2(vec2 v){return fract(sin(dot(v,vec2(12.9898,78.233)))*43758.5453);}
void fragment(){
 vec2 p=floor(UV*extent);
 float t=p.x/extent.x;
 float row=floor(p.y/5.);
 float offset=mod(row,2.)*5.+floor(rand2(vec2(row,bank_seed))*3.);
 vec2 cell=vec2(floor((p.x+offset)/11.),row);
 float n=rand2(cell+bank_seed);
 vec2 seam=vec2(mod(p.x+offset,11.),mod(p.y,5.));
 float edge=abs(UV.y-.5)*2.;
 float outline=.77+.15*t+.10*n;
 float cover=step(edge,outline)*step(t,.66+n*.33);
 float bevel=step(.5,seam.x)*step(.5,seam.y);
 float joints=mix(.75,1.,bevel);
 vec3 stone=texture(deck,(vec2(28.,20.)+vec2(mod(p.x+bank_seed+32.,65.),mod(p.y,11.)))/vec2(textureSize(deck,0))).rgb;
 vec3 paving=texture(TEXTURE,fract((p+vec2(bank_seed,0.)) / 58.)).rgb;
 vec3 c=mix(stone,paving,.32+.36*t)*joints*(.92+.12*n);
 float separation=smoothstep(.40,.90,t)*(1.-bevel);
 COLOR=vec4(c,cover*(1.-.92*separation)*(.98-.27*t));
}
