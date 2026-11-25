shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D paving : source_color, filter_nearest, repeat_enable;
uniform vec4 daylight : source_color = vec4(1.0);
varying vec2 ground;

void vertex() {
 ground = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
 vec2 uv = 1.0 - abs(mod(ground * .3, 2.0) - 1.0);
 float shade = mix(.28, .97, smoothstep(-22.0, -8.0, ground.y));
 ALBEDO = texture(paving, uv).rgb * shade * daylight.rgb;
}
