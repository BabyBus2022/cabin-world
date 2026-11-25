shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_image : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D actor_mask : repeat_disable, filter_nearest;
uniform sampler2D world_image : repeat_disable, filter_nearest;
uniform bool use_world=false;
uniform float pixel_step=3.0;
void fragment(){
 vec2 size=1.0/SCREEN_PIXEL_SIZE;
 vec2 snapped=(floor(SCREEN_UV*size/pixel_step)+vec2(0.5))*pixel_step/size;
 // Character sprites retain their source detail; environmental surfaces,
 // geometry edges and shadows all share the same display pixel grid.
 float actor=texture(actor_mask,SCREEN_UV).a;
 vec4 color=actor>0.02?texture(screen_image,SCREEN_UV):(use_world?texture(world_image,SCREEN_UV):texture(screen_image,snapped));
 COLOR=vec4(color.rgb,1.0);
}
