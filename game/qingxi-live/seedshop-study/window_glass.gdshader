shader_type canvas_item;
uniform vec3 glass_tint = vec3(1.0);
void fragment() {
 vec3 base = texture(TEXTURE, UV).rgb;
 float glass = smoothstep(0.025, 0.09, base.b-base.r) * smoothstep(0.025, 0.07, base.g-base.r);
 COLOR.rgb *= mix(vec3(1.0), glass_tint, glass);
}
