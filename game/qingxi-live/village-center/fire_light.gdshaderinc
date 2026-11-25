uniform vec2 fire_position=vec2(1120.0,928.0);
uniform float fire_energy=0.0;
uniform vec2 lantern_positions[4];
uniform vec4 lantern_power=vec4(0.0);
float fire_reach(vec2 p){
    vec2 d=(p-fire_position)*vec2(1.0,1.18);
    return pow(clamp(1.0-length(d)/340.0,0.0,1.0),1.35)*fire_energy;
}
vec3 fire_illumination(vec3 ambient,vec2 p){
    vec3 lit=mix(ambient,vec3(1.65,1.04,0.52),clamp(fire_reach(p),0.0,0.96));
    float lamps=0.0;
    for(int i=0;i<4;i++)lamps=max(lamps,pow(clamp(1.0-distance(p,lantern_positions[i])/150.0,0.0,1.0),1.5)*lantern_power[i]);
    return mix(lit,vec3(1.25,1.09,0.78),lamps*.82);
}
