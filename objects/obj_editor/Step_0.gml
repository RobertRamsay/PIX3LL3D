/// @desc STEP EVENT of obj_editor

// --- UI SCALE + MENU BAR (menu runs first so a click this frame drives the shortcuts below) ---
// Window housekeeping first: it finishes any fullscreen change already in
// flight before anything else reads the window size this frame.
window_update();
ui_update_gui_size();
menu_update();

// --- FULLSCREEN / WINDOWED (F10; works in both editors) ---
if (keyboard_check_pressed(vk_f10) || menu_action == "fullscreen")
{
    window_toggle_fullscreen();
}

// --- ABOUT PANEL (modal: it eats all input while it is open) ---
about_update();

// Update banner: clickable in both editors, so it runs before the pe branch
about_banner_update();
if (about_visible)
{
    exit;
}

// --- PRO PANEL (modal in both editors; demo builds only) ---
demo_update();
if (demo_visible)
{
    exit;
}

// --- TILESET CELL SIZE (works in BOTH editors, so it sits above the pe branch) ---
if (tile_msg_timer > 0)
{
    tile_msg_timer -= 1;
}

if (menu_action == "cell_auto")
{
    global.tile_cell_pref = 0;
}
if (menu_action == "cell_8")
{
    global.tile_cell_pref = 8;
}
if (menu_action == "cell_16")
{
    global.tile_cell_pref = 16;
}
if (menu_action == "cell_24")
{
    global.tile_cell_pref = 24;
}
if (menu_action == "cell_32")
{
    global.tile_cell_pref = 32;
}

// Re-slice whatever sheet is loaded, built-in or imported, at the chosen size
if (menu_action == "cell_reimport")
{
    var _was_pe = pe_open;

    // Bake any pixel edits first so re-slicing never loses work
    if (_was_pe)
    {
        pe_apply();
    }

    var _re = tileset_reslice_active(global.tile_cell_pref, palette_cols);
    if (_re >= 0)
    {
        var _old = global.tile_custom;
        global.tile_custom = _re;
        global.tile_sprite = _re;
        global.tile_is_custom = true;
        palette_cols = max(1, global.tile_custom_cols);
        active_sub = 0;
        brush_subs = [0];
        brush_cols = 1;
        brush_rows = 1;

        if (_old >= 0 && sprite_exists(_old) && _old != _re)
        {
            sprite_delete(_old);
        }

        tile_msg = "Re-sliced at " + string(global.tile_cell) + "px - " + string(sprite_get_number(_re)) + " tiles, " + string(palette_cols) + " cols";
        tile_msg_timer = room_speed * 4;

        // Reload the pixel editor so it picks up the new cell size
        if (_was_pe)
        {
            pe_open_editor();
        }
    }
    else
    {
        tile_msg = "Cannot re-slice this sheet at that size - try another";
        tile_msg_timer = room_speed * 4;
    }
}

// --- NEW EMPTY TILESET SHEET (works from either editor) ---
var _new_w = 0;
var _new_h = 0;
if (menu_action == "sheet_new_64")
{
    _new_w = 64;
    _new_h = 64;
}
if (menu_action == "sheet_new_128")
{
    _new_w = 128;
    _new_h = 128;
}
if (menu_action == "sheet_new_256")
{
    _new_w = 256;
    _new_h = 256;
}
if (menu_action == "sheet_new_512")
{
    _new_w = 512;
    _new_h = 512;
}
if (menu_action == "sheet_new_1024x512")
{
    _new_w = 1024;
    _new_h = 512;
}

if (_new_w > 0)
{
    // Unsaved pixel work would go with the old sheet: the same size has to be
    // picked twice to go ahead, so nothing is lost by one stray click.
    if (pe_png_dirty && sheet_new_pending != menu_action)
    {
        sheet_new_pending = menu_action;
        tile_msg = "Texture edits are not saved - pick that size again to start anyway";
        tile_msg_timer = room_speed * 5;
    }
    else
    {
        sheet_new_pending = "";

        var _blank = tileset_new_blank(_new_w, _new_h, global.tile_cell_pref);
        if (_blank == -2)
        {
            tile_msg = "That sheet would hold over " + string(TILESET_MAX_TILES) + " tiles - use a bigger cell size";
            tile_msg_timer = room_speed * 4;
        }
        else if (_blank < 0)
        {
            tile_msg = "Cell size does not divide " + string(_new_w) + "x" + string(_new_h) + " - pick another in Tileset > Cell size";
            tile_msg_timer = room_speed * 4;
        }
        else
        {
            var _old_sheet = global.tile_custom;
            global.tile_custom = _blank;
            global.tile_sprite = _blank;
            global.tile_is_custom = true;
            global.tile_custom_path = ""; // nothing on disk yet; Ctrl+S will ask

            palette_cols = max(1, global.tile_custom_cols);
            active_sub = 0;
            brush_subs = [0];
            brush_cols = 1;
            brush_rows = 1;
            brush_rot = 0;
            ghost_rot = 0;
            ghost_flip_x = FLIP_X_DEFAULT;
            ghost_flip_y = FLIP_Y_DEFAULT;

            if (_old_sheet >= 0 && sprite_exists(_old_sheet) && _old_sheet != _blank)
            {
                sprite_delete(_old_sheet);
            }

            pe_png_dirty = false;

            tile_msg = "New " + string(_new_w) + "x" + string(_new_h) + " sheet - " + string(sprite_get_number(_blank)) + " empty tiles at " + string(global.tile_cell) + "px";
            tile_msg_timer = room_speed * 4;

            // Open the pixel editor on it (or reload it if already open)
            pe_open_editor();
        }
    }
}

// --- PIXEL EDITOR (takes over all input while open) ---
if (pe_open)
{
    pe_step();
    exit;
}

// Background gradient swatch / RGB popup (can claim the mouse and Esc)
bg_ui_update();

// Post FX toggles, shortcuts and the slider panel (can claim the mouse and Esc)
postfx_update();

// Clip strip down the left edge (claims the mouse over its cells)
clip_strip_update();

if ((keyboard_check_pressed(ord("P")) && !keyboard_check(vk_control)) || menu_action == "pe_toggle")
{
    pe_open_editor();
    exit;
}

// Esc first cancels a selection or puts down the held cluster
if (keyboard_check_pressed(vk_escape) && !menu_esc_consumed)
{
    if (clip_held >= 0 || sel_dragging || array_length(sel_keys) > 0)
    {
        clip_held = -1;
        sel_keys = [];
        sel_dragging = false;
        menu_esc_consumed = true;
    }
}

if ((keyboard_check_pressed(vk_escape) && !menu_esc_consumed) || menu_action == "quit")
{
    game_end();
}

