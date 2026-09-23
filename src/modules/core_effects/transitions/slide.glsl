#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- INPUTS ---
layout(set = 0, binding = 0) uniform sampler2D input_image;

// --- OUTPUT ---
layout(rgba8, set = 0, binding = 1) uniform writeonly image2D output_image;

// --- PARAMS ---
layout(set = 0, binding = 2, std140) uniform Params {
	float angle;
	int pass_index;
	int frame_nr;
} params;
layout(set = 0, binding = 3, std140) uniform Progress { float value; } progress;



void main() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(output_image);
	if (id.x >= size.x || id.y >= size.y) {
		return;
	}

	float dist = 1.0 - progress.value;
	float angle_rad = radians(params.angle);
	vec2 dir = vec2(-sin(angle_rad), cos(angle_rad));

	float displacement = abs(dir.x) * float(size.x) + abs(dir.y) * float(size.y);
	vec2 offset = dist * dir * displacement;

	ivec2 src_id = id + ivec2(offset);
	vec4 color = vec4(0.0);
	if (src_id.x >= 0 && src_id.x < size.x && src_id.y >= 0 && src_id.y < size.y) {
		color = texelFetch(input_image, src_id, 0);
	}

	imageStore(output_image, id, color);
}
