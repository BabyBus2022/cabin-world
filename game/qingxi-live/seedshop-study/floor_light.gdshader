shader_type canvas_item;
uniform vec4 rooms[5];
uniform bool window_beam = false;
varying vec2 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,0.0,1.0)).xy; }
void fragment() {
 float inside = 0.0;
 for(int i=0;i<5;i++) {
  vec4 r=rooms[i];
  inside=max(inside,step(r.x,world_position.x)*step(r.y,world_position.y)*(1.0-step(r.z,world_position.x))*(1.0-step(r.w,world_position.y)));
 }
 COLOR.a *= inside;
 if(window_beam) {
  float edge=smoothstep(0.0,0.06,UV.x)*(1.0-smoothstep(0.94,1.0,UV.x));
  float fade=1.0-smoothstep(0.15,1.0,UV.y);
  float bars=1.0-0.52*(1.0-smoothstep(0.006,0.025,abs(fract(UV.x*4.0+0.5)-0.5)));
  COLOR.a *= edge*fade*bars;
 }
}
