shader_type spatial;
render_mode unshaded,cull_disabled;
uniform sampler2D art:source_color,filter_nearest;
uniform vec4 daylight:source_color=vec4(1.0);
void fragment(){vec4 c=texture(art,UV);ALBEDO=c.rgb*daylight.rgb;ALPHA=c.a;ALPHA_SCISSOR_THRESHOLD=.5;}
