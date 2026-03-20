#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- INPUT ---
layout(set = 0, binding = 0) uniform sampler2D source_image;

// --- OUTPUT ---
layout(rgba8, set = 0, binding = 1) uniform writeonly image2D output_image;

// --- PARAMS ---
layout(set = 0, binding = 2, std140) uniform Params {
    int radius;
    float sigma;
} params;


void main() {
    ivec2 id = ivec2(gl_GlobalInvocationID.xy);
    ivec2 out_size = imageSize(output_image);
    if (id.x >= out_size.x || id.y >= out_size.y) {
		return;
	}

    int r = params.radius;
    if (r <= 0) {
        imageStore(output_image, id, texelFetch(source_image, id, 0));
        return;
    }

	// Automatically determine a good sigma if left at 0.
    vec4 color = vec4(0.0);
    float weightSum = 0.0;
    float sigma = params.sigma <= 0.0 ? max(float(r) / 2.0, 1.0) : params.sigma;
    float twoSigmaSq = 2.0 * sigma * sigma;
    for (int x = -r; x <= r; x++) {
        for (int y = -r; y <= r; y++) {
            ivec2 coord = clamp(id + ivec2(x, y), ivec2(0), out_size - ivec2(1));
            float weight = exp(-(float(x * x + y * y)) / twoSigmaSq);
            color += texelFetch(source_image, coord, 0) * weight;
            weightSum += weight;
        }
    }
    imageStore(output_image, id, color / weightSum);
}
