#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- INPUTS ---
layout(set = 0, binding = 0) uniform sampler2D input_image;

// --- OUTPUT ---
layout(rgba8, set = 0, binding = 1) uniform writeonly image2D output_image;

// --- PARAMS ---
layout(set = 0, binding = 2, std140) uniform Params {
	vec2 center;
	int fade;
	int pass_index;
	int frame_nr;
} params;
layout(set = 0, binding = 3, std140) uniform Progress { float value; } progress;



void main() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(output_image);
	if (id.x >= size.x || id.y >= size.y) {
		return;
	} else if (progress.value <= 0.0) {
		imageStore(output_image, id, vec4(0.0));
		return;
	} else if (progress.value >= 1.0) {
		imageStore(output_image, id, texelFetch(input_image, id, 0));
		return;
	}

	vec4 color = vec4(0.0);
	float scale = clamp(progress.value, 0.0, 1.0);
	vec2 uv = ((((vec2(id) + 0.5) / vec2(size)) - params.center) / scale) + params.center;
	if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
		vec2 half_texel = 0.5 / vec2(size);
		color = textureLod(input_image, clamp(uv, half_texel, 1.0 - half_texel), 0.0);
		if (params.fade > 0) {
			color.a *= scale;
		}
	}
	imageStore(output_image, id, color);
}
