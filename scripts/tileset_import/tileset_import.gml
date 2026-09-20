/// @desc Pick a cell size for a sheet of this pixel size.
/// 16 is tried first so every sheet that worked before keeps working; then
/// the larger sizes, then 8. A square sheet often divides by several of
/// these, and nothing in the file says which was intended - when the guess
/// is wrong, Tileset > Cell size sets it explicitly and re-imports.
/// Returns 0 when no candidate divides both dimensions cleanly.
function tileset_detect_cell(_sheet_w, _sheet_h)
{
    var _cands = [16, 32, 24, 8];
    for (var _i = 0; _i < array_length(_cands); _i++)
    {
        var _c = _cands[_i];
        if (_sheet_w >= _c && _sheet_h >= _c && (_sheet_w mod _c) == 0 && (_sheet_h mod _c) == 0)
        {
            return _c;
        }
    }
    return 0;
}

/// @desc Carve a surface into square frames of _cell, row-major.
/// Sets global.tile_custom_cols so the palette can match the grid.
/// Returns the new sprite index, or -1 on failure.
function tileset_slice_surface(_surf, _sheet_w, _sheet_h, _cell)
{
    var _cols = _sheet_w div _cell;
    var _rows = _sheet_h div _cell;

    if (_cols < 1 || _rows < 1)
    {
        return -1;
    }

    var _new = -1;
    var _row = 0;
    repeat (_rows)
    {
        var _col = 0;
        repeat (_cols)
        {
            var _cx = _col * _cell;
            var _cy = _row * _cell;
            if (_new < 0)
            {
                _new = sprite_create_from_surface(_surf, _cx, _cy, _cell, _cell, false, false, 0, 0);
            }
            else
            {
                sprite_add_from_surface(_new, _surf, _cx, _cy, _cell, _cell, false, false);
            }
            _col += 1;
        }
        _row += 1;
    }

    if (_new >= 0)
    {
        global.tile_custom_cols = _cols;
        global.tile_cell = _cell;
    }
    return _new;
}

/// @desc Re-slice the sheet that is CURRENTLY active at a new cell size.
/// Works on the built-in set as well as an imported one, and needs no file on
/// disk - it rebuilds the sheet from the live sprite's frames, so anything
/// already applied from the pixel editor is carried over.
/// _cell of 0 detects the size. Returns the new sprite index, or -1.
function tileset_reslice_active(_cell, _cols_now)
{
    var _spr = global.tile_sprite;
    if (!sprite_exists(_spr))
    {
        return -1;
    }

    var _src_cell = sprite_get_width(_spr);
    var _count = sprite_get_number(_spr);
    var _cols = max(1, min(_cols_now, _count));
    var _rows = ceil(_count / _cols);
    var _w = _cols * _src_cell;
    var _h = _rows * _src_cell;

    var _use = _cell;
    if (_use <= 0)
    {
        _use = tileset_detect_cell(_w, _h);
    }
    if (_use <= 0)
    {
        return -1;
    }

    // Rebuild the whole sheet from the frames, then carve it up again
    var _surf = surface_create(_w, _h);
    surface_set_target(_surf);
    draw_clear_alpha(c_black, 0);
    gpu_set_blendenable(false);
    gpu_set_alphatestenable(false);
    gpu_set_tex_filter(false);
    var _xo = sprite_get_xoffset(_spr);
    var _yo = sprite_get_yoffset(_spr);
    for (var _i = 0; _i < _count; _i++)
    {
        draw_sprite(_spr, _i, (_i mod _cols) * _src_cell + _xo, (_i div _cols) * _src_cell + _yo);
    }
    gpu_set_blendenable(true);
    gpu_set_alphatestenable(true);
    surface_reset_target();

    var _new = tileset_slice_surface(_surf, _w, _h, _use);
    surface_free(_surf);
    return _new;
}

/// @desc Load an external PNG sheet and slice it into square frames.
/// _cell is the cell size in pixels, or 0 to detect it from the sheet.
/// Sets global.tile_cell to whatever was actually used, so the nudge step,
/// the pixel editor and the scene file all agree with the sprite.
/// Returns the new sprite index, or -1 on failure.
function tileset_import(_path, _cell)
{
    if (!file_exists(_path))
    {
        show_debug_message("Tileset import: file not found - " + _path);
        return -1;
    }

    // Load the whole sheet as a single-frame sprite to measure it
    var _probe = sprite_add(_path, 1, false, false, 0, 0);
    if (_probe < 0)
    {
        show_debug_message("Tileset import: sprite_add failed - " + _path);
        return -1;
    }

    var _sheet_w = sprite_get_width(_probe);
    var _sheet_h = sprite_get_height(_probe);

    // 0 means "work it out from the sheet"
    var _use_cell = _cell;
    if (_use_cell <= 0)
    {
        _use_cell = tileset_detect_cell(_sheet_w, _sheet_h);
        if (_use_cell <= 0)
        {
            show_debug_message("Tileset import: cannot fit 8, 16, 24 or 32 px cells into " + string(_sheet_w) + "x" + string(_sheet_h) + " - set the size in Tileset > Cell size.");
            sprite_delete(_probe);
            return -1;
        }
    }

    // Render the probe sprite to a surface so we can carve out cells
    var _surf = surface_create(_sheet_w, _sheet_h);
    surface_set_target(_surf);
    draw_clear_alpha(c_black, 0);
    draw_sprite(_probe, 0, 0, 0);
    surface_reset_target();

    var _new = tileset_slice_surface(_surf, _sheet_w, _sheet_h, _use_cell);

    surface_free(_surf);
    sprite_delete(_probe);

    if (_new < 0)
    {
        show_debug_message("Tileset import: no frames created.");
        return -1;
    }

    show_debug_message("Tileset import: " + string(sprite_get_number(_new)) + " frames at " + string(_use_cell) + "px from " + _path);
    return _new;
}
/// @desc Draw the short-lived tileset status line, centred low on screen.
/// Called from Draw GUI in both editors, so a re-slice always says what it did
/// (or why it could not) instead of appearing to do nothing.
function tileset_msg_draw()
{
    if (tile_msg_timer <= 0)
    {
        return;
    }
    if (tile_msg == "")
    {
        return;
    }

    var _gw = display_get_gui_width();
    var _gh = display_get_gui_height();

    gpu_set_tex_filter(true);
    draw_set_font(-1);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);

    var _w = string_width(tile_msg) + 36;
    var _h = 34;
    var _x = floor((_gw - _w) * 0.5);
    var _y = _gh - 120;

    // Fade out over the last half second
    var _a = 1;
    if (tile_msg_timer < room_speed * 0.5)
    {
        _a = tile_msg_timer / (room_speed * 0.5);
    }

    draw_set_alpha(0.88 * _a);
    draw_set_colour(menu_col_panel);
    draw_rectangle(_x, _y, _x + _w, _y + _h, false);
    draw_set_alpha(_a);
    draw_set_colour(menu_col_accent);
    draw_rectangle(_x, _y, _x + _w, _y + _h, true);

    draw_set_colour(c_white);
    draw_text(_x + _w * 0.5, _y + _h * 0.5, tile_msg);

    draw_set_alpha(1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_colour(c_white);
    gpu_set_tex_filter(tex_filter_on);
}
