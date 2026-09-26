/// @desc DRAW GUI EVENT of obj_editor

// --- POST FX (puts the 3D view on screen; everything below lands on top) ---
if (!pe_open)
{
    postfx_draw_scene();
}

// --- PIXEL EDITOR (full screen, menu bar on top) ---
if (pe_open)
{
    pe_draw();
    tileset_msg_draw();
    about_banner_draw();
    about_draw();
    demo_draw();
    tut_draw();
    shortcuts_draw();
    menu_draw();
    exit;
}

gpu_set_cullmode(cull_noculling);
var _hud_x = 20;
var _hud_y = 20 + menu_bar_h; // sits below the menu bar
draw_set_font(font_pixeldown);
draw_set_halign(fa_left);
draw_set_valign(fa_top);

// The box grows a line to fit the nudge readout while a nudge is dialled in.
// Width stays put: the gradient swatch sits at _hud_x + 128.
var _nudge_text = brush_nudge_text();
var _hud_w = 120;
var _hud_h = 110;
if (_nudge_text != "")
{
    _hud_h = 128;
}

draw_set_color(c_white);
draw_rectangle(_hud_x - 5, _hud_y - 5, _hud_x + _hud_w, _hud_y + _hud_h, false);
draw_set_color(c_black);
draw_rectangle(_hud_x - 5, _hud_y - 5, _hud_x + _hud_w, _hud_y + _hud_h, true);

var _cx2 = _hud_x + 55;
var _cy2 = _hud_y + 55;
var _len = 40;

// Rebuild the view matrix here (Draw GUI has no access to the Draw event's _view)
var _gcx = cam_look_x + dcos(cam_yaw) * dcos(cam_pitch) * cam_dist;
var _gcy = cam_look_y + dsin(cam_yaw) * dcos(cam_pitch) * cam_dist;
var _gcz = cam_look_z - dsin(cam_pitch) * cam_dist;
var _view = matrix_build_lookat(_gcx, _gcy, _gcz, cam_look_x, cam_look_y, cam_look_z, 0, 0, 1);

// Project world axis directions through the real view matrix.
// Transform the origin and each axis tip, then take the view-space delta.
// View-space X -> screen right, view-space Y -> screen up (so negate for screen).
var _o  = matrix_transform_vertex(_view, 0, 0, 0);
var _tx = matrix_transform_vertex(_view, 1, 0, 0);
var _ty = matrix_transform_vertex(_view, 0, 1, 0);
var _tz = matrix_transform_vertex(_view, 0, 0, 1);

var _ax_x =  (_tx[0] - _o[0]) * _len;
var _ax_y = -(_tx[1] - _o[1]) * _len;
var _ay_x =  (_ty[0] - _o[0]) * _len;
var _ay_y = -(_ty[1] - _o[1]) * _len;
var _az_x =  (_tz[0] - _o[0]) * _len;
var _az_y = -(_tz[1] - _o[1]) * _len;

// X axis (Red)
draw_set_color(c_red);
draw_arrow(_cx2, _cy2, _cx2 + _ax_x, _cy2 + _ax_y, 8);
draw_text(_cx2 + _ax_x + 4, _cy2 + _ax_y - 8, "X");

// Y axis (Green)
draw_set_color(c_lime);
draw_arrow(_cx2, _cy2, _cx2 + _ay_x, _cy2 + _ay_y, 8);
draw_text(_cx2 + _ay_x + 4, _cy2 + _ay_y - 8, "Y");

// Z axis (Blue)
draw_set_color(c_blue);
draw_arrow(_cx2, _cy2, _cx2 + _az_x, _cy2 + _az_y, 8);
draw_text(_cx2 + _az_x + 4, _cy2 + _az_y - 8, "Z");

draw_set_color(c_black);
draw_text(_hud_x + 10, _hud_y + 85, "Plane: " + active_plane);

if (_nudge_text != "")
{
    draw_text(_hud_x + 10, _hud_y + 103, _nudge_text);
}

// --- BACKGROUND GRADIENT SWATCH (+ RGB popup when open) ---
bg_ui_draw();

// --- UNSAVED TEXTURE NOTICE ---
if (pe_png_dirty)
{
    gpu_set_tex_filter(true);
    draw_set_colour(c_yellow);
    draw_text(_hud_x, _hud_y + 122, "Texture edits not saved to PNG (Tileset > Pixel editor > Ctrl+S)");
    draw_set_colour(c_white);
    gpu_set_tex_filter(tex_filter_on);
}

