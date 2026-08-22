#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- INPUTS ---
layout(set = 0, binding = 0) uniform sampler2D input_image;

// --- OUTPUT ---
layout(rgba8, set = 0, binding = 1) uniform writeonly image2D output_image;

// --- PARAMS ---
layout(set = 0, binding = 2, std140) uniform Params {
    int direction; // 0=left, 1=right, 2=top, 3=bottom
    int pass_index;
} params;
layout(set = 0, binding = 3, std140) uniform Progress { float value; } progress;


void main() {
    ivec2 id = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(output_image);
    if (id.x >= size.x || id.y >= size.y) return;

    vec2 offset = vec2(0.0);
    float dist = 1.0 - progress.value;
    if (params.direction == 0) offset.x = dist * float(size.x);
    else if (params.direction == 1) offset.x = -dist * float(size.x);
    else if (params.direction == 2) offset.y = dist * float(size.y);
    else if (params.direction == 3) offset.y = -dist * float(size.y);

    ivec2 src_id = id + ivec2(offset);
    vec4 color = vec4(0.0);
    if (src_id.x >= 0 && src_id.x < size.x && src_id.y >= 0 && src_id.y < size.y) {
        color = texelFetch(input_image, src_id, 0);
    }

    imageStore(output_image, id, color);
}
