shader_type canvas_item;
render_mode unshaded;
uniform vec4 sky_tint:source_color=vec4(1.0);
uniform float night_level=0.0;
void fragment(){
    vec4 c=texture(TEXTURE,UV);
    float edge=0.0;
    edge=max(edge,texture(TEXTURE,UV+vec2(TEXTURE_PIXEL_SIZE.x,0.0)).a);
    edge=max(edge,texture(TEXTURE,UV-vec2(TEXTURE_PIXEL_SIZE.x,0.0)).a);
    edge=max(edge,texture(TEXTURE,UV+vec2(0.0,TEXTURE_PIXEL_SIZE.y)).a);
    edge=max(edge,texture(TEXTURE,UV-vec2(0.0,TEXTURE_PIXEL_SIZE.y)).a);
    vec3 palette=floor(c.rgb*12.0+0.5)/12.0;
    vec3 col=mix(vec3(0.24,0.25,0.23),palette,step(0.5,c.a));
    COLOR=vec4(col*sky_tint.rgb,max(step(0.5,c.a),step(0.5,edge)*0.90));
}
