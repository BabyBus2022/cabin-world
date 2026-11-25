shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
// A narrow silhouette, not a thick black cartoon border. The real tool mesh
// supplies the outline; the world pass puts it on the same pixel grid.
void vertex(){ VERTEX+=NORMAL*0.022; }
void fragment(){ ALBEDO=vec3(0.20,0.19,0.25); }
