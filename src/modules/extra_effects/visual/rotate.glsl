#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- INPUT ---
layout(set = 0, binding = 0) uniform sampler2D source_image;

// --- OUTPUT ---
layout(rgba8, set = 0, binding = 1) uniform writeonly image2D output_image;

// --- PARAMS ---
layout(set = 0, binding = 2, std140) uniform Params {
    float x_rotation;
    float y_rotation;
    float z_rotation;
    float fov;
} params;



mat3 euler_to_matrix(float pitch, float yaw, float roll) {
    float cos_pitch = cos(radians(pitch));
    float sin_pitch = sin(radians(pitch));
    float cos_yaw = cos(radians(yaw));
    float sin_yaw = sin(radians(yaw));
    float cos_roll = cos(radians(roll));
    float sin_roll = sin(radians(roll));

    mat3 rotation_x = mat3(
        1.0, 0.0, 0.0,
        0.0, cos_pitch, -sin_pitch,
        0.0, sin_pitch, cos_pitch
    );
    mat3 rotation_y = mat3(
        cos_yaw, 0.0, sin_yaw,
        0.0, 1.0, 0.0,
        -sin_yaw, 0.0, cos_yaw
    );
    mat3 rotation_z = mat3(
        cos_roll, -sin_roll, 0.0,
        sin_roll, cos_roll, 0.0,
        0.0, 0.0, 1.0
    );
    return rotation_y * rotation_x * rotation_z;
}


void main() {
    ivec2 id = ivec2(gl_GlobalInvocationID.xy);
    ivec2 out_size = imageSize(output_image);

    if (id.x >= out_size.x || id.y >= out_size.y) {
        return;
    }

    vec2 resolution = vec2(out_size);
    vec2 uv = (vec2(id) + 0.5) / resolution;
    vec2 centered_pos = uv - 0.5;

    float aspect = resolution.x / resolution.y;
    centered_pos.x *= aspect;

    mat3 rotation_matrix = euler_to_matrix(params.x_rotation, params.y_rotation, params.z_rotation);

    float focus_length = max(params.fov, 0.01);
    vec3 camera_pos = vec3(0.0, 0.0, -focus_length);
    vec3 ray_direction = normalize(vec3(centered_pos.x, centered_pos.y, focus_length));

    vec3 plane_normal = rotation_matrix * vec3(0.0, 0.0, -1.0);
    vec3 plane_center = vec3(0.0, 0.0, 0.0);

    float ray_plane_dot = dot(ray_direction, plane_normal);
    vec4 color = vec4(0.0);

    if (abs(ray_plane_dot) > 0.0001) {
        float intersection_distance = dot(plane_center - camera_pos, plane_normal) / ray_plane_dot;
        if (intersection_distance > 0.0) {
            vec3 intersection_pos = camera_pos + ray_direction * intersection_distance;
            vec3 local_pos = transpose(rotation_matrix) * intersection_pos;

            vec2 source_uv = vec2(local_pos.x / aspect, local_pos.y) + 0.5;

            if (source_uv.x >= 0.0 && source_uv.x <= 1.0 && source_uv.y >= 0.0 && source_uv.y <= 1.0) {
                color = textureLod(source_image, source_uv, 0.0);
                if (ray_plane_dot > 0.0) {
                    color.rgb *= 0.8;
                }
            }
        }
    }
    imageStore(output_image, id, color);
}
