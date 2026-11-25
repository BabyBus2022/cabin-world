shader_type canvas_item;
render_mode unshaded;
#include "res://qingxi-live/village-center/flat-build/pond_waves.gdshaderinc"
uniform vec4 tint:source_color=vec4(1.);
uniform float sunlight=.8;
uniform float rainfall=0.;
uniform float sky_time=.54;
uniform float clear_sky=1.;
uniform float cloud_cover=.18;
uniform sampler2D reflected_banks:source_color,filter_linear,repeat_disable;

// The four samples must match exactly across neighbouring cells, even when
// the graphics driver reassociates floating-point additions.
float cloud_corner(ivec2 cell){
 uint h=uint(cell.x)*1597334677u ^ uint(cell.y)*3812015801u;
 h=(h^(h>>16u))*2246822519u;
 return float((h^(h>>13u))&65535u)/65535.;
}
float mist(vec2 p){
 ivec2 cell=ivec2(floor(p));
 vec2 f=fract(p);
 f=f*f*(3.-2.*f);
 return mix(mix(cloud_corner(cell),cloud_corner(cell+ivec2(1,0)),f.x),
            mix(cloud_corner(cell+ivec2(0,1)),cloud_corner(cell+ivec2(1,1)),f.x),f.y);
}
void fragment(){
 vec2 p=floor(UV/TEXTURE_PIXEL_SIZE*32.);
 vec4 field=ground_field(TEXTURE_PIXEL_SIZE,p);
 float water=field.g+shoreline(p);
 if(water<.51){discard;}
 vec2 pos=floor(UV/TEXTURE_PIXEL_SIZE*64.);
 vec2 slope=lake_slope(pos,TIME);
 float height=sin((sky_time-.25)*6.283185);
 float day=smoothstep(-.17,.20,height);
 float warm=1.-smoothstep(.02,.62,abs(height));
 float horizontal=cos((sky_time-.25)*6.283185);
 vec2 sky_uv=(pos+vec2(TIME*.93,-TIME*.29)+slope*vec2(5.,9.))/vec2(91.,57.);
 float cloud=.69*mist(sky_uv)+.31*mist(sky_uv*2.3);
 float veil=smoothstep(.36,.79,cloud)*(.35+.65*cloud_cover);
 vec3 daylight=mix(vec3(.44,.72,.80),vec3(.95,.60,.38),warm);
 vec3 sky=mix(vec3(.23,.37,.60),daylight,day);
 float facing=smoothstep(-.65,.96,slope.y);
 float sky_alpha=(.025+.26*veil)*(.45+.55*facing)*smoothstep(.01,.32,field.b);
 vec2 bend=(slope*vec2(3.,1.65)+vec2(sin(pos.y*.30+TIME)*1.6,0.))*TEXTURE_PIXEL_SIZE/64.;
 vec4 bank=texture(reflected_banks,UV+bend);
 float ba=bank.a*(.34+.27*facing);
 vec3 reflected=sky*sky_alpha*(1.-ba)+bank.rgb*vec3(.52,.68,.63)*ba;
 float alpha=sky_alpha*(1.-ba)+ba;
 // A changing strip of wave facets catches the sun (or moon) on each basin.
 float strip_center=.5-.31*horizontal+.037*sin(pos.y*.017+horizontal);
 float dx=(field.a-strip_center)/(.14+.10*max(height,0.));
 float strip=exp(-dx*dx);
 float wave=pos.y*.54+pos.x*.067+2.6*slope.x+1.3*sin(pos.x*.052-TIME*.23)-TIME*1.58;
 float facet=smoothstep(.24,.88,slope.y+.25*horizontal*slope.x);
 float patch=mist(pos/vec2(9.,5.)+vec2(TIME*.15,-TIME*.11));
 float capillary=cos(pos.y*1.1+pos.x*.21+.83*sin(pos.x*.32+TIME*.41)-TIME*2.24);
 float fleck=smoothstep(.53,.995,cos(wave))*facet*mix(.10,1.,smoothstep(.24,.73,patch));
 fleck+=.38*smoothstep(.79,.995,capillary)*smoothstep(.55,.91,patch)*facet;
 float clarity=(1.-.74*cloud_cover)*(1.-.80*rainfall);
 float gleam=fleck*(.055+strip*(.35+.55*day))*clarity*mix(.78,.32+.68*clear_sky,day);
 gleam+=(.025+.038*warm)*strip*facet*clarity;
 vec3 lit=mix(vec3(.62,.80,.98),mix(vec3(.97,.97,.80),vec3(1.,.72,.36),warm),day);
 reflected=reflected*(1.-gleam)+lit*gleam;
 alpha=alpha*(1.-gleam)+gleam;
 COLOR=vec4(reflected/max(alpha,.0001)*mix(max(tint.rgb,vec3(.45)),vec3(1.),.17),
            alpha*smoothstep(.51,.64,water));
}
