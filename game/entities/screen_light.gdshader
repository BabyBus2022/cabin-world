shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D screen : hint_screen_texture, repeat_disable, filter_nearest;
uniform int count = 0;
uniform vec4 geometry[64];
uniform vec4 clips[64];
uniform vec4 first_color[64];
uniform vec4 middle_color[64];
uniform vec4 last_color[64];
uniform float middle_stop[64];
varying vec2 room_position;
void vertex() { room_position = VERTEX; }
void fragment() {
    vec4 background = textureLod(screen, SCREEN_UV, 0.0);
    vec3 result = background.rgb;
    for (int i=0; i<count; i++) {
        vec4 box=clips[i];
        if (room_position.x<box.x || room_position.y<box.y || room_position.x>=box.x+box.z || room_position.y>=box.y+box.w) { continue; }
        vec4 g=geometry[i];
        float t=clamp((distance(room_position,g.xy)-g.w)/max(0.001,g.z-g.w),0.0,1.0);
        float mid=middle_stop[i];
        vec4 light=t<=mid ? mix(first_color[i],middle_color[i],t/mid) : mix(middle_color[i],last_color[i],(t-mid)/(1.0-mid));
        result=1.0-(1.0-result)*(1.0-light.rgb*light.a);
    }
    COLOR=vec4(result,background.a);
}
