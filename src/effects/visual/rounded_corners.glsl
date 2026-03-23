#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- INPUT ---
layout(set = 0, binding = 0) uniform sampler2D source_image;

// --- OUTPUT ---
layout(rgba8, set = 0, binding = 1) uniform writeonly image2D output_image;

// --- PARAMS ---
layout(set = 0, binding = 2, std140) uniform Params {
    float radius;
    float width;
    float height;
    float center_x;
    float center_y;
} params;


float roundedBoxSDF(vec2 CenterPosition, vec2 Size, float Radius) {
    return length(max(abs(CenterPosition) - Size + Radius, 0.0)) - Radius;
}


void main() {
    ivec2 id = ivec2(gl_GlobalInvocationID.xy);
    ivec2 out_size = imageSize(output_image);

    if (id.x >= out_size.x || id.y >= out_size.y) {
        return;
    }

    vec4 color = texelFetch(source_image, id, 0);
    vec2 center = vec2(params.center_x, params.center_y);
    vec2 size = vec2(params.width, params.height) / 2.0;
    vec2 pos = vec2(id.x, id.y) - center;
    float distance = roundedBoxSDF(pos, size, params.radius);
    float alpha = 1.0 - smoothstep(-0.5, 1.0, distance); // Smoothstep of 1.5 pixels.

    color.a *= alpha;
    imageStore(output_image, id, color);
}