if (keyboard_check_pressed(vk_enter) || menu_action == "restart")
{
    game_restart();
}



// --- 1. CAMERA CONTROLS ---
// Orbit/tilt: Alt + Middle Mouse
var _orbit_held = keyboard_check(vk_alt) && mouse_check_button(mb_middle);
var _orbit_start = keyboard_check(vk_alt) && mouse_check_button_pressed(mb_middle);

if (_orbit_start) {
    window_set_cursor(cr_none);
    window_mouse_set(window_get_width() / 2, window_get_height() / 2);
    cam_dragging = false;
}

if (_orbit_held) {
    var _win_w = window_get_width();
    var _win_h = window_get_height();
    var _cx_win = _win_w / 2;
    var _cy_win = _win_h / 2;

    if (cam_dragging) {
        var _m_x = window_mouse_get_x();
        var _m_y = window_mouse_get_y();

        var _dx = _m_x - _cx_win;
        var _dy = _m_y - _cy_win;

        // Dead-zone: ignore sub-pixel residual from the cursor warp not landing exactly
        if (abs(_dx) <= 1) { _dx = 0; }
        if (abs(_dy) <= 1) { _dy = 0; }

        cam_yaw += _dx * 0.2;
        cam_pitch -= _dy * 0.2;
        cam_pitch = clamp(cam_pitch, -89, 89);
    }

    cam_dragging = true;
    window_mouse_set(_cx_win, _cy_win);
}

if (mouse_check_button_released(mb_middle)) {
    window_set_cursor(cr_default);
    cam_dragging = false;
}

// --- MIDDLE MOUSE PAN (plain MMB; Alt+MMB is orbit) ---
if (mouse_check_button_pressed(mb_middle) && !keyboard_check(vk_alt)) {
    // Record the 3D world point under the mouse at press time
    // Cast a ray from camera through the mouse position and hit Z=0 plane
    var _win_w = window_get_width();
    var _win_h = window_get_height();
    var _mx_ndc = (window_mouse_get_x() / _win_w) * 2 - 1;
    var _my_ndc = 1 - (window_mouse_get_y() / _win_h) * 2;

    // Camera basis vectors
    var _cam_x = cam_look_x + dcos(cam_yaw) * dcos(cam_pitch) * cam_dist;
    var _cam_y = cam_look_y + dsin(cam_yaw) * dcos(cam_pitch) * cam_dist;
    var _cam_z = cam_look_z - dsin(cam_pitch) * cam_dist;

    var _fwd_x = cam_look_x - _cam_x;
    var _fwd_y = cam_look_y - _cam_y;
    var _fwd_z = cam_look_z - _cam_z;
    var _fwd_len = sqrt(_fwd_x * _fwd_x + _fwd_y * _fwd_y + _fwd_z * _fwd_z);
    _fwd_x /= _fwd_len;
    _fwd_y /= _fwd_len;
    _fwd_z /= _fwd_len;

    var _right_x = dcos(cam_yaw - 90);
    var _right_y = dsin(cam_yaw - 90);
    var _right_z = 0;

    // Up = cross(right, fwd)
    var _up_x = _right_y * _fwd_z - _right_z * _fwd_y;
    var _up_y = _right_z * _fwd_x - _right_x * _fwd_z;
    var _up_z = _right_x * _fwd_y - _right_y * _fwd_x;

    // Scale by FOV and aspect
    var _aspect = _win_w / _win_h;
    var _fov_scale = tan(degtorad(60) / 2);

    var _ray_x = _fwd_x + (_right_x * _mx_ndc * _aspect + _up_x * _my_ndc) * _fov_scale;
    var _ray_y = _fwd_y + (_right_y * _mx_ndc * _aspect + _up_y * _my_ndc) * _fov_scale;
    var _ray_z = _fwd_z + (_right_z * _mx_ndc * _aspect + _up_z * _my_ndc) * _fov_scale;

    // Intersect ray with the ACTIVE plane (passing through the look target)
    if (active_plane == "XY") {
        // constant axis Z, plane at cam_look_z
        if (abs(_ray_z) > 0.0001) {
            var _t = (cam_look_z - _cam_z) / _ray_z;
            cam_pan_anchor_x = _cam_x + _ray_x * _t;
            cam_pan_anchor_y = _cam_y + _ray_y * _t;
            cam_pan_anchor_z = _cam_z + _ray_z * _t;
        }
    } else if (active_plane == "XZ") {
        // constant axis Y, plane at cam_look_y
        if (abs(_ray_y) > 0.0001) {
            var _t = (cam_look_y - _cam_y) / _ray_y;
            cam_pan_anchor_x = _cam_x + _ray_x * _t;
            cam_pan_anchor_y = _cam_y + _ray_y * _t;
            cam_pan_anchor_z = _cam_z + _ray_z * _t;
        }
    } else { // YZ
        // constant axis X, plane at cam_look_x
        if (abs(_ray_x) > 0.0001) {
            var _t = (cam_look_x - _cam_x) / _ray_x;
            cam_pan_anchor_x = _cam_x + _ray_x * _t;
            cam_pan_anchor_y = _cam_y + _ray_y * _t;
            cam_pan_anchor_z = _cam_z + _ray_z * _t;
        }
    }

    cam_panning = true;
}

