#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- INPUT ---
layout(set = 0, binding = 0) uniform sampler2D source_image;

// --- OUTPUT ---
layout(rgba8, set = 0, binding = 1) uniform writeonly image2D output_image;

// --- PARAMS ---
layout(set = 0, binding = 2, std140) uniform Params {
    vec4 color;
    float radius;
    float softness;
    float center_x;
    float center_y;
} params;


void main() {
    ivec2 id = ivec2(gl_GlobalInvocationID.xy);
    ivec2 out_size = imageSize(output_image);

    if (id.x >= out_size.x || id.y >= out_size.y) {
        return;
    }

    vec4 color = texelFetch(source_image, id, 0);
    vec2 center = vec2(params.center_x, params.center_y);
    vec2 position = vec2(id.x, id.y);
    float distance = distance(position, center);
    float mix_value = smoothstep(params.radius, params.radius + max(params.softness, 0.001), distance);

    color.rgb = mix(color.rgb, params.color.rgb, mix_value * params.color.a);
    imageStore(output_image, id, color);
}
