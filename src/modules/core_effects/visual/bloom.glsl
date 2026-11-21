#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- INPUT ---
layout(set = 0, binding = 0) uniform sampler2D source_image;

// --- OUTPUT ---
layout(rgba8, set = 0, binding = 1) uniform writeonly image2D output_image;

// --- PARAMS ---
layout(set = 0, binding = 2, std140) uniform Params {
	float threshold;
	float smoothness;
	float radius;
	float intensity;
	vec4 tint;
} params;



vec3 extract_bright_pixels(vec4 color, float threshold, float smoothness) {
	vec3 rgb = color.rgb * color.a;
	float brightness = max(rgb.r, max(rgb.g, rgb.b));
	float weight = (smoothness > 0.0001)
		? smoothstep(threshold - smoothness, threshold + smoothness, brightness)
		: step(threshold, brightness);
	return rgb * weight;
}


void main() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	ivec2 out_size = imageSize(output_image);
	if (id.x >= out_size.x || id.y >= out_size.y) {
		return;
	}

	vec4 fg_color = texelFetch(source_image, id, 0);
	if (params.intensity <= 0.0) {
		imageStore(output_image, id, fg_color);
		return;
	}

	vec3 bloom = vec3(0.0);
	if (params.radius > 0.0) {
		int num_samples = clamp(int(params.radius * 3.0), 64, 2048);
		float sigma_core = max(params.radius * 0.15, 1.0);
		float sigma_halo = max(params.radius * 0.45, 1.0);
		float core_weight_sum = 0.0;
		float halo_weight_sum = 0.0;
		vec3 core_sum = vec3(0.0);
		vec3 halo_sum = vec3(0.0);
		for (int i = 0; i < num_samples; i++) {
			float theta = float(i) * 2.39996323;
			float r = (sqrt(float(i) + 0.5) / sqrt(float(num_samples))) * params.radius;
			vec2 sample_uv = (vec2(id) + 0.5 + vec2(cos(theta), sin(theta)) * r) / vec2(out_size);

			float weight_core = exp(-(r * r) / (2.0 * sigma_core * sigma_core));
			float weight_halo = exp(-(r * r) / (2.0 * sigma_halo * sigma_halo));
			if (sample_uv.x >= 0.0 && sample_uv.x <= 1.0 && sample_uv.y >= 0.0 && sample_uv.y <= 1.0) {
				vec4 sample_color = textureLod(source_image, sample_uv, 0.0);
				vec3 bright = extract_bright_pixels(sample_color, params.threshold, params.smoothness);
				core_sum += bright * weight_core;
				halo_sum += bright * weight_halo;
				core_weight_sum += weight_core;
				halo_weight_sum += weight_halo;
			}
		}
		vec3 core_bloom = core_sum / max(core_weight_sum, 0.0001);
		vec3 halo_bloom = halo_sum / max(halo_weight_sum, 0.0001);
		bloom = core_bloom * 0.6 + halo_bloom * 0.4;
	} else {
		bloom = extract_bright_pixels(fg_color, params.threshold, params.smoothness);
	}
	vec3 rgb = vec3(0.0);
	vec3 bloom_rgb = bloom * params.intensity * params.tint.rgb * params.tint.a;
	float bloom_alpha = clamp(max(bloom_rgb.r, max(bloom_rgb.g, bloom_rgb.b)), 0.0, 1.0);
	float alpha = clamp(fg_color.a + bloom_alpha * (1.0 - fg_color.a), 0.0, 1.0);
	if (alpha > 0.0) {
		rgb = clamp((fg_color.rgb * fg_color.a + bloom_rgb) / alpha, 0.0, 1.0);
	}

	imageStore(output_image, id, vec4(rgb, alpha));
}
