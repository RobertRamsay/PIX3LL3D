function draw_skybox(_size, _z_up, _col_top, _col_bot) {
    // _size: half-extent of the box (e.g. 50)
    // _z_up: world Z at the top of the box (negative, since -Z is up)
    // Builds 5 quads (4 walls + floor); ceiling optional
    var _s = _size;
    var _zt = -_size; // top (sky) — negative Z is up
    var _zb =  _size; // bottom (ground)

    // No texture, vertex colours only -> use the colour-only buffer/format
    vertex_begin(global.v_buffer, global.v_format);

    // Helper pattern: each wall is a vertical quad, top verts _col_top, bottom _col_bot
    // Wall +X
    vertex_position_3d(global.v_buffer,  _s, -_s, _zt); vertex_color(global.v_buffer, _col_top, 1);
    vertex_position_3d(global.v_buffer,  _s,  _s, _zt); vertex_color(global.v_buffer, _col_top, 1);
    vertex_position_3d(global.v_buffer,  _s, -_s, _zb); vertex_color(global.v_buffer, _col_bot, 1);
    vertex_position_3d(global.v_buffer,  _s,  _s, _zt); vertex_color(global.v_buffer, _col_top, 1);
    vertex_position_3d(global.v_buffer,  _s,  _s, _zb); vertex_color(global.v_buffer, _col_bot, 1);
    vertex_position_3d(global.v_buffer,  _s, -_s, _zb); vertex_color(global.v_buffer, _col_bot, 1);
    // Wall -X
    vertex_position_3d(global.v_buffer, -_s, -_s, _zt); vertex_color(global.v_buffer, _col_top, 1);
    vertex_position_3d(global.v_buffer, -_s,  _s, _zt); vertex_color(global.v_buffer, _col_top, 1);
    vertex_position_3d(global.v_buffer, -_s, -_s, _zb); vertex_color(global.v_buffer, _col_bot, 1);
    vertex_position_3d(global.v_buffer, -_s,  _s, _zt); vertex_color(global.v_buffer, _col_top, 1);
    vertex_position_3d(global.v_buffer, -_s,  _s, _zb); vertex_color(global.v_buffer, _col_bot, 1);
    vertex_position_3d(global.v_buffer, -_s, -_s, _zb); vertex_color(global.v_buffer, _col_bot, 1);
    // Wall +Y
    vertex_position_3d(global.v_buffer, -_s,  _s, _zt); vertex_color(global.v_buffer, _col_top, 1);
    vertex_position_3d(global.v_buffer,  _s,  _s, _zt); vertex_color(global.v_buffer, _col_top, 1);
    vertex_position_3d(global.v_buffer, -_s,  _s, _zb); vertex_color(global.v_buffer, _col_bot, 1);
    vertex_position_3d(global.v_buffer,  _s,  _s, _zt); vertex_color(global.v_buffer, _col_top, 1);
    vertex_position_3d(global.v_buffer,  _s,  _s, _zb); vertex_color(global.v_buffer, _col_bot, 1);
    vertex_position_3d(global.v_buffer, -_s,  _s, _zb); vertex_color(global.v_buffer, _col_bot, 1);
    // Wall -Y
    vertex_position_3d(global.v_buffer, -_s, -_s, _zt); vertex_color(global.v_buffer, _col_top, 1);
    vertex_position_3d(global.v_buffer,  _s, -_s, _zt); vertex_color(global.v_buffer, _col_top, 1);
    vertex_position_3d(global.v_buffer, -_s, -_s, _zb); vertex_color(global.v_buffer, _col_bot, 1);
    vertex_position_3d(global.v_buffer,  _s, -_s, _zt); vertex_color(global.v_buffer, _col_top, 1);
    vertex_position_3d(global.v_buffer,  _s, -_s, _zb); vertex_color(global.v_buffer, _col_bot, 1);
    vertex_position_3d(global.v_buffer, -_s, -_s, _zb); vertex_color(global.v_buffer, _col_bot, 1);
    // Floor (bottom, ground colour, flat)
    vertex_position_3d(global.v_buffer, -_s, -_s, _zb); vertex_color(global.v_buffer, _col_bot, 1);
    vertex_position_3d(global.v_buffer,  _s, -_s, _zb); vertex_color(global.v_buffer, _col_bot, 1);
    vertex_position_3d(global.v_buffer, -_s,  _s, _zb); vertex_color(global.v_buffer, _col_bot, 1);
    vertex_position_3d(global.v_buffer,  _s, -_s, _zb); vertex_color(global.v_buffer, _col_bot, 1);
    vertex_position_3d(global.v_buffer,  _s,  _s, _zb); vertex_color(global.v_buffer, _col_bot, 1);
    vertex_position_3d(global.v_buffer, -_s,  _s, _zb); vertex_color(global.v_buffer, _col_bot, 1);
    // Ceiling (top, sky colour, flat)
    vertex_position_3d(global.v_buffer, -_s, -_s, _zt); vertex_color(global.v_buffer, _col_top, 1);
    vertex_position_3d(global.v_buffer,  _s, -_s, _zt); vertex_color(global.v_buffer, _col_top, 1);
    vertex_position_3d(global.v_buffer, -_s,  _s, _zt); vertex_color(global.v_buffer, _col_top, 1);
    vertex_position_3d(global.v_buffer,  _s, -_s, _zt); vertex_color(global.v_buffer, _col_top, 1);
    vertex_position_3d(global.v_buffer,  _s,  _s, _zt); vertex_color(global.v_buffer, _col_top, 1);
    vertex_position_3d(global.v_buffer, -_s,  _s, _zt); vertex_color(global.v_buffer, _col_top, 1);

    vertex_end(global.v_buffer);
    vertex_submit(global.v_buffer, pr_trianglelist, -1);
}