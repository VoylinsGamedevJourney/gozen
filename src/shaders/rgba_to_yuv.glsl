#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- INPUTS ---
layout(set = 0, binding = 0) uniform sampler2D input_image;

// --- OUTPUTS ---
// r8 format maps floats [0.0, 1.0] to 1-byte [0, 255] integers in memory.
layout(r8, set = 0, binding = 1) uniform writeonly image2D output_image;

// --- PARAMS ---
layout(set = 0, binding = 2, std140) uniform Params {
    mat4 color_matrix; // The conversion matrix (RGB to YUV).
    ivec2 resolution;  // The original resolution (Width, Height).
} params;


void main() {
    // uv_id maps to a single U/V pixel. Because YUV420 subsamples color by
    // half in both directions, 1 invocation handles a 2x2 block of RGBA pixels.
    ivec2 uv_id = ivec2(gl_GlobalInvocationID.xy);
    int W = params.resolution.x;
    int H = params.resolution.y;

    if (uv_id.x >= W / 2 || uv_id.y >= H / 2) {
        return;
    }

    // The top-left corner of the 2x2 RGBA block.
    ivec2 base_id = uv_id * 2;
    vec4 c00 = texelFetch(input_image, base_id + ivec2(0, 0), 0);
    vec4 c10 = texelFetch(input_image, base_id + ivec2(1, 0), 0);
    vec4 c01 = texelFetch(input_image, base_id + ivec2(0, 1), 0);
    vec4 c11 = texelFetch(input_image, base_id + ivec2(1, 1), 0);

    // Apply color matrix conversion (RGB to YUV).
    vec3 yuv00 = (params.color_matrix * vec4(c00.rgb, 1.0)).rgb;
    vec3 yuv10 = (params.color_matrix * vec4(c10.rgb, 1.0)).rgb;
    vec3 yuv01 = (params.color_matrix * vec4(c01.rgb, 1.0)).rgb;
    vec3 yuv11 = (params.color_matrix * vec4(c11.rgb, 1.0)).rgb;

    // --- WRITE Y PLANE ---
    // The Y plane takes up the first W * H bytes of the output buffer.
    // It maps exactly 1:1 with the original 2D resolution.
    imageStore(output_image, base_id + ivec2(0, 0), vec4(yuv00.x, 0.0, 0.0, 0.0));
    imageStore(output_image, base_id + ivec2(1, 0), vec4(yuv10.x, 0.0, 0.0, 0.0));
    imageStore(output_image, base_id + ivec2(0, 1), vec4(yuv01.x, 0.0, 0.0, 0.0));
    imageStore(output_image, base_id + ivec2(1, 1), vec4(yuv11.x, 0.0, 0.0, 0.0));

    // --- WRITE U & V PLANES ---
    // Average the chrominance values for the 2x2 block.
    float u_avg = (yuv00.y + yuv10.y + yuv01.y + yuv11.y) * 0.25;
    float v_avg = (yuv00.z + yuv10.z + yuv01.z + yuv11.z) * 0.25;

    // The linear index of the U/V pixel inside its specific plane.
    int uv_linear_idx = uv_id.y * (W / 2) + uv_id.x;

    // The U plane starts immediately after the Y plane.
    int u_total_idx = (W * H) + uv_linear_idx;
    ivec2 u_pos = ivec2(u_total_idx % W, u_total_idx / W);
    imageStore(output_image, u_pos, vec4(u_avg, 0.0, 0.0, 0.0));

    // The V plane starts immediately after the U plane.
    int v_total_idx = (W * H) + (W * H / 4) + uv_linear_idx;
    ivec2 v_pos = ivec2(v_total_idx % W, v_total_idx / W);
    imageStore(output_image, v_pos, vec4(v_avg, 0.0, 0.0, 0.0));
}
