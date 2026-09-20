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

    var _cols = _sheet_w div _use_cell;
    var _rows = _sheet_h div _use_cell;

    // Expose the sheet's grid width so the palette can match it
    global.tile_custom_cols = _cols;

    if (_cols < 1 || _rows < 1)
    {
        show_debug_message("Tileset import: sheet smaller than one cell.");
        sprite_delete(_probe);
        return -1;
    }

    // Render the probe sprite to a surface so we can carve out cells
    var _surf = surface_create(_sheet_w, _sheet_h);
    surface_set_target(_surf);
    draw_clear_alpha(c_black, 0);
    draw_sprite(_probe, 0, 0, 0);
    surface_reset_target();

    // Build a new multi-frame sprite, one frame per cell, row-major
    var _new = -1;
    var _row = 0;
    repeat (_rows)
    {
        var _col = 0;
        repeat (_cols)
        {
            var _cx = _col * _use_cell;
            var _cy = _row * _use_cell;
            if (_new < 0)
            {
                _new = sprite_create_from_surface(_surf, _cx, _cy, _use_cell, _use_cell, false, false, 0, 0);
            }
            else
            {
                sprite_add_from_surface(_new, _surf, _cx, _cy, _use_cell, _use_cell, false, false);
            }
            _col += 1;
        }
        _row += 1;
    }

    surface_free(_surf);
    sprite_delete(_probe);

    if (_new < 0)
    {
        show_debug_message("Tileset import: no frames created.");
        return -1;
    }

    // Everything downstream reads the cell size from here
    global.tile_cell = _use_cell;

    show_debug_message("Tileset import: " + string(_cols * _rows) + " frames at " + string(_use_cell) + "px from " + _path);
    return _new;
}