shader_type canvas_item;
uniform vec4 sky_tint:source_color=vec4(1.0);
uniform float night_level=0.0;
uniform float glow=0.0;
uniform vec2 native_grid=vec2(128.0);
varying vec4 vertex_tint;
void vertex(){vertex_tint=COLOR;}
void fragment(){
 vec2 pixel_uv=(floor(UV*native_grid)+vec2(0.5))/native_grid;
 vec4 c=texture(TEXTURE,pixel_uv);
 if(c.a<0.5){discard;}
 COLOR=vec4(c.rgb*sky_tint.rgb,1.0)*vertex_tint;
}
