shader_type canvas_item;
render_mode unshaded;
uniform vec2 extent=vec2(200.0,18.0);
uniform float feather=0.0;
void fragment() {
 vec2 p=floor(UV*extent);
 vec2 sample_uv=clamp(1.0-abs(mod(p/65.0,2.0)-1.0),vec2(.004),vec2(.996));
 vec4 c=texture(TEXTURE,sample_uv);
 float rough=mod(floor(p.x/5.0)*7.0,4.0);
 float inside=step(1.0+rough*.35,p.y)*step(p.y,extent.y-1.0-rough);
 inside*=step(1.0,p.x)*step(p.x,extent.x-1.0);
 float border=min(min(p.x,extent.x-p.x),min(p.y,extent.y-p.y));
 float soft_edge=floor(clamp(border/4.0,0.0,1.0)*4.0)/4.0;
 COLOR=vec4(c.rgb,inside*.92*mix(1.0,soft_edge,feather));
}
