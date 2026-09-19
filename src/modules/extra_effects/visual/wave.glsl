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
	float frequency;
	float speed;
	int pass_index;
	int frame_nr;
} params;



void main() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	ivec2 out_size = imageSize(output_image);
	if (id.x >= out_size.x || id.y >= out_size.y) {
		return;
	}

	vec2 uv = vec2(id) / vec2(out_size);
	vec2 wave_offset = vec2(0.0);
	float time = float(params.frame_nr) * params.speed * 0.05;

	if (params.horizontal > 0) {
		wave_offset.x = sin(uv.y * params.frequency + time) * (params.amplitude / float(out_size.x));
	}

	if (params.vertical > 0) {
		wave_offset.y = sin(uv.x * params.frequency + time) * (params.amplitude / float(out_size.y));
	}

	vec2 src_uv = uv + wave_offset;
	vec4 color = vec4(0.0);

	if (src_uv.x >= 0.0 && src_uv.x <= 1.0 && src_uv.y >= 0.0 && src_uv.y <= 1.0) {
		color = textureLod(source_image, src_uv, 0.0);
	}

	imageStore(output_image, id, color);
}
