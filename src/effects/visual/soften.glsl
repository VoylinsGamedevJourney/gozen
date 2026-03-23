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
} params;


void main() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	ivec2 out_size = imageSize(output_image);
	if (id.x >= out_size.x || id.y >= out_size.y) {
		return; // Boundary check.
	}

	if (params.amount <= 0.0) {
		imageStore(output_image, id, texelFetch(source_image, id, 0));
		return;
	}

	float sigma = params.amount * 10.0;
    int radius = clamp(int(ceil(sigma * 3.0)), 1, 20);
    vec4 color_sum = vec4(0.0);
    float weight_sum = 0.0;
    float two_sigma_sq = 2.0 * sigma * sigma;
    for (int x = -radius; x <= radius; x++) {
        for (int y = -radius; y <= radius; y++) {
            float weight = exp(-float(x * x + y * y) / two_sigma_sq);
            ivec2 coord = clamp(id + ivec2(x, y), ivec2(0), out_size - ivec2(1));
            color_sum += texelFetch(source_image, coord, 0) * weight;
            weight_sum += weight;
        }
    }
    imageStore(output_image, id, color_sum / weight_sum);
}
