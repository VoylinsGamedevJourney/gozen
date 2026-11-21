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
	int pass_index;
} params;


void main() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	ivec2 out_size = imageSize(output_image);
	if (id.x >= out_size.x || id.y >= out_size.y) {
		return; // Boundary check.
	}

	vec4 center_color = texelFetch(source_image, id, 0);
	if (params.amount <= 0.0) {
		imageStore(output_image, id, center_color);
		return;
	}

	float sigma = params.amount * 10.0;
	int radius = clamp(int(ceil(sigma * 3.0)), 1, 20);
	float inv_two_sigma_sq = 1.0 / (2.0 * sigma * sigma);

	vec4 color_sum = center_color;
	float weight_sum = 1.0;
	ivec2 step_direction = (params.pass_index == 0) ? ivec2(1, 0) : ivec2(0, 1);
	ivec2 max_coord = out_size - ivec2(1);

	for (int offset = 1; offset <= radius; offset++) {
		float weight = exp(-float(offset * offset) * inv_two_sigma_sq);
		ivec2 positive_coord = clamp(id + step_direction * offset, ivec2(0), max_coord);
		ivec2 negative_coord = clamp(id - step_direction * offset, ivec2(0), max_coord);

		color_sum += (texelFetch(source_image, positive_coord, 0) + texelFetch(source_image, negative_coord, 0)) * weight;
		weight_sum += 2.0 * weight;
	}

	imageStore(output_image, id, color_sum / weight_sum);
}
