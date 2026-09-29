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
	float thickness;
	float roundness;
} params;



void main() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	ivec2 out_size = imageSize(output_image);
	if (id.x >= out_size.x || id.y >= out_size.y) {
		return;
	}

	vec4 center_color = texelFetch(source_image, id, 0);
	if (center_color.a >= 1.0 || params.thickness <= 0.0) {
		imageStore(output_image, id, center_color);
		return;
	}

	int radius = int(ceil(params.thickness + 1.0));
	float max_alpha = 0.0;
	for (int x = -radius; x <= radius; x++) {
		for (int y = -radius; y <= radius; y++) {
			if (x == 0 && y == 0) {
				continue;
			}

			float box_dist = float(max(abs(x), abs(y)));
			float round_dist = length(vec2(x, y));
			float dist = mix(box_dist, round_dist, params.roundness);

			if (dist <= params.thickness + 1.0) {
				ivec2 sample_pos = clamp(id + ivec2(x, y), ivec2(0), out_size - ivec2(1));
				float a = texelFetch(source_image, sample_pos, 0).a;
				if (a > 0.0) {
					float weight = clamp(params.thickness - dist + 1.0, 0.0, 1.0);
					float weighted_alpha = a * weight;
					if (weighted_alpha > max_alpha) {
						max_alpha = weighted_alpha;
					}
				}
			}
		}
	}

	vec4 outline_color = vec4(params.color.rgb, params.color.a * max_alpha);
	float out_alpha = center_color.a + outline_color.a * (1.0 - center_color.a);
	vec3 out_rgb = vec3(0.0);
	if (out_alpha > 0.0) {
		out_rgb = vec3(center_color.rgb * center_color.a + outline_color.rgb * outline_color.a * (1.0 - center_color.a));
		out_rgb /= out_alpha;
	}

	imageStore(output_image, id, vec4(out_rgb, out_alpha));
}
