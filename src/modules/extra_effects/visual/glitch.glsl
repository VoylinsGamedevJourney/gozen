#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- INPUT ---
layout(set = 0, binding = 0) uniform sampler2D source_image;

// --- OUTPUT ---
layout(rgba8, set = 0, binding = 1) uniform writeonly image2D output_image;

// --- PARAMS ---
layout(set = 0, binding = 2, std140) uniform Params {
	float frequency;
	float max_block_height;
	float intensity;
	float color_intensity;
	int pass_index;
	int frame_nr;
} params;



float rand(float seed) {
	return fract(sin(seed) * 43758.5453123);
}



void main() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	ivec2 out_size = imageSize(output_image);
	if (id.x >= out_size.x || id.y >= out_size.y) {
		return;
	}

	vec2 uv = vec2(id) / vec2(out_size);

	float block_seed = floor(uv.y * (float(out_size.y) / params.max_block_height));
	float trigger = rand(block_seed + float(params.frame_nr) * 0.1);

	vec2 offset = vec2(0.0);
	float color_shift = 0.0;

	if (trigger < params.frequency) {
		float shift_amt = (rand(block_seed + 1.0 + float(params.frame_nr)) * 2.0 - 1.0);
		offset.x = shift_amt * params.intensity;
		color_shift = shift_amt * params.color_intensity;
	}

	vec2 src_uv = uv + offset;

	float r = textureLod(source_image, clamp(src_uv + vec2(color_shift, 0.0), 0.0, 1.0), 0.0).r;
	float g = textureLod(source_image, clamp(src_uv, 0.0, 1.0), 0.0).g;
	float b = textureLod(source_image, clamp(src_uv - vec2(color_shift, 0.0), 0.0, 1.0), 0.0).b;
	float a = textureLod(source_image, clamp(src_uv, 0.0, 1.0), 0.0).a;

	imageStore(output_image, id, vec4(r, g, b, a));
}
