/// GRID_system
/// The 3D ground grid, drawn as screen-space thick lines with sh_grid_line.
/// The whole grid lives in one vertex buffer (grid_vb) and is only rebuilt
/// when its placement changes; drawing it is a single vertex_submit.
/// State is initialised in the Create event of obj_editor.

/// @desc Add one thick line (a quad of two triangles) to grid_vb.
/// Call between vertex_begin and vertex_end.
function grid_add_line(_x1, _y1, _z1, _x2, _y2, _z2, _col)
{
    // The B corners see the line from the other end, so their "side" is
    // negated to land on the same edge as the matching A corner.
    // Triangle 1: A left, A right, B left
    grid_add_vertex(_x1, _y1, _z1, _x2, _y2, _z2, -1, _col);
    grid_add_vertex(_x1, _y1, _z1, _x2, _y2, _z2, 1, _col);
    grid_add_vertex(_x2, _y2, _z2, _x1, _y1, _z1, 1, _col);
    // Triangle 2: A right, B right, B left
    grid_add_vertex(_x1, _y1, _z1, _x2, _y2, _z2, 1, _col);
    grid_add_vertex(_x2, _y2, _z2, _x1, _y1, _z1, -1, _col);
    grid_add_vertex(_x2, _y2, _z2, _x1, _y1, _z1, 1, _col);
}

/// @desc One corner: own endpoint, other endpoint, side (-1 / +1), colour.
function grid_add_vertex(_x, _y, _z, _ox, _oy, _oz, _side, _col)
{
    vertex_position_3d(grid_vb, _x, _y, _z);
    vertex_normal(grid_vb, _ox, _oy, _oz);
    vertex_color(grid_vb, _col, 1);
    vertex_texcoord(grid_vb, _side, 0);
}

/// @desc Rebuild grid_vb for a grid shifted by (_gx, _gy, _gz).
/// Includes the blue zero-offset reference grid when _with_ref is true.
function grid_build(_gx, _gy, _gz, _with_ref)
{
    vertex_begin(grid_vb, grid_vfmt);
    for (var i = -grid_half; i <= grid_half; i++)
    {
        var _col_x = c_gray;
        if (i == 0)
        {
            _col_x = c_red;
        }
        grid_add_line(i + _gx, -grid_half + _gy, _gz, i + _gx, grid_half + _gy, _gz, _col_x);

        var _col_y = c_gray;
        if (i == 0)
        {
            _col_y = c_green;
        }
        grid_add_line(-grid_half + _gx, i + _gy, _gz, grid_half + _gx, i + _gy, _gz, _col_y);
    }

    if (_with_ref)
    {
        for (var j = -grid_half; j <= grid_half; j++)
        {
            grid_add_line(j, -grid_half, 0, j, grid_half, 0, grid_col_ref);
            grid_add_line(-grid_half, j, 0, grid_half, j, 0, grid_col_ref);
        }
    }
    vertex_end(grid_vb);
}

/// @desc Draw the grid, rebuilding it only if its placement changed.
/// Call in the Draw event after the 3D camera has been applied.
function grid_draw(_gx, _gy, _gz)
{
    var _with_ref = (grid_offset != 0);
    var _key = string(_gx) + "," + string(_gy) + "," + string(_gz) + "," + string(_with_ref);
    if (_key != grid_vb_key)
    {
        grid_build(_gx, _gy, _gz, _with_ref);
        grid_vb_key = _key;
    }

    // Size of what we are rendering into right now (the application surface)
    var _sw = window_get_width();
    var _sh = window_get_height();
    if (surface_exists(application_surface))
    {
        _sw = surface_get_width(application_surface);
        _sh = surface_get_height(application_surface);
    }

    shader_set(sh_grid_line);
    shader_set_uniform_f(grid_u_screen, _sw, _sh);
    shader_set_uniform_f(grid_u_width, grid_line_px);
    vertex_submit(grid_vb, pr_trianglelist, -1);
    shader_reset();
}
