#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- INPUT ---
layout(set = 0, binding = 0) uniform sampler2D source_image;

// --- OUTPUT ---
layout(rgba8, set = 0, binding = 1) uniform writeonly image2D output_image;

// --- PARAMS ---
layout(set = 0, binding = 2, std140) uniform Params {
    float amount;
    float seed;
} params;



float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}


void main() {
    ivec2 id = ivec2(gl_GlobalInvocationID.xy);
    ivec2 out_size = imageSize(output_image);
    if (id.x >= out_size.x || id.y >= out_size.y) {
		return;
	}

    vec4 color = texelFetch(source_image, id, 0);
    if (params.amount > 0.0) {
        float noise = rand(vec2(id) / vec2(out_size) + params.seed) * 2.0 - 1.0;
        color.rgb += noise * params.amount;
        color.rgb = clamp(color.rgb, 0.0, 1.0);
    }
    imageStore(output_image, id, color);
}
