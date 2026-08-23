#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- INPUTS ---
layout(set = 0, binding = 0) uniform sampler2D input_image;

// --- OUTPUT ---
layout(rgba8, set = 0, binding = 1) uniform writeonly image2D output_image;

// --- PARAMS ---
layout(set = 0, binding = 2, std140) uniform Params {
    float seed;
    int pass_index;
} params;
layout(set = 0, binding = 3, std140) uniform Progress { float value; } progress;


float rand(vec2 co){ return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453); }


void main() {
    ivec2 id = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(output_image);
    if (id.x >= size.x || id.y >= size.y) return;

    vec4 color = texelFetch(input_image, id, 0);
    float noise = rand(vec2(id) / vec2(size) + params.seed);
    if (noise > progress.value) { color.a = 0.0; }

    imageStore(output_image, id, color);
}