if (mouse_check_button(mb_middle) && cam_panning && !keyboard_check(vk_alt)) {
    // Each frame, find where the mouse ray hits Z=0 now
    var _win_w = window_get_width();
    var _win_h = window_get_height();
    var _mx_ndc = (window_mouse_get_x() / _win_w) * 2 - 1;
    var _my_ndc = 1 - (window_mouse_get_y() / _win_h) * 2;

    var _cam_x = cam_look_x + dcos(cam_yaw) * dcos(cam_pitch) * cam_dist;
    var _cam_y = cam_look_y + dsin(cam_yaw) * dcos(cam_pitch) * cam_dist;
    var _cam_z = cam_look_z - dsin(cam_pitch) * cam_dist;

    var _fwd_x = cam_look_x - _cam_x;
    var _fwd_y = cam_look_y - _cam_y;
    var _fwd_z = cam_look_z - _cam_z;
    var _fwd_len = sqrt(_fwd_x * _fwd_x + _fwd_y * _fwd_y + _fwd_z * _fwd_z);
    _fwd_x /= _fwd_len;
    _fwd_y /= _fwd_len;
    _fwd_z /= _fwd_len;

    var _right_x = dcos(cam_yaw - 90);
    var _right_y = dsin(cam_yaw - 90);
    var _right_z = 0;

    var _up_x = _right_y * _fwd_z - _right_z * _fwd_y;
    var _up_y = _right_z * _fwd_x - _right_x * _fwd_z;
    var _up_z = _right_x * _fwd_y - _right_y * _fwd_x;

    var _aspect = _win_w / _win_h;
    var _fov_scale = tan(degtorad(60) / 2);

    var _ray_x = _fwd_x + (_right_x * _mx_ndc * _aspect + _up_x * _my_ndc) * _fov_scale;
    var _ray_y = _fwd_y + (_right_y * _mx_ndc * _aspect + _up_y * _my_ndc) * _fov_scale;
    var _ray_z = _fwd_z + (_right_z * _mx_ndc * _aspect + _up_z * _my_ndc) * _fov_scale;

    var _hit_x = _cam_x;
    var _hit_y = _cam_y;
    var _hit_z = _cam_z;
    var _valid = false;

    if (active_plane == "XY") {
        if (abs(_ray_z) > 0.0001) {
            var _t = (cam_look_z - _cam_z) / _ray_z;
            _hit_x = _cam_x + _ray_x * _t;
            _hit_y = _cam_y + _ray_y * _t;
            _hit_z = _cam_z + _ray_z * _t;
            _valid = true;
        }
    } else if (active_plane == "XZ") {
        if (abs(_ray_y) > 0.0001) {
            var _t = (cam_look_y - _cam_y) / _ray_y;
            _hit_x = _cam_x + _ray_x * _t;
            _hit_y = _cam_y + _ray_y * _t;
            _hit_z = _cam_z + _ray_z * _t;
            _valid = true;
        }
    } else { // YZ
        if (abs(_ray_x) > 0.0001) {
            var _t = (cam_look_x - _cam_x) / _ray_x;
            _hit_x = _cam_x + _ray_x * _t;
            _hit_y = _cam_y + _ray_y * _t;
            _hit_z = _cam_z + _ray_z * _t;
            _valid = true;
        }
    }

    if (_valid) {
        // Move the look target so the anchor stays under the mouse (all 3 axes)
        cam_look_x += cam_pan_anchor_x - _hit_x;
        cam_look_y += cam_pan_anchor_y - _hit_y;
        cam_look_z += cam_pan_anchor_z - _hit_z;
    }
}

if (mouse_check_button_released(mb_middle)) {
    cam_panning = false;
}

// --- MOUSE WHEEL ZOOM ---
if (mouse_wheel_up()) {
    cam_dist -= 1;
}
if (mouse_wheel_down()) {
    cam_dist += 1;
}
cam_dist = clamp(cam_dist, 2, 100);

// --- TILE TEXTURE FILTER TOGGLE (only affects placed tiles + ghost; see Draw) ---
if (keyboard_check_pressed(ord("T")) || menu_action == "tex_filter") {
    tex_filter_on = !tex_filter_on;
}

// --- BACKFACE CULLING TOGGLE ---
if (keyboard_check_pressed(ord("B")) || menu_action == "cull") {
    cull_on = !cull_on;
}

// --- GRID TOGGLE ---
if (keyboard_check_pressed(ord("G")) || menu_action == "grid") {
    grid_visible = !grid_visible;
}

// --- RESET VIEW (Home) ---
if (keyboard_check_pressed(vk_home) || menu_action == "reset_view") {
    cam_dist = cam_dist_default;
    cam_pitch = cam_pitch_default;
    cam_yaw = cam_yaw_default;
    cam_look_x = cam_look_x_default;
    cam_look_y = cam_look_y_default;
    cam_look_z = cam_look_z_default;
}

// --- SAVE / LOAD ---
var _ctrl = keyboard_check(vk_control);
    var _shift = keyboard_check(vk_shift);
    var _alt = keyboard_check(vk_alt);

    if ((_alt && _shift && keyboard_check_pressed(ord("S"))) || menu_action == "export_obj")
    {
        // Demo build stops here and explains why (see DEMO_system)
        if (!demo_lock("OBJ export"))
        {
            var _obj_path = get_save_filename_safe("OBJ model|*.obj", "model.obj");
            if (_obj_path != "")
            {
                scene_export_obj(_obj_path);
            }
        }
    }

// Ctrl+Shift+S = Save As (new file), Ctrl+S = save over last known file
var _do_save_as = false;
var _do_save = false;
if (_ctrl && _shift && keyboard_check_pressed(ord("S"))) {
    _do_save_as = true;
}
else if (_ctrl && keyboard_check_pressed(ord("S"))) {
    _do_save = true;
}
if (menu_action == "scene_save_as") {
    _do_save_as = true;
}
if (menu_action == "scene_save") {
    _do_save = true;
}
// Plain save with no file yet falls back to Save As
if (_do_save && scene_path == "") {
    _do_save = false;
    _do_save_as = true;
}

if (_do_save_as) {
    var _path = get_save_filename_safe("Scene files (*.scene)|*.scene", "untitled.scene");
    if (_path != "") {
        scene_path = _path;
        scene_save(scene_path);
        recent_add(scene_path);
    }
}
else if (_do_save) {
    scene_save(scene_path);
    recent_add(scene_path);
}

// Ctrl+L = Load
if ((_ctrl && keyboard_check_pressed(ord("L"))) || menu_action == "scene_load") {
    var _path = get_open_filename_safe("Scene files (*.scene)|*.scene", "");
    if (_path != "") {
        if (scene_load(_path)) {
            scene_path = _path;
            recent_add(scene_path);
        }
    }
}

// --- RECENT SCENES (File menu, newest first) ---
if (menu_action == "recent_clear") {
    recent_clear();
    tile_msg = "Recent scenes cleared";
    tile_msg_timer = room_speed * 2;
}

var _recent_pick = -1;
for (var _ri = 0; _ri < RECENT_MAX; _ri++) {
    if (menu_action == "recent_" + string(_ri)) {
        _recent_pick = _ri;
    }
}

if (_recent_pick >= 0 && _recent_pick < array_length(global.recent_scenes)) {
    var _rpath = global.recent_scenes[_recent_pick];
    if (!file_exists(_rpath)) {
        tile_msg = "Not there any more - taken off the list: " + filename_name(_rpath);
        tile_msg_timer = room_speed * 4;
        recent_remove_at(_recent_pick);
    }
    else if (scene_load(_rpath)) {
        scene_path = _rpath;
        recent_add(scene_path);
        tile_msg = "Loaded " + filename_name(_rpath);
        tile_msg_timer = room_speed * 3;
    }
    else {
        tile_msg = "Could not read " + filename_name(_rpath);
        tile_msg_timer = room_speed * 4;
    }
}

