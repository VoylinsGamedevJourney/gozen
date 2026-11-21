#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- INPUT ---
layout(set = 0, binding = 0) uniform sampler2D source_image;

// --- OUTPUT ---
layout(rgba8, set = 0, binding = 1) uniform writeonly image2D output_image;

// --- PARAMS ---
layout(set = 0, binding = 2, std140) uniform Params {
	float fade;
	float intensity;
	vec4 color;
} params;



void main() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	ivec2 out_size = imageSize(output_image);
	if (id.x >= out_size.x || id.y >= out_size.y) {
		return;
	}

	vec4 foreground_color = texelFetch(source_image, id, 0);
	if (foreground_color.a >= 1.0 || params.intensity <= 0.0 || params.color.a <= 0.0) {
		imageStore(output_image, id, foreground_color);
		return;
	}

	float glow_alpha = 0.0;
	if (params.fade > 0.0) {
		int sample_count = clamp(int(ceil(params.fade * 2.0)), 8, 128);
		float sigma = max(params.fade / 3.0, 0.1);
		float inv_two_sigma_sq = 1.0 / (2.0 * sigma * sigma);
		float radius_step_sq = (params.fade * params.fade) / float(sample_count);

		// Golden angle (~2.39996323 rad) rotation matrix.
		const mat2 golden_rotation = mat2(
			-0.73736888,  0.67549029,
			-0.67549029, -0.73736888
		);
		vec2 direction = vec2(1.0, 0.0);
		vec2 center_pos = vec2(id) + 0.5;
		vec2 size_float = vec2(out_size);
		vec2 inv_size = 1.0 / size_float;
		float weight_sum = 0.0;

		for (int i = 0; i < sample_count; i++) {
			float radius_sq = (float(i) + 0.5) * radius_step_sq;
			float radius = sqrt(radius_sq);
			vec2 sample_pos = center_pos + direction * radius;

			float weight = exp(-radius_sq * inv_two_sigma_sq);
			if (sample_pos.x >= 0.0 && sample_pos.y >= 0.0 && sample_pos.x < size_float.x && sample_pos.y < size_float.y) {
				glow_alpha += textureLod(source_image, sample_pos * inv_size, 0.0).a * weight;
			}
			weight_sum += weight;
			direction = golden_rotation * direction;
		}
		glow_alpha /= weight_sum;
	} else {
		glow_alpha = foreground_color.a;
	}

	glow_alpha = 1.0 - pow(1.0 - clamp(glow_alpha, 0.0, 1.0), params.intensity);
	vec4 glow_color = vec4(params.color.rgb, params.color.a * glow_alpha);

	float out_alpha = foreground_color.a + glow_color.a * (1.0 - foreground_color.a);
	vec3 out_rgb = vec3(0.0);
	if (out_alpha > 0.0) {
		out_rgb = (foreground_color.rgb * foreground_color.a + glow_color.rgb * glow_color.a * (1.0 - foreground_color.a)) / out_alpha;
	}

	imageStore(output_image, id, vec4(out_rgb, out_alpha));
}
