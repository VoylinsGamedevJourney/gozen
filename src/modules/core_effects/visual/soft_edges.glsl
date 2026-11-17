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
	ivec2 pixel_coord = ivec2(gl_GlobalInvocationID.xy);
	ivec2 output_size = imageSize(output_image);
	if (pixel_coord.x >= output_size.x || pixel_coord.y >= output_size.y) {
		return;
	}

	vec4 center_color = texelFetch(source_image, pixel_coord, 0);
	if (params.amount <= 0.0 || center_color.a <= 0.0) {
		imageStore(output_image, pixel_coord, center_color);
		return;
	}

	float weight_sum = 0.0;
	float coverage = 0.0;

	float distance_x = min(float(pixel_coord.x), float(output_size.x - 1 - pixel_coord.x));
	float distance_y = min(float(pixel_coord.y), float(output_size.y - 1 - pixel_coord.y));
	float frame_mask = smoothstep(0.0, params.amount, distance_x) * smoothstep(0.0, params.amount, distance_y);
	float sigma = max(params.amount / 2.5, 0.1);
	float two_sigma_squared = 2.0 * sigma * sigma;
	int sample_count = clamp(int(params.amount * 5.0), 32, 1024);

	for (int sample_index = 0; sample_index < sample_count; sample_index++) {
		float sample_angle = float(sample_index) * 2.39996323;
		float sample_radius = (sqrt(float(sample_index) + 0.5) / sqrt(float(sample_count))) * params.amount;
		ivec2 sample_coord = pixel_coord + ivec2(
				round(cos(sample_angle) * sample_radius),
				round(sin(sample_angle) * sample_radius));

		float sample_weight = exp(-(sample_radius * sample_radius) / two_sigma_squared);
		if (sample_coord.x >= 0 && sample_coord.y >= 0 && sample_coord.x < output_size.x && sample_coord.y < output_size.y) {
			if (texelFetch(source_image, sample_coord, 0).a > 0.001) {
				coverage += sample_weight;
			}
		} else {
			coverage += sample_weight;
		}
		weight_sum += sample_weight;
	}

	center_color.a *= frame_mask * clamp(((coverage / weight_sum) - 0.5) / 0.49, 0.0, 1.0);
	imageStore(output_image, pixel_coord, center_color);
}
