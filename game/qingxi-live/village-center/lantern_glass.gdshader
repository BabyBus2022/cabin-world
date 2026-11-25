shader_type canvas_item;
render_mode unshaded,blend_add;
void fragment(){
 vec4 base=texture(TEXTURE,UV);
 vec2 px=UV/ TEXTURE_PIXEL_SIZE;
 // Use the artwork's existing lit paper windows; the wooden lattice stays dark.
 float window=step(45.,px.y)*step(px.y,86.)*step(21.,px.x)*step(px.x,75.);
 float paper=smoothstep(.48,.83,base.r)*smoothstep(.32,.63,base.g);
 COLOR=vec4(1.,.75,.40,window*base.a*paper*.85);
}
