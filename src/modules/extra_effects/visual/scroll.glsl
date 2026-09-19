#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- INPUT ---
layout(set = 0, binding = 0) uniform sampler2D source_image;

// --- OUTPUT ---
layout(rgba8, set = 0, binding = 1) uniform writeonly image2D output_image;

// --- PARAMS ---
layout(set = 0, binding = 2, std140) uniform Params {
	vec2 init_pos;
	vec2 speed;
	int pass_index;
	int frame_nr;
} params;



void main() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	ivec2 out_size = imageSize(output_image);

	if (id.x >= out_size.x || id.y >= out_size.y) {
		return;
	}

	vec2 scroll_offset = params.init_pos + (params.speed * float(params.frame_nr));
	ivec2 source_id = ivec2(mod(vec2(id) - scroll_offset, vec2(out_size)));
	imageStore(output_image, id, texelFetch(source_image, source_id, 0));
}