// --- TILESET IMPORT (Ctrl+I) / SWITCH (F2 custom, F1 built-in) ---
if ((_ctrl && keyboard_check_pressed(ord("I"))) || menu_action == "tiles_import") {
    var _ts_path = get_open_filename_safe("PNG image (*.png)|*.png", "");
    if (_ts_path != "") {
        var _loaded = tileset_import(_ts_path, global.tile_cell_pref);
        if (_loaded >= 0) {
            if (global.tile_custom >= 0 && sprite_exists(global.tile_custom)) {
                sprite_delete(global.tile_custom);
            }
            global.tile_custom = _loaded;
            global.tile_custom_path = _ts_path;
            global.tile_sprite = _loaded;
            global.tile_is_custom = true;
            palette_cols = max(1, global.tile_custom_cols);
            active_sub = 0;
            brush_subs = [0];
            brush_cols = 1;
            brush_rows = 1;
        }
    }
}

if (keyboard_check_pressed(vk_f2) || menu_action == "tiles_custom") {
    if (global.tile_custom >= 0 && sprite_exists(global.tile_custom)) {
        global.tile_sprite = global.tile_custom;
        global.tile_is_custom = true;
        global.tile_cell = sprite_get_width(global.tile_custom);
        palette_cols = max(1, global.tile_custom_cols);
        active_sub = 0;
        brush_subs = [0];
        brush_cols = 1;
        brush_rows = 1;
    }
}

if (keyboard_check_pressed(vk_f1) || menu_action == "tiles_builtin") {
    global.tile_sprite = spr_tile;
    global.tile_is_custom = false;
    global.tile_cell = sprite_get_width(spr_tile);
    palette_cols = palette_cols_builtin;
    active_sub = 0;
    brush_subs = [0];
    brush_cols = 1;
    brush_rows = 1;
}



// Ctrl+Z = Undo, Ctrl+Y = Redo
if ((_ctrl && keyboard_check_pressed(ord("Z"))) || menu_action == "undo") {
    undo_perform();
}
if ((_ctrl && keyboard_check_pressed(ord("Y"))) || menu_action == "redo") {
    redo_perform();
}

// Sweep the whole scene for faces sitting back to back
if (menu_action == "clean_faces") {
    undo_push_snapshot();
    var _cleaned = world_cancel_back_to_back();
    if (_cleaned > 0) {
        tile_msg = "Removed " + string(_cleaned) + " faces sitting back to back";
    }
    else {
        tile_msg = "No back-to-back faces found";
    }
    tile_msg_timer = room_speed * 3;
}

// --- DECAL OFFSET (1 forward, Tab+1 back, 0 reset) ---
var _decal_step = 0;
if (keyboard_check_pressed(ord("1"))) {
    if (keyboard_check(vk_tab)) {
        _decal_step = 1;
    } else {
        _decal_step = -1;
    }
}
if (menu_action == "decal_fwd") {
    _decal_step = -1;
}
if (menu_action == "decal_back") {
    _decal_step = 1;
}
if (_decal_step != 0) {
    grid_offset += _decal_step;
    grid_offset = clamp(grid_offset, -grid_offset_max, grid_offset_max);
}

if (keyboard_check_pressed(ord("0")) || menu_action == "decal_reset") {
    grid_offset = 0;
}

// --- BRUSH NUDGE (arrow keys, one texture pixel a step; see BRUSH_system) ---
brush_nudge_update();
// --- TILE PALETTE (hold SPACE) ---
palette_phase += 0.02; // gradient animation speed (tunable)

if (keyboard_check_pressed(vk_space)) {
    var _count = sprite_get_number(global.tile_sprite);
    var _rows = max(1, ceil(_count / palette_cols));
    var _gw = display_get_gui_width();
    var _gh = display_get_gui_height();
    var _margin = 8;
    var _top = menu_bar_h + _margin;

    // Shrink the cells (never below palette_cell_min) when a big sheet
    // would not fit the screen at full size.
    var _fit_w = floor((_gw - _margin * 2 - palette_pad) / palette_cols) - palette_pad;
    var _fit_h = floor((_gh - _top - _margin - palette_pad) / _rows) - palette_pad;
    palette_cell = clamp(min(_fit_w, _fit_h), palette_cell_min, palette_cell_max);

    // Centre the used columns under the mouse, as before
    var _used_cols = min(_count, palette_cols);
    var _used_w = _used_cols * (palette_cell + palette_pad) + palette_pad;
    palette_x = floor(device_mouse_x_to_gui(0) - _used_w * 0.5);
    palette_y = floor(device_mouse_y_to_gui(0) + 30);

    // Clamp so the drawn panel (palette_x - pad .. + full width) stays in view.
    // Right/bottom first, then left/top, so left/top win if it still can't fit.
    var _pw = palette_cols * (palette_cell + palette_pad) + palette_pad;
    var _ph = _rows * (palette_cell + palette_pad) + palette_pad;
    palette_x = min(palette_x, _gw - _margin - _pw + palette_pad);
    palette_x = max(palette_x, _margin + palette_pad);
    palette_y = min(palette_y, _gh - _margin - _ph + palette_pad);
    palette_y = max(palette_y, _top + palette_pad);
}
palette_open = keyboard_check(vk_space);

if (palette_open) {
    var _count = sprite_get_number(global.tile_sprite);
    var _mx = device_mouse_x_to_gui(0);
    var _my = device_mouse_y_to_gui(0);

    palette_hover = -1;
    for (var _i = 0; _i < _count; _i++) {
        var _col = _i mod palette_cols;
        var _row = _i div palette_cols;
        var _cell_x = palette_x + _col * (palette_cell + palette_pad);
        var _cell_y = palette_y + _row * (palette_cell + palette_pad);
        if (_mx >= _cell_x && _mx < _cell_x + palette_cell && _my >= _cell_y && _my < _cell_y + palette_cell) {
            palette_hover = _i;
        }
    }

    // Begin drag on the hovered cell
    if (mouse_check_button_pressed(mb_left) && palette_hover >= 0) {
        palette_drag_start = palette_hover;
    }

    // Release: build the brush, anchored at the drag-START cell, growing
    // in the direction dragged. Signed steps preserve drag direction.
    if (mouse_check_button_released(mb_left) && palette_drag_start >= 0) {
        var _end = (palette_hover >= 0) ? palette_hover : palette_drag_start;

        var _sc = palette_drag_start mod palette_cols;
        var _sr = palette_drag_start div palette_cols;
        var _ec = _end mod palette_cols;
        var _er = _end div palette_cols;

        // Always build in sheet order (top-left to bottom-right) so the
        // tiles keep their exact arrangement regardless of drag direction.
        var _c0 = min(_sc, _ec);
        var _c1 = max(_sc, _ec);
        var _r0 = min(_sr, _er);
        var _r1 = max(_sr, _er);

        brush_cols = (_c1 - _c0) + 1;
        brush_rows = (_r1 - _r0) + 1;

        brush_subs = [];
        for (var _row = _r0; _row <= _r1; _row++) {
            for (var _col = _c0; _col <= _c1; _col++) {
                var _sub_index = _row * palette_cols + _col;
                if (_sub_index >= 0 && _sub_index < _count) {
                    array_push(brush_subs, _sub_index);
                } else {
                    array_push(brush_subs, palette_drag_start); // safe fallback
                }
            }
        }

        // Anchor tile is the top-left of the selection
        active_sub = _r0 * palette_cols + _c0;

        // Fresh brush starts unrotated, with the default flip. The tile then
        // always reads the grabbed way on every plane; only X changes it.
        brush_rot = 0;
        ghost_rot = 0;
        ghost_flip_x = FLIP_X_DEFAULT;
        ghost_flip_y = FLIP_Y_DEFAULT;

        // New tile(s) picked: the decal offset goes back to 0 (same as
        // pressing 0). Plane depth is kept.
        grid_offset = 0;
        clip_held = -1; // back to single tiles
        palette_drag_start = -1;
		brush_nudge_reset() // also reset the nudge
    }
}

