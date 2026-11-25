shader_type spatial;
render_mode unshaded;
uniform sampler2D grain : source_color, filter_nearest, repeat_enable;
uniform vec4 daylight : source_color = vec4(1.0);

float hash(vec2 p) {
 return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
 vec2 grid = vec2(576.0, 232.0);
 vec2 pixel = floor(UV * grid);
 vec2 patch = floor(pixel / 10.0);
 float straw = texture(grain, fract(pixel / 13.0)).r;
 float fleck = step(.84, hash(floor(vec2(pixel.x + pixel.y * .6, pixel.y) / vec2(6.0, 1.0))));
 float tone = .26 + straw * .22 + hash(patch) * .10 + fleck * .27;
 vec3 base = mix(vec3(.61, .40, .16), vec3(.98, .81, .46), tone);
 vec2 edge = min(pixel, grid - pixel);
 if (min(edge.x, edge.y) < 1.0 + 6.0 * hash(floor(pixel / 3.0))) discard;
 ALBEDO = base * daylight.rgb;
}
