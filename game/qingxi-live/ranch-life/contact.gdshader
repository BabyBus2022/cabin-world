shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
void fragment(){float d=length(UV*2.0-1.0);ALBEDO=vec3(.19,.20,.16);ALPHA=step(d,.96)*.19*(1.0-d*.5);}