// Closing the palette without a drag still cancels any partial drag state
if (keyboard_check_released(vk_space)) {
    palette_drag_start = -1;
    palette_hover = -1;
}


// --- 2. CAMERA VECTORS ---
var _lx = dcos(cam_yaw) * dcos(cam_pitch);
var _ly = dsin(cam_yaw) * dcos(cam_pitch);
var _lz = -dsin(cam_pitch);
var _raw_z = 0;

var _dir_x = -_lx;
var _dir_y = -_ly;
var _dir_z = -_lz;

var _cx = cam_look_x + _lx * cam_dist;
var _cy = cam_look_y + _ly * cam_dist;
var _cz = cam_look_z + _lz * cam_dist;

// --- 3. DETERMINE ACTIVE PLANE ---
var _abs_x = abs(_dir_x);
var _abs_y = abs(_dir_y);
var _abs_z = abs(_dir_z);

if (_abs_z >= _abs_x && _abs_z >= _abs_y) {
    active_plane = "XY";
} else if (_abs_y >= _abs_x && _abs_y >= _abs_z) {
    active_plane = "XZ";
} else {
    active_plane = "YZ";
}

// --- WASD PLANE OFFSET CONTROLS ---
var _active_offset = plane_offset_XY;
if (active_plane == "XZ") { _active_offset = plane_offset_XZ; }
if (active_plane == "YZ") { _active_offset = plane_offset_YZ; }

// --- QE DEPTH CONTROLS (Q always away from eye, E always toward) ---
// "Away" = the direction the camera is looking, projected onto this
// plane's normal axis. Sign flips correctly across all 6 view-sides.
var _away = 1;
// XY is the odd one out: its plane sits at world Z = -depth (see the raycast
// below), so its depth axis runs OPPOSITE to world Z. Without this negation
// Q and E come out swapped whenever the XY plane is active. XZ and YZ map
// depth straight onto world Y and X, so they take the sign as-is.
if (active_plane == "XY") { _away = -sign(_dir_z); }
if (active_plane == "XZ") { _away = sign(_dir_y); }
if (active_plane == "YZ") { _away = sign(_dir_x); }
if (_away == 0) { _away = 1; }

if (keyboard_check_pressed(ord("Q")) || menu_action == "depth_in") {
    _active_offset.depth += _away;
}
if (keyboard_check_pressed(ord("E")) || menu_action == "depth_out") {
    _active_offset.depth -= _away;
}

// --- W RESETS THE ACTIVE PLANE'S DEPTH OFFSET ---
var _no_mod = (!keyboard_check(vk_shift) && !keyboard_check(vk_alt) && !keyboard_check(vk_control));

if ((_no_mod && keyboard_check_pressed(ord("W"))) || menu_action == "depth_reset") {
    _active_offset.depth = 0;
}

// --- 4. GHOST TILE PLACEMENT (raycast mouse to active plane) ---
draw_set_color(c_white);
draw_text(10, 10, "ghost_z=" + string(ghost_z) + " active_plane=" + active_plane + " cz=" + string(round(_cz)));

// Build mouse ray in world space
var _win_w = window_get_width();
var _win_h = window_get_height();
var _mx_ndc = (window_mouse_get_x() / _win_w) * 2 - 1;
var _my_ndc = 1 - (window_mouse_get_y() / _win_h) * 2;

var _ghost_fwd_x = cam_look_x - _cx;
var _ghost_fwd_y = cam_look_y - _cy;
var _ghost_fwd_z = cam_look_z - _cz;
var _ghost_fwd_len = sqrt(_ghost_fwd_x * _ghost_fwd_x + _ghost_fwd_y * _ghost_fwd_y + _ghost_fwd_z * _ghost_fwd_z);
_ghost_fwd_x /= _ghost_fwd_len;
_ghost_fwd_y /= _ghost_fwd_len;
_ghost_fwd_z /= _ghost_fwd_len;

var _ghost_right_x = dcos(cam_yaw - 90);
var _ghost_right_y = dsin(cam_yaw - 90);
var _ghost_right_z = 0;

var _ghost_up_x = _ghost_right_y * _ghost_fwd_z - _ghost_right_z * _ghost_fwd_y;
var _ghost_up_y = _ghost_right_z * _ghost_fwd_x - _ghost_right_x * _ghost_fwd_z;
var _ghost_up_z = _ghost_right_x * _ghost_fwd_y - _ghost_right_y * _ghost_fwd_x;

var _ghost_aspect = _win_w / _win_h;
var _ghost_fov_scale = tan(degtorad(60) / 2);

var _ray_x = _ghost_fwd_x + (_ghost_right_x * _mx_ndc * _ghost_aspect + _ghost_up_x * _my_ndc) * _ghost_fov_scale;
var _ray_y = _ghost_fwd_y + (_ghost_right_y * _mx_ndc * _ghost_aspect + _ghost_up_y * _my_ndc) * _ghost_fov_scale;
var _ray_z = _ghost_fwd_z + (_ghost_right_z * _mx_ndc * _ghost_aspect + _ghost_up_z * _my_ndc) * _ghost_fov_scale;

