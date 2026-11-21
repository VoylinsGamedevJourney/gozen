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

	if (progress.value <= 0.0) {
		imageStore(output_image, id, vec4(0.0));
		return;
	}

	float remaining_progress = 1.0 - progress.value;
	float angle_rad = radians(params.angle);
	vec2 direction = vec2(-sin(angle_rad), cos(angle_rad));
	vec2 size_float = vec2(size);

	float abs_dir_x = abs(direction.x);
	float abs_dir_y = abs(direction.y);
	float exit_x = (abs_dir_x > 0.0001) ? (size_float.x / abs_dir_x) : 1e9;
	float exit_y = (abs_dir_y > 0.0001) ? (size_float.y / abs_dir_y) : 1e9;

	vec2 source_uv = (vec2(id) + 0.5 + (remaining_progress * direction * min(exit_x, exit_y))) / size_float;

	vec4 color = vec4(0.0);
	if (source_uv.x >= 0.0 && source_uv.x <= 1.0 && source_uv.y >= 0.0 && source_uv.y <= 1.0) {
		vec2 half_texel = 0.5 / size_float;
		color = textureLod(input_image, clamp(source_uv, half_texel, 1.0 - half_texel), 0.0);
	}

	imageStore(output_image, id, color);
}
