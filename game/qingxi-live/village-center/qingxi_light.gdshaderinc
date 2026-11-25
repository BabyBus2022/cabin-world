// Qingxi village light layers, shared by qingxi_light_mul (multiply) and qingxi_light_add (additive):
//  multiply pass : time-of-day ambient colour; light sources cut warm, cel-stepped pools into it.
//  additive pass : soft glow halos around the same sources + whole-scene haze (dawn / golden hour).
// Positions are world px (the node sits at the world origin). Pools are squashed vertically
// to read as light lying on the ground in the 3/4 view.
uniform bool additive=false;
uniform vec4 ambient:source_color=vec4(1.0);
uniform vec4 haze:source_color=vec4(0.0,0.0,0.0,1.0);
uniform float vignette=0.0;
uniform int light_count=0;
uniform vec4 lights[40];       // xy = world pos, z = radius, w = intensity 0..1
uniform vec4 light_tints[40];  // rgb = colour
uniform float bands=4.0;
varying vec2 world_point;
void vertex(){world_point=VERTEX;}
void fragment(){
    vec2 p=floor(world_point/2.0)*2.0;     // light on the same 2px grid as the art
    vec3 lit=ambient.rgb;
    vec3 glow=vec3(0.0);
    for(int i=0;i<light_count;i++){
        vec2 d=p-lights[i].xy; d.y*=1.55;
        float f=clamp(1.0-length(d)/lights[i].z,0.0,1.0);
        float k=smoothstep(0.0,1.0,f)*lights[i].w;
        lit=max(lit,mix(ambient.rgb,light_tints[i].rgb,k));
        // Fixture glare is independent of the area receiving diffuse light.
        float halo=light_tints[i].a>0.0?light_tints[i].a:1.0;
        glow+=light_tints[i].rgb*pow(f,3.1)*lights[i].w*halo;
    }
    vec2 v=SCREEN_UV-0.5;
    float vig=1.0-vignette*smoothstep(0.25,0.75,length(v*vec2(1.0,1.25)));
    if(additive){
        COLOR=vec4(haze.rgb+glow*0.32,1.0);
    }else{
        COLOR=vec4(min(lit,vec3(1.0))*vig,1.0);
    }
}
