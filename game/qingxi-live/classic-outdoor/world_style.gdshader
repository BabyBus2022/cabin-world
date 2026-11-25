shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_image:hint_screen_texture,repeat_disable,filter_nearest;
uniform sampler2D actor_mask:repeat_disable,filter_nearest;
uniform sampler2D world_image:repeat_disable,filter_nearest;
uniform bool use_world=false;
uniform float pixel_step=3.0;
uniform int style_mode=1;
float luminance(vec3 c){return dot(c,vec3(.299,.587,.114));}
void fragment(){
 vec2 size=1.0/SCREEN_PIXEL_SIZE;
 vec2 snapped=(floor(SCREEN_UV*size/pixel_step)+vec2(.5))*pixel_step/size;
 float actor=texture(actor_mask,SCREEN_UV).a;
 vec3 c=actor>.02?texture(screen_image,SCREEN_UV).rgb:(use_world?texture(world_image,SCREEN_UV).rgb:texture(screen_image,snapped).rgb);
 if(style_mode>0 && actor<=.02){
  // Compress highlights without blurring source pixels or touching character art.
  vec3 soft=c/(vec3(1.0)+max(c-vec3(.55),vec3(0.0))*.45);
  float l=luminance(soft);
  c=mix(vec3(l),soft,.88);
  if(style_mode==1){
   vec2 step_=1.0/vec2(textureSize(world_image,0));
   float right=luminance(texture(world_image,SCREEN_UV+vec2(step_.x,0)).rgb);
   float below=luminance(texture(world_image,SCREEN_UV+vec2(0,step_.y)).rgb);
   float edge=smoothstep(.13,.35,max(abs(luminance(soft)-right),abs(luminance(soft)-below)));
   c=mix(c,c*vec3(.86,.87,.91),edge*.45);
  }else{
   // Stable broad pencil hatching in the shaded areas; no moving noise.
   vec2 p=floor(SCREEN_UV*vec2(textureSize(world_image,0)));
   float hatch=step(.88,fract((p.x+p.y)/9.0));
   float shadow=1.0-smoothstep(.25,.60,l);
   c=mix(c,c*vec3(.88,.85,.82),hatch*shadow*.32);
   c=mix(c,vec3(.89,.85,.74),.045);
  }
 }
 COLOR=vec4(c,1.0);
}

