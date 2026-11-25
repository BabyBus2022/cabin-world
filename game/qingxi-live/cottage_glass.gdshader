shader_type canvas_item;
render_mode unshaded;
uniform vec4 sky_color : source_color = vec4(.75,.82,.92,.0);
uniform float rain = 0.;
uniform float snow = 0.;
uniform float wind = 0.;
varying vec2 pos;
void vertex(){pos=(MODEL_MATRIX*vec4(VERTEX,0.,1.)).xy;}
float hash(vec2 v){return fract(sin(dot(v,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
	float mask=COLOR.a;
	vec4 ink=sky_color;
	if(rain>0. || snow>0.){
		bool flakes=snow>0.;
		vec2 at=floor(pos*1.25);
		float t=TIME;
		float lean=flakes?0.:.10+.035*wind;
		at.x-=at.y*lean;
		at.y-=t*(flakes?17.:125.+55.*rain);
		at.x-=flakes?(sin(t*.9+floor(at.y/12.))*2.+t*wind):0.;
		vec2 pitch=flakes?vec2(9.,12.):vec2(8.,16.);
		vec2 cell=floor(at/pitch);
		vec2 delta=mod(at,pitch)-pitch*(.2+.6*vec2(hash(cell),hash(cell+7.)));
		float size=hash(cell+13.)>.75?1.45:.9;
		bool particle=flakes?length(delta)<size:(abs(delta.x)<.73 && abs(delta.y)<1.5+2.5*rain);
		if(particle && hash(cell+4.)<(flakes?.65:.4+.44*rain)){
			ink=mix(ink,flakes?vec4(.88,.94,1.,.90):vec4(.70,.84,.96,.65),.79);
		}
	}
	COLOR=vec4(ink.rgb,mask*ink.a);
}
