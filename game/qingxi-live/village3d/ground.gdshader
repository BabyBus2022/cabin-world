shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform sampler2D grass_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D route_mask : filter_linear, repeat_disable;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 q=floor(world_position.xz*24.0)/24.0;
 float path=texture(route_mask,(q+vec2(48.0))/96.0).r;
 vec3 grass=texture(grass_tex,q/5.5).rgb;
 vec3 dirt=texture(dirt_tex,q/4.0).rgb;
 float patch=sin(q.x*0.33+sin(q.y*0.23))*sin(q.y*0.27+q.x*0.12);
 ALBEDO=mix(grass*(0.96+patch*0.045),dirt,smoothstep(0.18,0.82,path))*0.45;
 ROUGHNESS=1.0;
}
