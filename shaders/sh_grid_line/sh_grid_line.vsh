// sh_grid_line: screen-space thick 3D lines.
// Each line is a quad of 4 corners. Every vertex carries its own endpoint
// (in_Position), the OTHER endpoint (in_Normal) and which side of the line
// it sits on (in_TextureCoord.x = -1 or +1). The vertex is projected to the
// screen and pushed sideways by half the width in pixels, so the line is the
// same thickness at any distance or angle, and still depth-tested.
attribute vec3 in_Position;      // this endpoint (world)
attribute vec3 in_Normal;        // the other endpoint (world)
attribute vec4 in_Colour;        // (r,g,b,a)
attribute vec2 in_TextureCoord;  // x = side (-1 or +1), y unused

uniform vec2 u_screen;           // render target size in pixels
uniform float u_width;           // line width in pixels

varying vec4 v_vColour;

void main()
{
    mat4 mvp = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION];
    vec4 a = mvp * vec4(in_Position, 1.0);
    vec4 b = mvp * vec4(in_Normal, 1.0);

    // Keep both ends in front of the camera, sliding along the line, so a
    // line that passes behind the viewer still gets a sensible direction.
    float near_w = 0.05;
    if (a.w < near_w && b.w < near_w)
    {
        gl_Position = vec4(0.0, 0.0, 2.0, 1.0); // whole line behind: off-screen
        v_vColour = in_Colour;
        return;
    }
    if (a.w < near_w)
    {
        a = mix(a, b, (near_w - a.w) / (b.w - a.w));
    }
    if (b.w < near_w)
    {
        b = mix(b, a, (near_w - b.w) / (a.w - b.w));
    }

    vec2 half_screen = u_screen * 0.5;
    vec2 sa = (a.xy / a.w) * half_screen;
    vec2 sb = (b.xy / b.w) * half_screen;

    vec2 dir = sb - sa;
    if (length(dir) < 0.0001)
    {
        dir = vec2(1.0, 0.0);
    }
    dir = normalize(dir);
    vec2 nrm = vec2(-dir.y, dir.x);

    float half_w = u_width * 0.5;
    // Sideways by half the width, and back past the endpoint by half the width
    // so neighbouring lines meet in square corners instead of notches.
    vec2 off = nrm * in_TextureCoord.x * half_w - dir * half_w;

    a.xy += (off / half_screen) * a.w;
    gl_Position = a;
    v_vColour = in_Colour;
}
