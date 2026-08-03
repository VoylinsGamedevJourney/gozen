#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- INPUTS ---
layout(set = 0, binding = 0) uniform sampler2D input_image;

// --- OUTPUT ---
layout(rgba8, set = 0, binding = 1) uniform writeonly image2D output_image;

// --- PARAMS ---
layout(set = 0, binding = 2, std140) uniform Params {
    int direction; // 0=left->right, 1=right->left, 2=top->bottom, 3=bottom->top.
    int pass_index;
} params;
layout(set = 0, binding = 3, std140) uniform Progress { float value; } progress;


void main() {
    ivec2 id = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(output_image);

    if (id.x >= size.x || id.y >= size.y) return;
    vec4 color = texelFetch(input_image, id, 0);
    float p = 0.0;

    if (params.direction == 0) p = float(id.x) / float(size.x);
    else if (params.direction == 1) p = 1.0 - float(id.x) / float(size.x);
    else if (params.direction == 2) p = float(id.y) / float(size.y);
    else if (params.direction == 3) p = 1.0 - float(id.y) / float(size.y);

    if (p > progress.value) { color.a = 0.0; }
    imageStore(output_image, id, color);
}
