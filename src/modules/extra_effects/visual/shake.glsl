#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- INPUT ---
layout(set = 0, binding = 0) uniform sampler2D source_image;

// --- OUTPUT ---
layout(rgba8, set = 0, binding = 1) uniform writeonly image2D output_image;

// --- PARAMS ---
layout(set = 0, binding = 2, std140) uniform Params {
	int horizontal;
	int vertical;
	float amplitude;
	float speed;
	int pass_index;
	int frame_nr;
} params;



float rand(vec2 seed) {
	return fract(sin(dot(seed.xy ,vec2(13.0, 77.0))) * 40000.0);
}


void main() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	ivec2 out_size = imageSize(output_image);
	if (id.x >= out_size.x || id.y >= out_size.y) {
		return;
	}

	float time_val = floor(float(params.frame_nr) * params.speed);

	vec2 random_offset = vec2(
		rand(vec2(time_val, 1.0)) * 2.0 - 1.0,
		rand(vec2(1.0, time_val)) * 2.0 - 1.0
	);

	vec2 shake_offset = random_offset * params.amplitude * vec2(
		params.horizontal,
		params.vertical
	);

	ivec2 src_id = id + ivec2(shake_offset);
	vec4 color = vec4(0.0);

	if (src_id.x >= 0 && src_id.x < out_size.x && src_id.y >= 0 && src_id.y < out_size.y) {
		color = texelFetch(source_image, src_id, 0);
	}

	imageStore(output_image, id, color);
}
