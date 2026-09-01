function draw_line_3d(x1, y1, z1, x2, y2, z2, _color = c_white) {
    vertex_begin(global.v_buffer, global.v_format);
    vertex_position_3d(global.v_buffer, x1, y1, z1); vertex_color(global.v_buffer, _color, 1);
    vertex_position_3d(global.v_buffer, x2, y2, z2); vertex_color(global.v_buffer, _color, 1);
    vertex_end(global.v_buffer);
    vertex_submit(global.v_buffer, pr_linelist, -1);
}