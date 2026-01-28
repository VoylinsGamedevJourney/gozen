#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- INPUTS ---
layout(set = 0, binding = 0) uniform sampler2D input_image;

// --- OUTPUT ---
layout(rgba8, set = 0, binding = 1) uniform writeonly image2D output_image;

// --- PARAMS ---
layout(set = 0, binding = 2, std140) uniform Params {
    float opacity;
} params;

void main() {
    ivec2 id = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(output_image);

    if (id.x >= size.x || id.y >= size.y)
        return;

    vec4 color = texelFetch(input_image, id, 0);

    color.a *= params.opacity;

    imageStore(output_image, id, color);
}
