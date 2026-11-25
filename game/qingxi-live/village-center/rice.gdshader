shader_type canvas_item;
uniform float age = 0.0;
uniform float wind_strength = 0.5;
uniform vec2 breeze = vec2(0.95, -0.31);
uniform vec2 field_origin;
uniform vec2 sun_side;
uniform float sunlight = 0.6;
uniform float growth = 1.0;
uniform int season = 1;
uniform vec2 standing = vec2(0.0,512.0);
uniform vec4 ground_light = vec4(1.0);
varying float presence;

void vertex() {
    vec2 root = UV;
    vec2 place = root + field_origin;
    vec2 offset = VERTEX - root;
    float phase = dot(place, breeze)*0.020 - age*1.85;
    float seed = fract(sin(dot(root, vec2(12.9898,78.233))) * 43758.5);
    float envelope = 0.50 + 0.50*sin(phase*0.43+sin(place.y*0.009-age*0.28));
    float common = sin(phase + 0.37*sin(place.y*0.033)) * envelope;
    float motion = (common + 0.16*sin(age*3.8+seed*6.28)) * wind_strength;
    float tip = clamp(-offset.y/22.0,0.0,1.3);
    float height = season==0 ? 0.40 : (season==1 ? 0.68+growth*0.42 : 1.04);
    offset *= vec2(0.65+0.35*height,height);
    offset += vec2(breeze.x, breeze.y*0.38)*motion*8.4*tip*tip*height;
    VERTEX = root+offset;
    bool ear = COLOR.b > 0.5;
    presence = (root.x>=standing.x && root.x<=standing.y && (!ear || season==2)) ? 1.0 : 0.0;
    float facing = (COLOR.g-0.5)*1.5 + motion*breeze.x*0.85;
    float blade_light = clamp(0.5 + facing*sun_side.x*0.70 - common*breeze.y*sun_side.y*0.35,0.0,1.0);
    // Neighbouring blades turn together in a passing gust. Their shared angle broadens the glint.
    float aligned = envelope * smoothstep(0.16,0.82,abs(common)) * wind_strength;
    float reflection = sunlight*blade_light*blade_light*(0.14+0.57*aligned)*tip;
    vec3 dark = season==2 ? vec3(0.48,0.34,0.16) : vec3(0.17,0.36,0.23);
    vec3 light = season==2 ? vec3(0.88,0.67,0.28) : vec3(0.54,0.76,0.31);
    vec3 pigment = mix(dark, light, COLOR.r);
    if(ear){pigment=mix(vec3(0.72,0.46,0.16),vec3(0.98,0.79,0.38),COLOR.r);}
    COLOR=vec4(mix(pigment, season==2 ? vec3(1.0,0.90,0.57) : vec3(0.85,0.94,0.58),clamp(reflection,0.0,0.8))*ground_light.rgb,1.0);
}
void fragment(){ if(presence<0.5){discard;} }

