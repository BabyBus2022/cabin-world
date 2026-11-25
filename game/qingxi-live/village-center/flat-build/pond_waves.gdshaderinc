// Mask sampling and phase must agree on both sides of the fish sprites.
uniform sampler2D mask:filter_nearest,repeat_disable;
vec4 ground_field(vec2 texel,vec2 p){
 vec2 q=(p+.5)/32.-.5, at=floor(q), f=fract(q);
 vec2 sm=f*f*(3.-2.*f);
 vec4 a=texture(mask,(at+.5)*texel);
 vec4 b=texture(mask,(at+vec2(1.5,.5))*texel);
 vec4 c=texture(mask,(at+vec2(.5,1.5))*texel);
 vec4 d=texture(mask,(at+1.5)*texel);
 vec2 shape=mix(mix(a.rg,b.rg,sm.x),mix(c.rg,d.rg,sm.x),sm.y);
 return vec4(shape,mix(mix(a.ba,b.ba,f.x),mix(c.ba,d.ba,f.x),f.y));
}
float shoreline(vec2 p){
 return .015*sin(p.x*.29+p.y*.13)+.014*sin(p.y*.4)
      +.022*sin(p.y*.077+sin(p.x*.045))+.015*sin(p.x*.11+p.y*.05);
}
vec2 lake_slope(vec2 p,float t){
 // Two long swells and finer wind waves travel at different angles and speeds.
 float a=dot(p,vec2(.042,.135))+t*.99+1.1*sin(p.x*.035-t*.25);
 float b=dot(p,vec2(-.078,.081))-t*.61+.82*sin(p.y*.052+t*.21);
 float c=p.y*.39+1.4*sin(a*.52)+.85*sin(p.x*.085+t*.38)-t*1.63;
 return vec2(.52*cos(a)-.49*cos(b)+.19*cos(c),.56*cos(a)+.27*cos(b)+.29*cos(c));
}
float rand2(vec2 p){return fract(sin(dot(p,vec2(27.61,57.37)))*4375.81);}

float pond_noise(vec2 p){
 vec2 cell=floor(p), f=fract(p);
 f=f*f*(3.-2.*f);
 return mix(mix(rand2(cell),rand2(cell+vec2(1,0)),f.x),
            mix(rand2(cell+vec2(0,1)),rand2(cell+1.),f.x),f.y);
}

