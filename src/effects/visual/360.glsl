#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- INPUT ---
layout(set = 0, binding = 0) uniform sampler2D source_image;

// --- OUTPUT ---
layout(rgba8, set = 0, binding = 1) uniform writeonly image2D output_image;

// --- PARAMS ---
layout(set = 0, binding = 2, std140) uniform Params {
    float yaw;
    float pitch;
    float roll;
    float fov;
} params;



mat3 euler_to_matrix(float yaw, float pitch, float roll) {
    float cy = cos(radians(yaw));
    float sy = sin(radians(yaw));
    float cp = cos(radians(pitch));
    float sp = sin(radians(pitch));
    float cr = cos(radians(roll));
    float sr = sin(radians(roll));
    mat3 R_y = mat3(cy, 0.0, sy,
                    0.0, 1.0, 0.0,
                    -sy, 0.0, cy);
    mat3 R_x = mat3(1.0, 0.0, 0.0,
                    0.0, cp, -sp,
                    0.0, sp, cp);
    mat3 R_z = mat3(cr, -sr, 0.0,
                    sr, cr, 0.0,
                    0.0, 0.0, 1.0);
    return R_y * R_x * R_z;
}


void main() {
    ivec2 id = ivec2(gl_GlobalInvocationID.xy);
    ivec2 out_size = imageSize(output_image);
    if (id.x >= out_size.x || id.y >= out_size.y) return;

    vec2 ndc = (vec2(id) + 0.5) / vec2(out_size) * 2.0 - 1.0;
    float aspect = float(out_size.x) / float(out_size.y);

    float fov_rad = radians(params.fov);
    float f = 1.0 / tan(fov_rad / 2.0);
    vec3 ray = normalize(vec3(ndc.x * aspect, ndc.y, f));

    mat3 rot = euler_to_matrix(params.yaw, params.pitch, params.roll);
    ray = rot * ray;

    float longitude = atan(ray.x, ray.z);
    float latitude = asin(ray.y);
    vec2 uv = vec2(longitude / (2.0 * 3.14159265) + 0.5,
                   0.5 - latitude / 3.14159265);

    vec4 color = textureLod(source_image, uv, 0.0);
    imageStore(output_image, id, color);
}