// --- TILE PALETTE OVERLAY ---
if (palette_open) {
    var _count = sprite_get_number(global.tile_sprite);
    var _rows = ceil(_count / palette_cols);
    var _pw = palette_cols * (palette_cell + palette_pad) + palette_pad;
    var _ph = _rows * (palette_cell + palette_pad) + palette_pad;

    // Background panel — animated vertical gradient (light grey <-> dark grey)
    var _light = make_color_rgb(180, 180, 180);
    var _dark  = make_color_rgb(50, 50, 50);

    // Blend factor oscillates 0..1 over time
    var _blend = (sin(palette_phase) + 1) * 0.5;

    // Top and bottom colours swap-blend toward each other and back
    var _top_col = merge_color(_light, _dark, _blend);
    var _bot_col = merge_color(_dark, _light, _blend);

    var _px1 = palette_x - palette_pad;
    var _py1 = palette_y - palette_pad;
    var _px2 = palette_x - palette_pad + _pw;
    var _py2 = palette_y - palette_pad + _ph;

    draw_set_alpha(0.9);
    // Corner order: x1y1 (TL), x2y1 (TR), x2y2 (BR), x1y2 (BL)
    draw_rectangle_color(_px1, _py1, _px2, _py2, _top_col, _top_col, _bot_col, _bot_col, false);
    draw_set_alpha(1);

    // Tile art is pixel art: no smoothing, whatever the last draw left on.
    // (The 3D view turns filtering back on for everything after the tiles, and
    // a loaded sheet with a smaller cell is scaled up here, which showed it.)
    var _pal_filter = gpu_get_tex_filter();
    gpu_set_tex_filter(false);

    for (var _i = 0; _i < _count; _i++) {
        var _col = _i mod palette_cols;
        var _row = _i div palette_cols;
        var _cell_x = palette_x + _col * (palette_cell + palette_pad);
        var _cell_y = palette_y + _row * (palette_cell + palette_pad);

        // Tile image scaled into the cell
        var _sw = sprite_get_width(global.tile_sprite);
        var _sh = sprite_get_height(global.tile_sprite);
        var _scale_x = palette_cell / _sw;
        var _scale_y = palette_cell / _sh;
        draw_sprite_ext(global.tile_sprite, _i, _cell_x, _cell_y, _scale_x, _scale_y, 0, c_white, 1);

        // Highlight: hovered (yellow) or active (white)
        if (_i == palette_hover) {
            draw_set_color(c_yellow);
            draw_rectangle(_cell_x, _cell_y, _cell_x + palette_cell, _cell_y + palette_cell, true);
        } else if (_i == active_sub) {
            draw_set_color(c_white);
            draw_rectangle(_cell_x, _cell_y, _cell_x + palette_cell, _cell_y + palette_cell, true);
        }
    }

    gpu_set_tex_filter(_pal_filter);

    // --- DRAG-SELECT HIGHLIGHT (live rectangle while dragging) ---
    if (palette_drag_start >= 0) {
        var _end = (palette_hover >= 0) ? palette_hover : palette_drag_start;

        var _sc = palette_drag_start mod palette_cols;
        var _sr = palette_drag_start div palette_cols;
        var _ec = _end mod palette_cols;
        var _er = _end div palette_cols;

        var _c0 = min(_sc, _ec);
        var _c1 = max(_sc, _ec);
        var _r0 = min(_sr, _er);
        var _r1 = max(_sr, _er);

        var _hx0 = palette_x + _c0 * (palette_cell + palette_pad);
        var _hy0 = palette_y + _r0 * (palette_cell + palette_pad);
        var _hx1 = palette_x + _c1 * (palette_cell + palette_pad) + palette_cell;
        var _hy1 = palette_y + _r1 * (palette_cell + palette_pad) + palette_cell;

        // Translucent fill
        draw_set_alpha(0.3);
        draw_set_color(c_yellow);
        draw_rectangle(_hx0, _hy0, _hx1, _hy1, false);

        // Solid outline
        draw_set_alpha(1);
        draw_set_color(c_yellow);
        draw_rectangle(_hx0, _hy0, _hx1, _hy1, true);

        // Mark the anchor (drag-start) cell so direction is visible
        var _ax = palette_x + _sc * (palette_cell + palette_pad);
        var _ay = palette_y + _sr * (palette_cell + palette_pad);
        draw_set_color(c_white);
        draw_rectangle(_ax, _ay, _ax + palette_cell, _ay + palette_cell, true);
    }

    draw_set_color(c_white);
}

// --- POST FX CONTROL PANEL ---
postfx_panel_draw();

// --- CLUSTER SELECT RUBBER BAND (window pixels -> GUI pixels) ---
if (sel_dragging) {
    var _band_sx = display_get_gui_width() / max(1, window_get_width());
    var _band_sy = display_get_gui_height() / max(1, window_get_height());
    var _bx0 = min(sel_x0, sel_x1) * _band_sx;
    var _bx1 = max(sel_x0, sel_x1) * _band_sx;
    var _by0 = min(sel_y0, sel_y1) * _band_sy;
    var _by1 = max(sel_y0, sel_y1) * _band_sy;

    draw_set_alpha(0.15);
    draw_set_colour(c_yellow);
    draw_rectangle(_bx0, _by0, _bx1, _by1, false);
    draw_set_alpha(1);
    draw_set_colour(c_yellow);
    draw_rectangle(_bx0, _by0, _bx1, _by1, true);
    draw_set_colour(c_white);
}

// --- CLIP STRIP (clusters copied with Ctrl+C) ---
clip_strip_draw();

// --- INVISIBLE-TILE WARNING (with Clean up button) ---
invisible_warn_draw();

// --- WIREFRAME LEGEND ---
if (wire_on) {
    wire_legend_draw();
}

// --- TILESET STATUS (re-slice confirmation) ---
tileset_msg_draw();

// --- UPDATE BANNER (over the viewport, under the menu bar) ---
about_banner_draw();

// --- ABOUT PANEL (modal, over the editor but under the menu bar) ---
about_draw();

// --- PRO PANEL (modal, demo builds only) ---
demo_draw();

// --- GUIDED TOUR (card, sparkles, chapter toast, first-launch question) ---
tut_draw();
tut_prompt_draw();

// --- SHORTCUT KEYS PANEL (modal) ---
shortcuts_draw();

// --- MENU BAR (last, so drop-downs sit over everything) ---
menu_draw();

draw_sprite(spr_logo,0,1920-180,1080-180)