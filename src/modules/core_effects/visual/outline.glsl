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



void sample_outline_offset(ivec2 id, ivec2 max_coord, ivec2 offset, float max_distance, inout float max_alpha) {
	float dist = mix(
			float(max(abs(offset.x), abs(offset.y))),
			length(vec2(offset)),
			params.roundness);
	float weight = clamp(max_distance - dist, 0.0, 1.0);
	if (weight <= max_alpha) {
		return;
	}

	float sample_alpha = texelFetch(source_image, clamp(id + offset, ivec2(0), max_coord), 0).a;
	if (sample_alpha > 0.0) {
		max_alpha = max(max_alpha, sample_alpha * weight);
	}
}


void main() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(output_image);
	if (id.x >= size.x || id.y >= size.y) {
		return;
	}

	vec4 center_color = texelFetch(source_image, id, 0);
	if (center_color.a >= 1.0 || params.thickness <= 0.0 || params.color.a <= 0.0) {
		imageStore(output_image, id, center_color);
		return;
	}

	float max_distance = params.thickness + 1.0;
	ivec2 max_coord = size - ivec2(1);
	float max_alpha = 0.0;
	for (int ring = 1; ring <= clamp(int(ceil(max_distance)), 1, 100); ring++) {
		if (max_alpha >= 1.0 || (max_distance - float(ring)) <= max_alpha) {
			break;
		}

		for (int x = -ring; x <= ring; x++) {
			sample_outline_offset(id, max_coord, ivec2(x, -ring), max_distance, max_alpha);
			sample_outline_offset(id, max_coord, ivec2(x, ring), max_distance, max_alpha);
		}
		for (int y = -ring + 1; y <= ring - 1; y++) {
			sample_outline_offset(id, max_coord, ivec2(-ring, y), max_distance, max_alpha);
			sample_outline_offset(id, max_coord, ivec2(ring, y), max_distance, max_alpha);
		}
	}

	vec4 outline_color = vec4(params.color.rgb, params.color.a * max_alpha);
	float alpha = center_color.a + outline_color.a * (1.0 - center_color.a);
	vec3 rgb = vec3(0.0);
	if (alpha > 0.0) {
		rgb = (center_color.rgb * center_color.a + outline_color.rgb * outline_color.a * (1.0 - center_color.a)) / alpha;
	}
	imageStore(output_image, id, vec4(rgb, alpha));
}
