shader_type canvas_item;
uniform vec4 tint:source_color=vec4(1.0);
uniform float night_level=0.0;
void fragment(){COLOR=vec4(vec3(0.6235,0.749,0.447)*tint.rgb,1.0);}
