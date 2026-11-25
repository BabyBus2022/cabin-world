shader_type canvas_item;
render_mode unshaded;
uniform float fire_clock=0.0;
uniform float power=0.0;
void fragment(){
    // Discrete pixel clusters with independently bending flame tongues.
    vec2 p=floor(UV*vec2(48.0,64.0))/vec2(48.0,64.0);
    float t=floor(fire_clock*12.0)/12.0;
    float h=1.0-p.y;
    float sway=sin(t*5.2+h*8.0)*0.045*h;
    float width=(0.24*(1.0-h)+0.015)*(0.85+sin(h*21.0-t*8.0)*0.16);
    float shape=width-abs(p.x-0.5-sway);
    float left_h=0.72+sin(t*4.0)*0.10;
    float right_h=0.59+sin(t*4.8+1.4)*0.12;
    shape=max(shape,(0.14*(1.0-h/left_h))-abs(p.x-0.30-sin(t*6.0+h*9.0)*.035));
    shape=max(shape,(0.13*(1.0-h/right_h))-abs(p.x-0.68-sin(t*5.0+h*11.0)*.04));
    float visible=step(0.0,shape)*step(0.035,h)*step(h,0.95+sin(t*3.0)*0.025);
    float core=step(abs(p.x-0.50-sway),max(0.0,(0.14*(1.0-h*1.65))))*step(h,.58);
    float middle=step(0.035,shape)*step(h,.80);
    vec3 color=mix(vec3(1.0,.30,.06),vec3(1.0,.65,.12),middle);
    color=mix(color,vec3(1.0,.94,.61),core);
    COLOR=vec4(color,visible*power);
}
