function draw_tile_quad(_x, _y, _z, _plane, _color) {
    vertex_begin(global.v_buffer, global.v_format);
    
    var _x2 = _x + 1;
    var _y2 = _y + 1;
    var _z2 = _z + 1;
    
    // We draw two triangles to make one square (quad)
var _zoff = -_z - 0.01;
    if (_plane == "XY") {
        // Triangle 1
        vertex_position_3d(global.v_buffer, _x,  _y,  _zoff); vertex_color(global.v_buffer, _color, 0.5);
        vertex_position_3d(global.v_buffer, _x2, _y,  _zoff); vertex_color(global.v_buffer, _color, 0.5);
        vertex_position_3d(global.v_buffer, _x,  _y2, _zoff); vertex_color(global.v_buffer, _color, 0.5);
        // Triangle 2
        vertex_position_3d(global.v_buffer, _x2, _y,  _zoff); vertex_color(global.v_buffer, _color, 0.5);
        vertex_position_3d(global.v_buffer, _x2, _y2, _zoff); vertex_color(global.v_buffer, _color, 0.5);
        vertex_position_3d(global.v_buffer, _x,  _y2, _zoff); vertex_color(global.v_buffer, _color, 0.5);
    }
    else if (_plane == "XZ") {
        vertex_position_3d(global.v_buffer, _x, _y, _z);  vertex_color(global.v_buffer, _color, 0.5);
        vertex_position_3d(global.v_buffer, _x2, _y, _z); vertex_color(global.v_buffer, _color, 0.5);
        vertex_position_3d(global.v_buffer, _x, _y, _z2); vertex_color(global.v_buffer, _color, 0.5);
        
        vertex_position_3d(global.v_buffer, _x2, _y, _z); vertex_color(global.v_buffer, _color, 0.5);
        vertex_position_3d(global.v_buffer, _x2, _y, _z2);vertex_color(global.v_buffer, _color, 0.5);
        vertex_position_3d(global.v_buffer, _x, _y, _z2); vertex_color(global.v_buffer, _color, 0.5);
    }
    else if (_plane == "YZ") {
        vertex_position_3d(global.v_buffer, _x, _y, _z);  vertex_color(global.v_buffer, _color, 0.5);
        vertex_position_3d(global.v_buffer, _x, _y2, _z); vertex_color(global.v_buffer, _color, 0.5);
        vertex_position_3d(global.v_buffer, _x, _y, _z2); vertex_color(global.v_buffer, _color, 0.5);
        
        vertex_position_3d(global.v_buffer, _x, _y2, _z); vertex_color(global.v_buffer, _color, 0.5);
        vertex_position_3d(global.v_buffer, _x, _y2, _z2);vertex_color(global.v_buffer, _color, 0.5);
        vertex_position_3d(global.v_buffer, _x, _y, _z2); vertex_color(global.v_buffer, _color, 0.5);
    }

    vertex_end(global.v_buffer);
    vertex_submit(global.v_buffer, pr_trianglelist, -1);
}

