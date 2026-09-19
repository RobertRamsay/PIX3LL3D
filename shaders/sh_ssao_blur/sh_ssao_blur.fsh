// sh_ssao_blur - depth-aware blur of the AO buffer, composited into the scene.
//
// gm_BaseTexture is the scene colour (the application surface). u_ao is the
// raw occlusion from sh_ssao. The blur is bilateral: taps across a depth
// discontinuity are weighted down, so AO does not bleed over tile edges.

varying vec2 v_vTexcoord;
varying vec4 v_vColour;

uniform sampler2D u_ao;
uniform sampler2D u_depth;
uniform vec2  u_texel;
uniform float u_znear;
uniform float u_zfar;
uniform float u_blur;        // tap spacing in pixels, 0 = no blur
uniform float u_tint;        // 0 = neutral black occlusion, 1 = cool blue
uniform float u_debug;       // 1 = show the AO buffer instead of the scene

float linear_depth(float d)
{
    float denom = u_zfar - d * (u_zfar - u_znear);
    return (u_znear * u_zfar) / max(denom, 0.0001);
}

void main()
{
    vec2 uv = v_vTexcoord;
    vec4 col = texture2D(gm_BaseTexture, uv);

    float dc = texture2D(u_depth, uv).r;
    float zc = linear_depth(dc);

    // 3x3 is enough once the AO buffer is upsampled with bilinear filtering,
    // and at blur 0 the loop is skipped entirely - 9 fewer texture fetches per
    // pixel than a 5x5, which is most of this pass's cost.
    float ao = texture2D(u_ao, uv).r;

    if (u_blur > 0.0)
    {
        float sum = 0.0;
        float wsum = 0.0;

        for (int y = -1; y <= 1; y++)
        {
            for (int x = -1; x <= 1; x++)
            {
                vec2 suv = uv + vec2(float(x), float(y)) * u_blur * u_texel;

                float zs = linear_depth(texture2D(u_depth, suv).r);
                float w = exp(-abs(zs - zc) * 6.0);

                sum += texture2D(u_ao, suv).r * w;
                wsum += w;
            }
        }

        ao = sum / max(wsum, 0.0001);
    }

    ao = clamp(ao, 0.0, 1.0);

    if (u_debug > 0.5)
    {
        gl_FragColor = vec4(ao, ao, ao, 1.0);
        return;
    }

    // ao = 1 leaves the pixel alone; ao = 0 pulls it to the occlusion colour.
    vec3 occ_col = mix(vec3(0.0), vec3(0.05, 0.10, 0.25), clamp(u_tint, 0.0, 1.0));
    vec3 shade = mix(occ_col, vec3(1.0), ao);

    gl_FragColor = vec4(col.rgb * shade, col.a);
}
