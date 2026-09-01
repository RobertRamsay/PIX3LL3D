/// @desc Load an external PNG sheet and slice it into 16x16 frames.
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

    var _cols = _sheet_w div _cell;
    var _rows = _sheet_h div _cell;

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

    // Build a new multi-frame sprite, one frame per 16x16 cell, row-major
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

    surface_free(_surf);
    sprite_delete(_probe);

    if (_new < 0)
    {
        show_debug_message("Tileset import: no frames created.");
        return -1;
    }

    show_debug_message("Tileset import: " + string(_cols * _rows) + " frames from " + _path);
    return _new;
}