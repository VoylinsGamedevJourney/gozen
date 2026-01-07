shader_type compute;
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;


// Input data
uniform sampler2D y_data;
uniform sampler2D u_data;
uniform sampler2D v_data;

// Output image
layout(rgba8, binding = 0) uniform writeonly image2D out_image;

// Params
uniform ivec2 resolution;
uniform vec4 color_profile;
uniform float rotation;
// 0 = none, 1 = top first, 2 = bottom first
uniform float interlaced;



void main() {
    ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
    if (pixel.x >= resolution.x || pixel.y >= resolution.y) {
        return;
    }

    // UV
    vec2 uv = (vec2(pixel) + 0.5) / vec2(resolution);

    // Rotation
    vec2 centered = uv - vec2(0.5);
    float c = cos(rotation);
    float s = sin(rotation);
    vec2 rotated = vec2(
        centered.x * c - centered.y * s,
        centered.x * s + centered.y * c
    );
    uv = rotated + vec2(0.5);

    // Y UV
    vec2 y_uv = clamp(
        uv * vec2(resolution) / vec2(textureSize(y_data, 0)),
        vec2(0.0), vec2(1.0)
    );

    // U/V UV (subsampled)
    vec2 half_res = vec2(resolution) * 0.5;
    vec2 u_uv = clamp(
        uv * half_res / vec2(textureSize(u_data, 0)),
        vec2(0.0), vec2(1.0)
    );
    vec2 v_uv = clamp(
        uv * half_res / vec2(textureSize(v_data, 0)),
        vec2(0.0), vec2(1.0)
    );

    // --- Deinterlacing (line blend) ---
    float Y;
    vec2 offset = vec2(0.0, 1.0 / float(resolution.y));

    float Y_center = texture(y_data, y_uv).r;
    float Y_top = texture(y_data, clamp(y_uv - offset, 0.0, 1.0)).r;
    float Y_bottom = texture(y_data, clamp(y_uv + offset, 0.0, 1.0)).r;

    if (interlaced == 1.0) {
        Y = mix(Y_top, Y_center, 0.5);
    } else if (interlaced == 2.0) {
        Y = mix(Y_center, Y_bottom, 0.5);
    } else {
        Y = Y_center;
    }

    float U = texture(u_data, u_uv).r;
    float V = texture(v_data, v_uv).r;

    // Studio range to full range
    Y = (Y * 255.0 - 16.0) / 219.0;
    U = (U * 255.0 - 128.0) / 224.0;
    V = (V * 255.0 - 128.0) / 224.0;

    // YUV to RGB
    vec3 rgb;
    rgb.r = Y + color_profile.x * V;
    rgb.g = Y - color_profile.y * U - color_profile.z * V;
    rgb.b = Y + color_profile.w * U;

    rgb = clamp(rgb, 0.0, 1.0);

	// Storing final RGBA image
    imageStore(out_image, pixel, vec4(rgb, 1.0));
}
