#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D input_image;
layout(r8, set = 0, binding = 1) uniform restrict writeonly image2D y_image;
layout(r8, set = 0, binding = 2) uniform restrict writeonly image2D u_image;
layout(r8, set = 0, binding = 3) uniform restrict writeonly image2D v_image;

layout(push_constant, std430) uniform Params {
    int width;
    int height;
} params;


void main() {
    ivec2 id = ivec2(gl_GlobalInvocationID.xy);
    if (id.x >= params.width || id.y >= params.height) return;

    vec4 color = texelFetch(input_image, id, 0);
    float r = color.r;
    float g = color.g;
    float b = color.b;

    float y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    float y_val = clamp(y * 219.0 + 16.0, 16.0, 235.0) / 255.0;
    imageStore(y_image, id, vec4(y_val, 0.0, 0.0, 1.0));

    if (id.x % 2 == 0 && id.y % 2 == 0) {
		// Each U/V is being used for a square of Y data.
		// YY   U.   V.
		// YY   ..   ..
        vec4 c00 = color;
        vec4 c10 = texelFetch(input_image, id + ivec2(1, 0), 0);
        vec4 c01 = texelFetch(input_image, id + ivec2(0, 1), 0);
        vec4 c11 = texelFetch(input_image, id + ivec2(1, 1), 0);
        vec4 avg = (c00 + c10 + c01 + c11) * 0.25;

        float ar = avg.r;
        float ag = avg.g;
        float ab = avg.b;

        float u = -0.1146 * ar - 0.3854 * ag + 0.5000 * ab;
        float v = 0.5000 * ar - 0.4542 * ag - 0.0458 * ab;

        float u_val = clamp(u * 224.0 + 128.0, 16.0, 240.0) / 255.0;
        float v_val = clamp(v * 224.0 + 128.0, 16.0, 240.0) / 255.0;

        ivec2 uv_id = id / 2;
        imageStore(u_image, uv_id, vec4(u_val, 0.0, 0.0, 1.0));
        imageStore(v_image, uv_id, vec4(v_val, 0.0, 0.0, 1.0));
    }
}
