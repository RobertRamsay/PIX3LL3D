// sh_ssao - screen-space ambient occlusion, depth only.
//
// Reads the application surface's depth buffer and writes a single-channel
// occlusion factor (1 = fully lit, 0 = fully occluded) into the AO surface.
// sh_ssao_blur then smooths it and multiplies it into the scene colour.
//
// Written for PIX3LL3D; no normal buffer, so occlusion comes purely from
// linearised depth differences inside a world-space radius. That suits
// axis-aligned voxel geometry: it darkens the creases where tiles meet.

varying vec2 v_vTexcoord;
varying vec4 v_vColour;

uniform sampler2D u_depth;      // surface_get_texture_depth(application_surface)
uniform vec2  u_texel;          // 1.0 / surface size
uniform vec2  u_res;            // surface size in pixels
uniform float u_znear;          // projection near plane
uniform float u_zfar;           // projection far plane
uniform float u_fov_scale;      // tan(fov_y * 0.5)
uniform float u_radius;         // sample radius in world units
uniform float u_bias;           // world-space depth bias, kills self-occlusion
uniform float u_intensity;      // occlusion strength
uniform float u_power;          // falloff shaping
uniform float u_samples;        // active taps, 4 .. 32

const int MAX_TAPS = 32;
const float GOLDEN = 2.39996323;
const float TAU = 6.28318530718;

// 0..1 perspective depth -> distance from the camera in world units.
float linear_depth(float d)
{
    float denom = u_zfar - d * (u_zfar - u_znear);
    return (u_znear * u_zfar) / max(denom, 0.0001);
}

void main()
{
    vec2 uv = v_vTexcoord;
    float dc = texture2D(u_depth, uv).r;

    // The skybox draws with zwrite off, so background pixels keep the cleared
    // depth. Leave them untouched instead of ringing the silhouettes.
    if (dc >= 0.999990)
    {
        gl_FragColor = vec4(1.0, 1.0, 1.0, 1.0);
        return;
    }

    float zc = linear_depth(dc);

    // Project the world radius onto the screen at this depth.
    float r_px = (u_radius / (zc * u_fov_scale)) * (u_res.y * 0.5);
    r_px = clamp(r_px, 1.0, 128.0);

    // Per-pixel spiral rotation so the tap pattern does not band.
    float rot = fract(sin(dot(uv * u_res, vec2(12.9898, 78.233))) * 43758.5453) * TAU;

    float taps = clamp(u_samples, 4.0, float(MAX_TAPS));
    float range = max(u_radius * 2.0, 0.0001);
    float occ = 0.0;
    float total = 0.0;

    for (int i = 0; i < MAX_TAPS; i++)
    {
        if (float(i) >= taps)
        {
            break;
        }

        float fi = float(i) + 0.5;
        float ang = fi * GOLDEN + rot;
        float rad = sqrt(fi / taps) * r_px;
        vec2 off = vec2(cos(ang), sin(ang)) * rad * u_texel;

        float ds = texture2D(u_depth, uv + off).r;
        float zs = linear_depth(ds);

        // Positive difference means the sample sits nearer the camera, so it
        // occludes. Beyond the range it is unrelated geometry, not a crease.
        float diff = zc - zs;
        float inside = step(u_bias, diff) * step(diff, range);
        occ += inside * (1.0 - clamp(diff / range, 0.0, 1.0));
        total += 1.0;
    }

    float ao = 1.0 - (occ / max(total, 1.0)) * u_intensity;
    ao = pow(clamp(ao, 0.0, 1.0), max(u_power, 0.01));

    gl_FragColor = vec4(ao, ao, ao, 1.0);
}
