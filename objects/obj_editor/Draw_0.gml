/// @desc DRAW EVENT of obj_editor


draw_clear(bg_col_bot);

// Pixel editor covers the whole screen from Draw GUI
if (pe_open) {
    exit;
}

// --- 1. BUILD CAMERA MATRICES ---
var _cx = cam_look_x + dcos(cam_yaw) * dcos(cam_pitch) * cam_dist;
var _cy = cam_look_y + dsin(cam_yaw) * dcos(cam_pitch) * cam_dist;
var _cz = cam_look_z - dsin(cam_pitch) * cam_dist;

var _view = matrix_build_lookat(_cx, _cy, _cz, cam_look_x, cam_look_y, cam_look_z, 0, 0, 1);
var _proj = matrix_build_projection_perspective_fov(60, window_get_width() / window_get_height(), 1, 32000);

camera_set_view_mat(camera_get_active(), _view);
camera_set_proj_mat(camera_get_active(), _proj);
camera_apply(camera_get_active());

// Skybox and grid always draw smooth; the T toggle only applies to tile textures
gpu_set_tex_filter(true);

// --- SKYBOX ENCLOSURE (drawn first, no culling, no depth write) ---
gpu_set_cullmode(cull_noculling);
gpu_set_zwriteenable(false);
draw_skybox(50, -50, bg_col_top, bg_col_bot);
gpu_set_zwriteenable(true);

// --- 2. DRAW GROUND GRID (shifted by decal offset along active plane normal) ---
if (grid_visible) {
	var _g_off = grid_offset * cm_world;
	var _gx = 0;
	var _gy = 0;
	var _gz = 0;
	if (active_plane == "XY") {
	    var _gside = (_cz < 0) ? -1 : 1;
	    _gz = _g_off * _gside;
	}
	if (active_plane == "XZ") {
	    var _gside = (_cy < 0) ? -1 : 1;
	    _gy = _g_off * _gside;
	}
	if (active_plane == "YZ") {
	    var _gside = (_cx < 0) ? 1 : -1;
	    _gx = _g_off * _gside;
	}
	for (var i = -20; i <= 20; i++) {
	    var _color = (i == 0) ? c_red : c_gray;
	    draw_line_3d(i + _gx, -20 + _gy, _gz, i + _gx, 20 + _gy, _gz, _color);
	    _color = (i == 0) ? c_green : c_gray;
	    draw_line_3d(-20 + _gx, i + _gy, _gz, 20 + _gx, i + _gy, _gz, _color);
	}

	// Reference grid at zero offset (mid-blue), drawn only when offset is active
	if (grid_offset != 0) {
	    var _ref_blue = make_color_rgb(80, 120, 220);
	    for (var i = -20; i <= 20; i++) {
	        draw_line_3d(i, -20, 0, i, 20, 0, _ref_blue);
	        draw_line_3d(-20, i, 0, 20, i, 0, _ref_blue);
	    }
	}
}

// --- 3. DRAW PLACED TILES (filter follows the T toggle) ---
gpu_set_tex_filter(tex_filter_on);
if (cull_on) {
    gpu_set_cullmode(cull_clockwise);
} else {
    gpu_set_cullmode(cull_noculling);
}
var _names = variable_struct_get_names(global.world_tiles);
for (var i = 0; i < array_length(_names); i++) {
    var _t = variable_struct_get(global.world_tiles, _names[i]);
    draw_tile_quad_textured(_t.x, _t.y, _t.z, _t.plane, c_white, _t.sub, 1, _t.rot, _t.facing, _t.off_x, _t.off_y, _t.off_z, _t.flip_x, _t.flip_y);
}

// --- 4. DRAW GHOST TILE (always visible, never culled; hidden while orbiting) ---
gpu_set_cullmode(cull_noculling);
if (!mouse_check_button(mb_right) && !mouse_check_button(mb_middle) && !palette_open && !menu_blocks_mouse) {
    var _ghost_facing = 1;
    if (active_plane == "XY") { _ghost_facing = (_cz < -ghost_z) ? -1 : 1; }
    if (active_plane == "XZ") { _ghost_facing = (_cy < ghost_y) ? -1 : 1; }
    if (active_plane == "YZ") { _ghost_facing = (_cx < ghost_x) ? -1 : 1; }

    for (var _gr = 0; _gr < brush_rows; _gr++) {
        for (var _gc = 0; _gc < brush_cols; _gc++) {
            var _garr_flip_x = (ghost_flip_x != FLIP_X_DEFAULT);
            var _garr_flip_y = (ghost_flip_y != FLIP_Y_DEFAULT);

            var _grev_c = _garr_flip_x;
            var _grev_r = _garr_flip_y;
            if (brush_rot == 1 || brush_rot == 3) {
                _grev_c = _garr_flip_y;
                _grev_r = _garr_flip_x;
            }

            var _gsrc_c = _grev_c ? (brush_cols - 1 - _gc) : _gc;
            var _gsrc_r = _grev_r ? (brush_rows - 1 - _gr) : _gr;
            var _gsub = brush_subs[_gsrc_r * brush_cols + _gsrc_c];

            var _gx2 = ghost_x;
            var _gy2 = ghost_y;
            var _gz2 = ghost_z;

            var _gctr_c = floor((brush_cols - 1) / 2);
            var _gctr_r = floor((brush_rows - 1) / 2);

            if (active_plane == "XY") { _gx2 -= (_gc - _gctr_c); _gy2 -= (_gr - _gctr_r); }
            if (active_plane == "XZ") { _gx2 -= (_gc - _gctr_c); _gz2 += (_gr - _gctr_r); }
            if (active_plane == "YZ") { _gy2 -= (_gc - _gctr_c); _gz2 += (_gr - _gctr_r); }

            draw_tile_quad_textured(_gx2, _gy2, _gz2, active_plane, c_white, _gsub, 0.5, ghost_rot, _ghost_facing, ghost_off_x, ghost_off_y, ghost_off_z, ghost_flip_x, ghost_flip_y);
        }
    }
}

// Back to smooth for anything drawn after the tiles
gpu_set_tex_filter(true);