// --- SHIFT TAP: MATCH DEPTH TO THE TILE UNDER THE CURSOR ---
// Shift pressed and released on its own (no other key or click in between)
// raycasts every placed tile and takes the nearest one hit:
//  - same plane as the active one: this plane's depth becomes that tile's
//    depth (the value Q/E would have to be dialled to).
//  - a perpendicular tile: this plane's depth snaps to whichever of that
//    tile's two edges lying on the active plane is nearer the cursor, so the
//    next tile meets it at a clean 90 degree corner.
// Shift+arrows, Ctrl+Shift+S and so on never count as a tap.
var _shift_tap = false;
if (keyboard_check_pressed(vk_shift)) {
    shift_tap_armed = true;
    if (keyboard_check(vk_control) || keyboard_check(vk_alt)) {
        shift_tap_armed = false;
    }
}
else if (keyboard_check(vk_shift)) {
    if (keyboard_check_pressed(vk_anykey) || mouse_check_button_pressed(mb_any)) {
        shift_tap_armed = false;
    }
    if (mouse_wheel_up() || mouse_wheel_down()) {
        shift_tap_armed = false;
    }
}
if (keyboard_check_released(vk_shift)) {
    if (shift_tap_armed && !palette_open && !menu_blocks_mouse && !clip_blocks_mouse) {
        _shift_tap = true;
    }
    shift_tap_armed = false;
}

if (_shift_tap) {
    var _hit = tile_raycast_nearest(_cx, _cy, _cz, _ray_x, _ray_y, _ray_z);

    if (_hit.found) {
        var _mt = _hit.tile;
        var _match_depth = 0;
        var _match_edge = false;

        if (_mt.plane == active_plane) {
            // Same plane: a tile's depth is its coordinate on the normal axis
            if (active_plane == "XY") {
                _match_depth = _mt.z;
            }
            if (active_plane == "XZ") {
                _match_depth = _mt.y;
            }
            if (active_plane == "YZ") {
                _match_depth = _mt.x;
            }
        }
        else {
            // Perpendicular: the tile spans one unit along the active plane's
            // normal axis. Take the end nearer the cursor.
            _match_edge = true;
            if (active_plane == "XY") {
                // XZ / YZ tiles span world Z [z, z+1]; XY depth = -world Z
                var _edge_z = _mt.z;
                if (abs(_hit.hz - (_mt.z + 1)) < abs(_hit.hz - _mt.z)) {
                    _edge_z = _mt.z + 1;
                }
                _match_depth = -_edge_z;
            }
            if (active_plane == "XZ") {
                // XY / YZ tiles span world Y [y, y+1]; XZ depth = world Y
                _match_depth = _mt.y;
                if (abs(_hit.hy - (_mt.y + 1)) < abs(_hit.hy - _mt.y)) {
                    _match_depth = _mt.y + 1;
                }
            }
            if (active_plane == "YZ") {
                // XY / XZ tiles span world X [x, x+1]; YZ depth = world X
                _match_depth = _mt.x;
                if (abs(_hit.hx - (_mt.x + 1)) < abs(_hit.hx - _mt.x)) {
                    _match_depth = _mt.x + 1;
                }
            }
        }

        _active_offset.depth = _match_depth;
        if (_match_edge) {
            tile_msg = "Depth snapped to edge: " + string(_match_depth) + " (" + active_plane + ")";
        }
        else {
            tile_msg = "Depth matched: " + string(_match_depth) + " (" + active_plane + ")";
        }
    }
    else {
        tile_msg = "No tile under the cursor to match";
    }
    tile_msg_timer = room_speed * 2;
}

// --- ALT+CLICK PICKS THE TILE UNDER THE CURSOR ---
// The tile under the cursor becomes the held tile, orientation and all, so it
// can be carried on with elsewhere. Alt+click never places anything.
if (mouse_check_button_pressed(mb_left) && keyboard_check(vk_alt) && !palette_open && !menu_blocks_mouse && !clip_blocks_mouse) {
    var _pick = tile_raycast_nearest(_cx, _cy, _cz, _ray_x, _ray_y, _ray_z);

    if (_pick.found) {
        var _pt = _pick.tile;
        active_sub = _pt.sub;
        brush_subs = [_pt.sub];
        brush_cols = 1;
        brush_rows = 1;
        brush_rot = _pt.rot;
        ghost_rot = _pt.rot;
        ghost_flip_x = _pt.flip_x;
        ghost_flip_y = _pt.flip_y;
        clip_held = -1; // back to single tiles

        tile_msg = "Picked tile " + string(_pt.sub);
        tile_msg_timer = room_speed * 2;
    }
    else {
        tile_msg = "No tile under the cursor to pick";
        tile_msg_timer = room_speed * 2;
    }
}

// Plane constant: the active plane sits at the offset depth pushed into the scene
var _hit_x = _cx;
var _hit_y = _cy;
var _hit_z = _cz;

if (active_plane == "XY") {
    // XY plane sits at world Z = -depth (negative Z is up here)
    var _plane_z = -plane_offset_XY.depth;
    if (abs(_ray_z) > 0.0001) {
        var _t = (_plane_z - _cz) / _ray_z;
        _hit_x = _cx + _ray_x * _t;
        _hit_y = _cy + _ray_y * _t;
        _hit_z = _plane_z;
    }
    ghost_x = floor(_hit_x) + plane_offset_XY.left_right;
    ghost_y = floor(_hit_y) + plane_offset_XY.up_down;
    // draw_tile_quad_textured draws an XY tile at world Z = -z, so a tile's
    // stored z is up-positive while _plane_z is the plane's world Z. Store the
    // negation or the quad lands mirrored through Z=0 - off the cursor by
    // twice the depth, which is only invisible while depth is still 0.
    ghost_z = round(-_plane_z);
}
if (active_plane == "XZ") {
    // XZ plane sits at world Y = depth
    var _plane_y = plane_offset_XZ.depth;
    if (abs(_ray_y) > 0.0001) {
        var _t = (_plane_y - _cy) / _ray_y;
        _hit_x = _cx + _ray_x * _t;
        _hit_z = _cz + _ray_z * _t;
    }
    ghost_x = floor(_hit_x) + plane_offset_XZ.left_right;
    ghost_y = round(_plane_y);
    ghost_z = floor(_hit_z) + plane_offset_XZ.up_down;
}
if (active_plane == "YZ") {
    // YZ plane sits at world X = depth
    var _plane_x = plane_offset_YZ.depth;
    if (abs(_ray_x) > 0.0001) {
        var _t = (_plane_x - _cx) / _ray_x;
        _hit_y = _cy + _ray_y * _t;
        _hit_z = _cz + _ray_z * _t;
    }
    ghost_x = round(_plane_x);
    ghost_y = floor(_hit_y) + plane_offset_YZ.left_right;
    ghost_z = floor(_hit_z) + plane_offset_YZ.up_down;
}

