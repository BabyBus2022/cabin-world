shader_type canvas_item;
render_mode unshaded;
uniform vec4 sky_tint:source_color=vec4(1.0);
uniform float night_level=0.0;
void fragment() {
 vec4 c=texture(TEXTURE,UV);
 COLOR=vec4(c.rgb*sky_tint.rgb,step(.5,c.a));
}
