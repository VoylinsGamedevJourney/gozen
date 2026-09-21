#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- INPUT ---
layout(set = 0, binding = 0) uniform sampler2D source_image;

// --- OUTPUT ---
layout(rgba8, set = 0, binding = 1) uniform writeonly image2D output_image;

// --- PARAMS ---
layout(set = 0, binding = 2, std140) uniform Params {
	float radius;
	vec2 size;
	vec2 center;
} params;



float roundedBoxSDF(vec2 CenterPosition, vec2 Size, float Radius) {
	float r = clamp(Radius, 0.0, min(Size.x, Size.y));
	vec2 q = abs(CenterPosition) - Size + vec2(r);
	return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}


void main() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	ivec2 out_size = imageSize(output_image);

	if (id.x >= out_size.x || id.y >= out_size.y) {
		return;
	}

	vec4 color = texelFetch(source_image, id, 0);
	vec2 pos = vec2(id.x, id.y) - params.center;
	vec2 size = params.size / 2.0;
	float distance = roundedBoxSDF(pos, size, params.radius);
	float alpha = 1.0 - smoothstep(-0.5, 0.5, distance);

	color.a *= alpha;
	imageStore(output_image, id, color);
}
