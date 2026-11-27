#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- OUTPUTS ---
layout(rgba8, set = 0, binding = 0) uniform writeonly image2D output_image;

// --- PARAMS ---
layout(set = 0, binding = 1, std140) uniform Params { vec4 color; } params;


void main() {
	ivec2 pixel_coord = ivec2(gl_GlobalInvocationID.xy);
	ivec2 output_size = imageSize(output_image);
	if (pixel_coord.x >= output_size.x || pixel_coord.y >= output_size.y) {
		return;
	}

	imageStore(output_image, pixel_coord, params.color);
}