// Decal sub-cell offset along the active plane normal.
// _toward is the world-axis sign pointing from the plane to the camera, so
// "1" (grid_offset going negative) always lifts the decal TOWARD the camera
// and Tab+1 always pushes it away - on every plane, from either side.
ghost_off_x = 0;
ghost_off_y = 0;
ghost_off_z = 0;
var _off_world = -grid_offset * cm_world;
var _toward = 1;
if (active_plane == "XY") {
    // XY sits at world Z = -ghost_z (negative Z is up)
    if (_cz < -ghost_z) {
        _toward = -1;
    }
    ghost_off_z = _off_world * _toward;
}
if (active_plane == "XZ") {
    if (_cy < ghost_y) {
        _toward = -1;
    }
    ghost_off_y = _off_world * _toward;
}
if (active_plane == "YZ") {
    if (_cx < ghost_x) {
        _toward = -1;
    }
    ghost_off_x = _off_world * _toward;
}

// Sub-tile nudge on the two in-plane axes, on top of the decal offset
brush_nudge_apply();

// --- 5b. CLUSTER SELECT (Ctrl+Shift drag) AND COPY (Ctrl+C) ---
var _sel_mod = (_ctrl && keyboard_check(vk_shift));

if (_sel_mod && mouse_check_button_pressed(mb_left) && !palette_open && !menu_blocks_mouse && !clip_blocks_mouse) {
    sel_dragging = true;
    sel_x0 = window_mouse_get_x();
    sel_y0 = window_mouse_get_y();
    sel_x1 = sel_x0;
    sel_y1 = sel_y0;
}

if (sel_dragging) {
    sel_x1 = window_mouse_get_x();
    sel_y1 = window_mouse_get_y();

    if (mouse_check_button_released(mb_left)) {
        sel_dragging = false;
        sel_keys = clip_select_rect(sel_x0, sel_y0, sel_x1, sel_y1);

        if (array_length(sel_keys) > 0) {
            tile_msg = string(array_length(sel_keys)) + " tiles selected - Ctrl+C to copy";
        }
        else {
            tile_msg = "Nothing in that rectangle";
        }
        tile_msg_timer = room_speed * 3;
    }
}

// The thumbnail is grabbed from the application surface, which holds the frame
// drawn LAST step - so the grid, the yellow selection tint and the ghost have
// to be out of the way a frame before the grab, not at the moment of it.
// Ctrl+C therefore arms a capture, and the grab happens once a clean frame has
// been drawn. Anything turned off for it goes back to how it was afterwards.
if (clip_capture_pending) {
    if (clip_capture_wait > 0) {
        clip_capture_wait -= 1;
    }
    else {
        var _grabbed = clip_grab(clip_capture_keys, clip_capture_rect[0], clip_capture_rect[1], clip_capture_rect[2], clip_capture_rect[3]);

        grid_visible = clip_capture_grid;
        clip_capture_pending = false;
        clip_capture_keys = [];

        if (_grabbed > 0) {
            tile_msg = "Copied " + string(_grabbed) + " tiles - click to place, Esc to put it down";
        }
        else {
            tile_msg = "Nothing copied";
        }
        tile_msg_timer = room_speed * 3;
    }
}

if (_ctrl && keyboard_check_pressed(ord("C")) && array_length(sel_keys) > 0 && !clip_capture_pending) {
    clip_capture_pending = true;
    clip_capture_wait = 1;
    clip_capture_keys = sel_keys;
    clip_capture_rect = [sel_x0, sel_y0, sel_x1, sel_y1];
    clip_capture_grid = grid_visible;

    grid_visible = false;   // put back once the grab is done
    sel_keys = [];          // drops the yellow tint for the capture frame
}

// --- 6. TILE PLACEMENT / REMOVAL ---
var _place_key = string(ghost_x) + "," + string(ghost_y) + "," + string(ghost_z) + "," + active_plane + "," + string(grid_offset);

// Left click places or replaces the whole brush footprint (not while palette
// open). Holding the button keeps painting: each new cell the ghost moves onto
// is stamped, and the whole drag is one undo step.
if (mouse_check_button_pressed(mb_left) && !keyboard_check(vk_alt) && !_sel_mod && !palette_open && !menu_blocks_mouse && !clip_blocks_mouse) {
    if (clip_held >= 0) {
        // A held cluster stamps once per click, centred on the ghost cell
        undo_push_snapshot();
        var _pasted = clip_paste(clip_held, ghost_x, ghost_y, ghost_z);
        tile_msg = "Placed " + string(_pasted.written) + " tiles";
        if (_pasted.cancelled > 0) {
            tile_msg += " - " + string(_pasted.cancelled) + " cancelled out a face pointing the other way";
        }
        tile_msg_timer = room_speed * 3;
    }
    else {
        paint_active = true;
        paint_last_key = "";
        undo_push_snapshot();
    }
}
if (mouse_check_button_released(mb_left)) {
    paint_active = false;
}

// Painting stops the moment the mouse leaves the viewport rules it started under
if (paint_active && (palette_open || menu_blocks_mouse || clip_blocks_mouse || keyboard_check(vk_alt) || clip_held >= 0)) {
    paint_active = false;
}

