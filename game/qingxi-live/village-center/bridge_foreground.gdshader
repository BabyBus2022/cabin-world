shader_type canvas_item;
uniform bool vertical = false;
uniform bool stone = false;
void fragment() {
    vec2 uv = UV;
    vec4 texel = COLOR;
    float side = min(uv.x, 1.0 - uv.x);
    bool front = vertical
        ? (side < (stone ? 0.19 : 0.20) || uv.y > 0.93)
        : (uv.y > (stone ? 0.60 : 0.52) || (side < 0.19 && uv.y > 0.45));
    COLOR = front ? texel : vec4(0.0);
}

