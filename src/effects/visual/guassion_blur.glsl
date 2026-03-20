#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- INPUT ---
layout(set = 0, binding = 0) uniform sampler2D source_image;

// --- OUTPUT ---
layout(rgba8, set = 0, binding = 1) uniform writeonly image2D output_image;

// --- PARAMS ---
layout(set = 0, binding = 2, std140) uniform Params {
    float horizontal_sigma;
    float vertical_sigma;
} params;


void main() {
    ivec2 id = ivec2(gl_GlobalInvocationID.xy);
    ivec2 out_size = imageSize(output_image);
    if (id.x >= out_size.x || id.y >= out_size.y) {
		return;
	}

	int rx = int(ceil(params.horizontal_sigma * 2.0));
    int ry = int(ceil(params.vertical_sigma * 2.0));

    if (rx <= 0 && ry <= 0) {
        imageStore(output_image, id, texelFetch(source_image, id, 0));
        return;
    }

    vec4 color = vec4(0.0);
    float weightSum = 0.0;

    float sigma_x = max(params.horizontal_sigma, 0.0001);
    float sigma_y = max(params.vertical_sigma, 0.0001);
    float twoSigmaSqX = 2.0 * sigma_x * sigma_x;
    float twoSigmaSqY = 2.0 * sigma_y * sigma_y;

    for (int x = -rx; x <= rx; x++) {
        for (int y = -ry; y <= ry; y++) {
            ivec2 coord = clamp(id + ivec2(x, y), ivec2(0), out_size - ivec2(1));
            float weight = exp(-(float(x * x) / twoSigmaSqX + float(y * y) / twoSigmaSqY));
            color += texelFetch(source_image, coord, 0) * weight;
            weightSum += weight;
        }
    }
    imageStore(output_image, id, color / weightSum);
}
