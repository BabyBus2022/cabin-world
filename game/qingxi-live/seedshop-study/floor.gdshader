shader_type canvas_item;
void fragment(){
 vec4 c=texture(TEXTURE,UV);
 float value=dot(c.rgb,vec3(.299,.587,.114));
 c.rgb=mix(vec3(value),c.rgb,.62)*.94+vec3(.105,.108,.10);
 COLOR=c;
}