if (paint_active && _place_key != paint_last_key) {
    paint_last_key = _place_key;

    var _facing = 1;
    if (active_plane == "XY") {
        _facing = (_cz < -ghost_z) ? -1 : 1;
    }
    if (active_plane == "XZ") {
        _facing = (_cy < ghost_y) ? -1 : 1;
    }
    if (active_plane == "YZ") {
        _facing = (_cx < ghost_x) ? 1 : -1;
    }

    var _nrm_x = 0;
    var _nrm_y = 0;
    var _nrm_z = 0;
    if (active_plane == "XY") { _nrm_z = _facing; }
    if (active_plane == "XZ") { _nrm_y = _facing; }
    if (active_plane == "YZ") { _nrm_x = _facing; }

    // Stamp each brush cell, offset from the anchor along the plane's
    // two in-plane axes. Column = first in-plane axis, row = second.
    // When the brush is flipped, read the footprint in reverse along that
    // axis so the whole arrangement mirrors (not just each tile's texture).
    for (var _br = 0; _br < brush_rows; _br++) {
        for (var _bc = 0; _bc < brush_cols; _bc++) {
            // Source cell in the brush array, reversed per active flip
            // Arrangement reversal is relative to the DEFAULT flip state.
            // When the brush is at an odd quarter-turn (90/270), the footprint
            // axes are swapped, so the flip must reverse the perpendicular axis.
            var _arr_flip_x = (ghost_flip_x != FLIP_X_DEFAULT);
            var _arr_flip_y = (ghost_flip_y != FLIP_Y_DEFAULT);

            var _rev_c = _arr_flip_x;
            var _rev_r = _arr_flip_y;
            if (brush_rot == 1 || brush_rot == 3) {
                _rev_c = _arr_flip_y;
                _rev_r = _arr_flip_x;
            }

            var _src_c = _rev_c ? (brush_cols - 1 - _bc) : _bc;
            var _src_r = _rev_r ? (brush_rows - 1 - _br) : _br;
            var _sub_here = brush_subs[_src_r * brush_cols + _src_c];

            var _tx = ghost_x;
            var _ty = ghost_y;
            var _tz = ghost_z;

            // Map brush column/row onto the active plane's in-plane axes.
            // Both axes reversed so brush[0] lands at the anchor corner and
            // the footprint reads the same way as the sheet (was rotated 180).
            // Center the brush on the cursor: shift each cell back by half
            // the brush extent. floor keeps placement on integer grid cells.
            var _ctr_c = floor((brush_cols - 1) / 2);
            var _ctr_r = floor((brush_rows - 1) / 2);

            if (active_plane == "XY") {
                _tx -= (_bc - _ctr_c); // X across (reversed), centered
                _ty -= (_br - _ctr_r); // Y (reversed), centered
            }
            if (active_plane == "XZ") {
                _tx -= (_bc - _ctr_c); // X across (reversed), centered
                _tz += (_br - _ctr_r); // Z (reversed), centered
            }
            if (active_plane == "YZ") {
                _ty -= (_bc - _ctr_c); // Y across (reversed), centered
                _tz += (_br - _ctr_r); // Z (reversed), centered
            }

            var _bkey = string(_tx) + "," + string(_ty) + "," + string(_tz) + "," + active_plane + "," + string(grid_offset);

            variable_struct_set(global.world_tiles, _bkey, {
                x: _tx,
                y: _ty,
                z: _tz,
                plane: active_plane,
                sub: _sub_here,
                rot: ghost_rot,
                facing: _facing,
                nrm_x: _nrm_x,
                nrm_y: _nrm_y,
                nrm_z: _nrm_z,
                flip_x: ghost_flip_x,
                flip_y: ghost_flip_y,
                off_x: ghost_off_x,
                off_y: ghost_off_y,
                off_z: ghost_off_z
            });
        }
    }
}

// Backspace, Delete, or Right Mouse removes the whole brush footprint
// Right mouse erases the same way: press starts a stroke, holding keeps
// erasing every new cell, and the whole drag is one undo step.
if (mouse_check_button_pressed(mb_right) && !menu_blocks_mouse && !clip_blocks_mouse) {
    erase_active = true;
    erase_last_key = "";
    undo_push_snapshot();
}
if (mouse_check_button_released(mb_right)) {
    erase_active = false;
}
if (erase_active && (menu_blocks_mouse || clip_blocks_mouse)) {
    erase_active = false;
}

var _erase_now = false;
if (erase_active && _place_key != erase_last_key) {
    erase_last_key = _place_key;
    _erase_now = true;
}
if (keyboard_check_pressed(vk_delete) || keyboard_check_pressed(vk_backspace)) {
    undo_push_snapshot();
    _erase_now = true;
}

if (_erase_now) {

    for (var _dr = 0; _dr < brush_rows; _dr++) {
        for (var _dc = 0; _dc < brush_cols; _dc++) {
            var _dx = ghost_x;
            var _dy = ghost_y;
            var _dz = ghost_z;

            // Same footprint mapping as placement, centered on the cursor
            var _dctr_c = floor((brush_cols - 1) / 2);
            var _dctr_r = floor((brush_rows - 1) / 2);

            if (active_plane == "XY") {
                _dx -= (_dc - _dctr_c);
                _dy -= (_dr - _dctr_r);
            }
            if (active_plane == "XZ") {
                _dx -= (_dc - _dctr_c);
                _dz += (_dr - _dctr_r);
            }
            if (active_plane == "YZ") {
                _dy -= (_dc - _dctr_c);
                _dz += (_dr - _dctr_r);
            }

            var _dkey = string(_dx) + "," + string(_dy) + "," + string(_dz) + "," + active_plane + "," + string(grid_offset);

            if (variable_struct_exists(global.world_tiles, _dkey)) {
                struct_remove(global.world_tiles, _dkey);
            }
        }
    }
}

// R turns a held cluster a quarter turn about the vertical axis, keeping every
// tile on the grid. Otherwise R is the brush rotate below.
if (keyboard_check_pressed(ord("R")) && !_ctrl && clip_held >= 0) {
    clip_turn(clip_held);
    tile_msg = "Cluster turned 90" + chr(176);
    tile_msg_timer = room_speed * 2;
}
// R always rotates the held brush (and the preview).
// Ctrl+R rotates the tile already placed under the cursor, if there is one.
else if (keyboard_check_pressed(ord("R")) && _ctrl) {
    if (variable_struct_exists(global.world_tiles, _place_key)) {
        undo_push_snapshot();
        var _hovered = variable_struct_get(global.world_tiles, _place_key);
        _hovered.rot = (_hovered.rot + 1) mod 4;
    }
}
else if (keyboard_check_pressed(ord("R")) || menu_action == "rotate") {
    // Rotate the whole brush as a unit: reshape footprint + move tiles
    if (brush_cols > 1 || brush_rows > 1) {
        var _rot_result = brush_rotate_cw(brush_subs, brush_cols, brush_rows);
        brush_subs = _rot_result.subs;
        brush_cols = _rot_result.cols;
        brush_rows = _rot_result.rows;
    }
    brush_rot = (brush_rot + 1) mod 4;
    // Each tile's own texture also turns 90°
    ghost_rot = (ghost_rot + 1) mod 4;
}

// X mirrors a held cluster (along whichever axis reads left-right on screen).
// Otherwise X flips a single tile's texture, as below.
if (keyboard_check_pressed(ord("X")) && clip_held >= 0) {
    clip_mirror_on_screen(clip_held);
    tile_msg = "Cluster mirrored";
    tile_msg_timer = room_speed * 2;
}
else if (keyboard_check_pressed(ord("X")) || menu_action == "flip_x") {
    if (variable_struct_exists(global.world_tiles, _place_key) && menu_action != "flip_x") {
        var _hovered = variable_struct_get(global.world_tiles, _place_key);
        _hovered.flip_x = !_hovered.flip_x;
    } else {
        ghost_flip_x = !ghost_flip_x;
    }
}

// Y flips texture vertically: hovered tile or preview (not while Ctrl held — that's redo)
if ((keyboard_check_pressed(ord("Y")) && !keyboard_check(vk_control)) || menu_action == "flip_y") {
    if (variable_struct_exists(global.world_tiles, _place_key) && menu_action != "flip_y") {
        var _hovered = variable_struct_get(global.world_tiles, _place_key);
        _hovered.flip_y = !_hovered.flip_y;
    } else {
        ghost_flip_y = !ghost_flip_y;
    }
}