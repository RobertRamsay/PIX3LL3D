/// PIXEL_editor
/// Full-screen pixel editor for the active tileset sheet.
///
/// The sheet is held in a CPU buffer (pe_buf, 4 bytes per pixel, read and
/// written as u32 = (alpha << 24) | colour). All painting happens on that
/// buffer; pe_surf is only a display copy, rebuilt from the buffer when stale
/// or lost. "Apply" slices the sheet back into a multi-frame sprite and makes
/// it the custom tileset (same frame order and columns, so every placed tile
/// keeps its sub index).

// ============================================================
//  OPEN / CLOSE / APPLY / SAVE
// ============================================================

/// @desc Copy the active tileset into an editable sheet and open the editor.
function pe_open_editor()
{
    var _spr = global.tile_sprite;
    if (!sprite_exists(_spr))
    {
        return;
    }

    pe_cell = sprite_get_width(_spr);
    pe_frame_count = sprite_get_number(_spr);
    pe_cols = max(1, min(palette_cols, pe_frame_count));
    pe_rows = ceil(pe_frame_count / pe_cols);
    pe_w = pe_cols * pe_cell;
    pe_h = pe_rows * pe_cell;
    pe_buf_size = pe_w * pe_h * 4;

    // Render every frame into one sheet, copying RGBA exactly (no blending)
    if (surface_exists(pe_surf))
    {
        surface_free(pe_surf);
    }
    pe_surf = surface_create(pe_w, pe_h);
    surface_set_target(pe_surf);
    draw_clear_alpha(c_black, 0);
    gpu_set_blendenable(false);
    gpu_set_alphatestenable(false);
    gpu_set_tex_filter(false);
    var _xo = sprite_get_xoffset(_spr);
    var _yo = sprite_get_yoffset(_spr);
    for (var _i = 0; _i < pe_frame_count; _i++)
    {
        var _fx = (_i mod pe_cols) * pe_cell;
        var _fy = (_i div pe_cols) * pe_cell;
        draw_sprite(_spr, _i, _fx + _xo, _fy + _yo);
    }
    gpu_set_blendenable(true);
    gpu_set_alphatestenable(true);
    gpu_set_tex_filter(tex_filter_on);
    surface_reset_target();

    if (buffer_exists(pe_buf))
    {
        buffer_delete(pe_buf);
    }
    pe_buf = buffer_create(pe_buf_size, buffer_fixed, 1);
    buffer_get_surface(pe_buf, pe_surf, 0);

    // Drawing into a surface from the Step event can come out mirrored
    // (the room camera still holds the 3D view/projection the Draw event set).
    // Measure how it lands right now and undo it, so the sheet is always upright.
    var _orient = pe_surface_orientation();
    if (_orient[1])
    {
        pe_flip_buffer_region(pe_buf, pe_w, 0, 0, pe_w, pe_h, false);
    }
    if (_orient[0])
    {
        pe_flip_buffer_region(pe_buf, pe_w, 0, 0, pe_w, pe_h, true);
    }
    pe_surf_stale = true;

    // Undo depth scales with sheet size (roughly 64 MB of snapshots max)
    pe_undo_clear();
    pe_undo_max = clamp(floor(67108864 / max(1, pe_buf_size)), 5, 100);

    // Fresh interaction state
    pe_sel_active = false;
    pe_sel_mode = "";
    pe_float_discard();
    pe_stroking = false;
    pe_picking = false;
    pe_panning = false;
    pe_drag_ui = "";

    pe_png_path = "";
    if (global.tile_is_custom)
    {
        pe_png_path = global.tile_custom_path;
    }
    pe_dirty = false;

    // Release anything the 3D view was holding
    palette_open = false;
    palette_drag_start = -1;
    cam_dragging = false;
    cam_panning = false;
    window_set_cursor(cr_default);

    pe_open = true;
    pe_layout();
    pe_fit_view();
    pe_notify("Editing tileset: " + string(pe_frame_count) + " tiles, " + string(pe_cell) + "px cells");
}

/// @desc Draw a mark in the top-left of a small surface and see where it lands.
/// Returns [flip_x, flip_y] for surface drawing in the current matrix state.
function pe_surface_orientation()
{
    var _s = surface_create(4, 4);
    surface_set_target(_s);
    draw_clear_alpha(c_black, 0);
    gpu_set_blendenable(false);
    gpu_set_alphatestenable(false);
    draw_set_colour(c_white);
    draw_set_alpha(1);
    draw_rectangle(0, 0, 1, 1, false); // top-left quadrant only
    gpu_set_blendenable(true);
    gpu_set_alphatestenable(true);
    surface_reset_target();

    var _b = buffer_create(4 * 4 * 4, buffer_fixed, 1);
    buffer_get_surface(_b, _s, 0);
    var _tl = (buffer_peek(_b, (0 * 4 + 0) * 4, buffer_u32) >> 24) & 255;
    var _tr = (buffer_peek(_b, (0 * 4 + 3) * 4, buffer_u32) >> 24) & 255;
    var _bl = (buffer_peek(_b, (3 * 4 + 0) * 4, buffer_u32) >> 24) & 255;
    var _br = (buffer_peek(_b, (3 * 4 + 3) * 4, buffer_u32) >> 24) & 255;
    buffer_delete(_b);
    surface_free(_s);

    var _flip_x = false;
    var _flip_y = false;
    if (_tl == 0)
    {
        if (_tr > 0)
        {
            _flip_x = true;
        }
        else if (_bl > 0)
        {
            _flip_y = true;
        }
        else if (_br > 0)
        {
            _flip_x = true;
            _flip_y = true;
        }
    }
    if (_flip_x || _flip_y)
    {
        show_debug_message("Pixel editor: surface draw was flipped (x=" + string(_flip_x) + ", y=" + string(_flip_y) + "), corrected.");
    }
    return [_flip_x, _flip_y];
}

/// @desc Commit, apply to tiles if edited, free resources and return to 3D.
function pe_close_editor()
{
    pe_float_commit();
    if (pe_dirty)
    {
        pe_apply();
    }
    pe_undo_clear();

    if (buffer_exists(pe_buf))
    {
        buffer_delete(pe_buf);
    }
    pe_buf = -1;
    if (surface_exists(pe_surf))
    {
        surface_free(pe_surf);
    }
    pe_surf = -1;
    if (surface_exists(pe_checker_surf))
    {
        surface_free(pe_checker_surf);
    }
    pe_checker_surf = -1;

    pe_sel_active = false;
    pe_stroking = false;
    pe_open = false;
}

/// @desc Slice the sheet back into frames and make it the active custom set.
function pe_apply()
{
    pe_float_commit();
    pe_sync_surface();

    var _new = -1;
    for (var _i = 0; _i < pe_frame_count; _i++)
    {
        var _fx = (_i mod pe_cols) * pe_cell;
        var _fy = (_i div pe_cols) * pe_cell;
        if (_new < 0)
        {
            _new = sprite_create_from_surface(pe_surf, _fx, _fy, pe_cell, pe_cell, false, false, 0, 0);
        }
        else
        {
            sprite_add_from_surface(_new, pe_surf, _fx, _fy, pe_cell, pe_cell, false, false);
        }
    }

    if (_new < 0)
    {
        pe_notify("Apply failed: no frames created");
        return;
    }

    if (global.tile_custom >= 0 && sprite_exists(global.tile_custom))
    {
        sprite_delete(global.tile_custom);
    }
    global.tile_custom = _new;
    global.tile_sprite = _new;
    global.tile_is_custom = true;
    global.tile_custom_cols = pe_cols;
    palette_cols = pe_cols;

    pe_dirty = false;
    pe_notify("Applied to tiles");
}

/// @desc Save the sheet as a PNG. Asks for a path if none yet or _ask is true.
function pe_save_png(_ask)
{
    pe_float_commit();

    var _path = pe_png_path;
    if (_ask || _path == "")
    {
        _path = get_save_filename_safe("PNG image (*.png)|*.png", "tileset.png");
    }
    if (_path == "")
    {
        return;
    }

    pe_sync_surface();
    surface_save(pe_surf, _path);

    // The saved PNG becomes the custom tileset's source, so scene saves
    // record it and scene loads re-import the edited art.
    if (pe_dirty)
    {
        pe_apply();
    }
    pe_png_path = _path;
    global.tile_custom_path = _path;
    pe_png_dirty = false;
    pe_notify("Saved " + filename_name(_path));
}

// ============================================================
//  PIXEL / COLOUR HELPERS
// ============================================================

/// @desc Pack a GML colour + alpha (0..255) into the buffer's u32 layout.
function pe_u32(_col, _alpha)
{
    return ((floor(_alpha) & 255) << 24) | (_col & $FFFFFF);
}

function pe_u32_col(_u)
{
    return _u & $FFFFFF;
}

function pe_u32_alpha(_u)
{
    return (_u >> 24) & 255;
}

/// @desc Read a sheet pixel (caller guarantees it is inside the sheet).
function pe_get(_x, _y)
{
    return buffer_peek(pe_buf, (_y * pe_w + _x) * 4, buffer_u32);
}

/// @desc Mark the sheet as changed.
function pe_touched()
{
    pe_dirty = true;
    pe_png_dirty = true;
    pe_surf_stale = true;
}

/// @desc Rebuild the display surface from the buffer if needed.
function pe_sync_surface()
{
    if (!surface_exists(pe_surf))
    {
        pe_surf = surface_create(pe_w, pe_h);
        pe_surf_stale = true;
    }
    if (pe_surf_stale)
    {
        buffer_set_surface(pe_buf, pe_surf, 0);
        pe_surf_stale = false;
    }
}

/// @desc Set the primary colour and keep the HSV picker in step.
function pe_set_primary(_col, _alpha)
{
    pe_col = _col;
    pe_alpha = _alpha;
    pe_hue = colour_get_hue(_col);
    pe_sat = colour_get_saturation(_col);
    pe_val = colour_get_value(_col);
}

function pe_set_secondary(_col, _alpha)
{
    pe_col2 = _col;
    pe_alpha2 = _alpha;
}

function pe_swap_colours()
{
    var _c = pe_col;
    var _a = pe_alpha;
    pe_set_primary(pe_col2, pe_alpha2);
    pe_set_secondary(_c, _a);
}

function pe_hex_byte(_n)
{
    var _d = "0123456789ABCDEF";
    return string_char_at(_d, (_n div 16) + 1) + string_char_at(_d, (_n mod 16) + 1);
}

function pe_colour_hex(_col)
{
    return "#" + pe_hex_byte(colour_get_red(_col)) + pe_hex_byte(colour_get_green(_col)) + pe_hex_byte(colour_get_blue(_col));
}

/// @desc Show a short message in the status bar.
function pe_notify(_text)
{
    pe_message = _text;
    pe_message_timer = 180;
}

// ============================================================
//  PAINT LIMITS (selection / tile clip)
// ============================================================

/// @desc Work out where an operation starting at (_px,_py) may paint.
function pe_begin_limits(_px, _py)
{
    pe_lim_x0 = 0;
    pe_lim_y0 = 0;
    pe_lim_x1 = pe_w;
    pe_lim_y1 = pe_h;

    if (pe_sel_active)
    {
        pe_lim_x0 = max(pe_lim_x0, pe_sel_x0);
        pe_lim_y0 = max(pe_lim_y0, pe_sel_y0);
        pe_lim_x1 = min(pe_lim_x1, pe_sel_x1);
        pe_lim_y1 = min(pe_lim_y1, pe_sel_y1);
    }

    if (pe_tile_clip)
    {
        var _cx = floor(_px / pe_cell) * pe_cell;
        var _cy = floor(_py / pe_cell) * pe_cell;
        pe_lim_x0 = max(pe_lim_x0, _cx);
        pe_lim_y0 = max(pe_lim_y0, _cy);
        pe_lim_x1 = min(pe_lim_x1, _cx + pe_cell);
        pe_lim_y1 = min(pe_lim_y1, _cy + pe_cell);
    }
}

// ============================================================
//  SHAPES (all shapes are lists of [x_start, x_end, y] spans, inclusive)
// ============================================================

/// @desc Build spans for a shape between two sheet pixels.
function pe_shape_spans(_shape, _x0, _y0, _x1, _y1)
{
    var _spans = [];

    if (_shape == "line")
    {
        // Bresenham, stamping a square brush at every point
        var _s = pe_brush;
        var _half = floor((_s - 1) / 2);
        var _dx = abs(_x1 - _x0);
        var _dy = -abs(_y1 - _y0);
        var _sx = 1;
        if (_x0 > _x1)
        {
            _sx = -1;
        }
        var _sy = 1;
        if (_y0 > _y1)
        {
            _sy = -1;
        }
        var _err = _dx + _dy;
        var _x = _x0;
        var _y = _y0;
        while (true)
        {
            for (var _r = 0; _r < _s; _r++)
            {
                array_push(_spans, [_x - _half, _x - _half + _s - 1, _y - _half + _r]);
            }
            if (_x == _x1 && _y == _y1)
            {
                break;
            }
            var _e2 = 2 * _err;
            if (_e2 >= _dy)
            {
                _err += _dy;
                _x += _sx;
            }
            if (_e2 <= _dx)
            {
                _err += _dx;
                _y += _sy;
            }
        }
        return _spans;
    }

    var _l = min(_x0, _x1);
    var _r2 = max(_x0, _x1);
    var _t = min(_y0, _y1);
    var _b = max(_y0, _y1);

    if (_shape == "rect_fill")
    {
        for (var _yy = _t; _yy <= _b; _yy++)
        {
            array_push(_spans, [_l, _r2, _yy]);
        }
        return _spans;
    }

    if (_shape == "rect")
    {
        array_push(_spans, [_l, _r2, _t]);
        if (_b != _t)
        {
            array_push(_spans, [_l, _r2, _b]);
        }
        for (var _yy = _t + 1; _yy < _b; _yy++)
        {
            array_push(_spans, [_l, _l, _yy]);
            if (_r2 != _l)
            {
                array_push(_spans, [_r2, _r2, _yy]);
            }
        }
        return _spans;
    }

    if (_shape == "ellipse" || _shape == "ellipse_fill")
    {
        // Filled extent per row, sampled at pixel centres
        var _h = _b - _t + 1;
        var _row_l = array_create(_h, 0);
        var _row_r = array_create(_h, 0);
        var _a = (_r2 - _l + 1) / 2;
        var _bb = _h / 2;
        var _cx = _l + _a;
        var _cy = _t + _bb;
        for (var _i = 0; _i < _h; _i++)
        {
            var _yc = _t + _i + 0.5;
            var _dn = (_yc - _cy) / _bb;
            var _k = 1 - _dn * _dn;
            if (_k < 0)
            {
                _k = 0;
            }
            var _hw = _a * sqrt(_k);
            var _xs = round(_cx - _hw);
            var _xe = round(_cx + _hw) - 1;
            if (_xe < _xs)
            {
                _xs = floor(_cx);
                _xe = _xs;
            }
            _row_l[_i] = max(_xs, _l);
            _row_r[_i] = min(_xe, _r2);
        }

        if (_shape == "ellipse_fill")
        {
            for (var _i = 0; _i < _h; _i++)
            {
                array_push(_spans, [_row_l[_i], _row_r[_i], _t + _i]);
            }
            return _spans;
        }

        // Outline = filled pixels with a 4-neighbour outside the fill
        for (var _i = 0; _i < _h; _i++)
        {
            var _run_start = -1;
            for (var _xx = _row_l[_i]; _xx <= _row_r[_i] + 1; _xx++)
            {
                var _edge = false;
                if (_xx <= _row_r[_i])
                {
                    if (_xx == _row_l[_i] || _xx == _row_r[_i] || _i == 0 || _i == _h - 1)
                    {
                        _edge = true;
                    }
                    else
                    {
                        if (_xx < _row_l[_i - 1] || _xx > _row_r[_i - 1])
                        {
                            _edge = true;
                        }
                        if (_xx < _row_l[_i + 1] || _xx > _row_r[_i + 1])
                        {
                            _edge = true;
                        }
                    }
                }
                if (_edge)
                {
                    if (_run_start < 0)
                    {
                        _run_start = _xx;
                    }
                }
                else
                {
                    if (_run_start >= 0)
                    {
                        array_push(_spans, [_run_start, _xx - 1, _t + _i]);
                        _run_start = -1;
                    }
                }
            }
        }
        return _spans;
    }

    return _spans;
}

/// @desc Write spans into the sheet, clipped to the current limits.
function pe_write_spans(_spans, _u32)
{
    var _any = false;
    for (var _i = 0; _i < array_length(_spans); _i++)
    {
        var _sp = _spans[_i];
        var _y = _sp[2];
        if (_y < pe_lim_y0 || _y >= pe_lim_y1)
        {
            continue;
        }
        var _xa = max(_sp[0], pe_lim_x0);
        var _xb = min(_sp[1], pe_lim_x1 - 1);
        if (_xb < _xa)
        {
            continue;
        }
        buffer_fill(pe_buf, (_y * pe_w + _xa) * 4, buffer_u32, _u32, (_xb - _xa + 1) * 4);
        _any = true;
    }
    if (_any)
    {
        pe_touched();
    }
}

/// @desc Scanline flood fill (4-connected, exact colour match) inside the limits.
function pe_flood_fill(_x, _y, _u32)
{
    if (_x < pe_lim_x0 || _x >= pe_lim_x1 || _y < pe_lim_y0 || _y >= pe_lim_y1)
    {
        return;
    }
    var _target = pe_get(_x, _y);
    if (_target == _u32)
    {
        return;
    }

    var _stack = [_x, _y];
    while (array_length(_stack) > 0)
    {
        var _sy = array_pop(_stack);
        var _sx = array_pop(_stack);
        if (pe_get(_sx, _sy) != _target)
        {
            continue;
        }

        var _left = _sx;
        while (_left - 1 >= pe_lim_x0 && pe_get(_left - 1, _sy) == _target)
        {
            _left -= 1;
        }
        var _right = _sx;
        while (_right + 1 < pe_lim_x1 && pe_get(_right + 1, _sy) == _target)
        {
            _right += 1;
        }
        buffer_fill(pe_buf, (_sy * pe_w + _left) * 4, buffer_u32, _u32, (_right - _left + 1) * 4);

        for (var _dir = -1; _dir <= 1; _dir += 2)
        {
            var _ny = _sy + _dir;
            if (_ny < pe_lim_y0 || _ny >= pe_lim_y1)
            {
                continue;
            }
            var _inside = false;
            for (var _xx = _left; _xx <= _right; _xx++)
            {
                if (pe_get(_xx, _ny) == _target)
                {
                    if (!_inside)
                    {
                        array_push(_stack, _xx, _ny);
                        _inside = true;
                    }
                }
                else
                {
                    _inside = false;
                }
            }
        }
    }
    pe_touched();
}

/// @desc Replace every pixel of one colour with another inside the limits.
function pe_replace_colour(_from, _to)
{
    if (_from == _to)
    {
        return;
    }
    var _count = 0;
    for (var _y = pe_lim_y0; _y < pe_lim_y1; _y++)
    {
        for (var _x = pe_lim_x0; _x < pe_lim_x1; _x++)
        {
            var _o = (_y * pe_w + _x) * 4;
            if (buffer_peek(pe_buf, _o, buffer_u32) == _from)
            {
                buffer_poke(pe_buf, _o, buffer_u32, _to);
                _count += 1;
            }
        }
    }
    if (_count > 0)
    {
        pe_touched();
    }
    pe_notify("Replaced " + string(_count) + " pixels");
}

/// @desc Pick the colour under a sheet pixel into primary (LMB) or secondary.
function pe_pick(_px, _py, _btn)
{
    if (_px < 0 || _py < 0 || _px >= pe_w || _py >= pe_h)
    {
        return;
    }
    var _u = pe_get(_px, _py);
    if (_btn == mb_left)
    {
        pe_set_primary(pe_u32_col(_u), pe_u32_alpha(_u));
    }
    else
    {
        pe_set_secondary(pe_u32_col(_u), pe_u32_alpha(_u));
    }
}

// ============================================================
//  UNDO / REDO (whole-sheet snapshots)
// ============================================================

function pe_snapshot()
{
    var _b = buffer_create(pe_buf_size, buffer_fixed, 1);
    buffer_copy(pe_buf, 0, pe_buf_size, _b, 0);
    return _b;
}

function pe_undo_push()
{
    array_push(pe_undo, pe_snapshot());
    while (array_length(pe_undo) > pe_undo_max)
    {
        buffer_delete(pe_undo[0]);
        array_delete(pe_undo, 0, 1);
    }
    for (var _i = 0; _i < array_length(pe_redo); _i++)
    {
        buffer_delete(pe_redo[_i]);
    }
    pe_redo = [];
}

function pe_undo_perform()
{
    pe_float_commit();
    if (array_length(pe_undo) == 0)
    {
        pe_notify("Nothing to undo");
        return;
    }
    array_push(pe_redo, pe_snapshot());
    var _snap = array_pop(pe_undo);
    buffer_copy(_snap, 0, pe_buf_size, pe_buf, 0);
    buffer_delete(_snap);
    pe_touched();
}

function pe_redo_perform()
{
    pe_float_commit();
    if (array_length(pe_redo) == 0)
    {
        pe_notify("Nothing to redo");
        return;
    }
    array_push(pe_undo, pe_snapshot());
    var _snap = array_pop(pe_redo);
    buffer_copy(_snap, 0, pe_buf_size, pe_buf, 0);
    buffer_delete(_snap);
    pe_touched();
}

function pe_undo_clear()
{
    for (var _i = 0; _i < array_length(pe_undo); _i++)
    {
        buffer_delete(pe_undo[_i]);
    }
    for (var _j = 0; _j < array_length(pe_redo); _j++)
    {
        buffer_delete(pe_redo[_j]);
    }
    pe_undo = [];
    pe_redo = [];
}

// ============================================================
//  SELECTION / FLOATING PIXELS / CLIPBOARD
// ============================================================

/// @desc Copy a sheet region into a new buffer (region must be inside the sheet).
function pe_region_to_buffer(_x0, _y0, _w, _h)
{
    var _b = buffer_create(_w * _h * 4, buffer_fixed, 1);
    for (var _r = 0; _r < _h; _r++)
    {
        buffer_copy(pe_buf, ((_y0 + _r) * pe_w + _x0) * 4, _w * 4, _b, _r * _w * 4);
    }
    return _b;
}

/// @desc Clear a sheet region to transparent.
function pe_clear_region(_x0, _y0, _w, _h)
{
    for (var _r = 0; _r < _h; _r++)
    {
        buffer_fill(pe_buf, ((_y0 + _r) * pe_w + _x0) * 4, buffer_u32, 0, _w * 4);
    }
    pe_touched();
}

/// @desc Lift the selection into floating pixels (leaves a hole behind).
function pe_float_lift()
{
    var _w = pe_sel_x1 - pe_sel_x0;
    var _h = pe_sel_y1 - pe_sel_y0;
    if (_w <= 0 || _h <= 0)
    {
        return;
    }
    pe_undo_push();
    pe_float_discard();
    pe_float_buf = pe_region_to_buffer(pe_sel_x0, pe_sel_y0, _w, _h);
    pe_float_w = _w;
    pe_float_h = _h;
    pe_float_x = pe_sel_x0;
    pe_float_y = pe_sel_y0;
    pe_float_active = true;
    pe_float_stale = true;
    pe_clear_region(pe_sel_x0, pe_sel_y0, _w, _h);
}

/// @desc Stamp floating pixels into the sheet (transparent pixels are skipped).
function pe_float_commit()
{
    if (!pe_float_active)
    {
        return;
    }
    for (var _r = 0; _r < pe_float_h; _r++)
    {
        var _ty = pe_float_y + _r;
        if (_ty < 0 || _ty >= pe_h)
        {
            continue;
        }
        for (var _c = 0; _c < pe_float_w; _c++)
        {
            var _tx = pe_float_x + _c;
            if (_tx < 0 || _tx >= pe_w)
            {
                continue;
            }
            var _u = buffer_peek(pe_float_buf, (_r * pe_float_w + _c) * 4, buffer_u32);
            if (pe_u32_alpha(_u) > 0)
            {
                buffer_poke(pe_buf, (_ty * pe_w + _tx) * 4, buffer_u32, _u);
            }
        }
    }
    pe_touched();
    pe_sel_from_float();
    pe_float_discard();
}

/// @desc Drop the floating pixels without stamping them.
function pe_float_discard()
{
    if (buffer_exists(pe_float_buf))
    {
        buffer_delete(pe_float_buf);
    }
    pe_float_buf = -1;
    if (surface_exists(pe_float_surf))
    {
        surface_free(pe_float_surf);
    }
    pe_float_surf = -1;
    pe_float_active = false;
}

/// @desc Make the selection match the floating pixels (clipped to the sheet).
function pe_sel_from_float()
{
    pe_sel_x0 = clamp(pe_float_x, 0, pe_w);
    pe_sel_y0 = clamp(pe_float_y, 0, pe_h);
    pe_sel_x1 = clamp(pe_float_x + pe_float_w, 0, pe_w);
    pe_sel_y1 = clamp(pe_float_y + pe_float_h, 0, pe_h);
    pe_sel_active = (pe_sel_x1 > pe_sel_x0 && pe_sel_y1 > pe_sel_y0);
}

function pe_clipboard_store(_src, _w, _h)
{
    if (buffer_exists(pe_clip_buf))
    {
        buffer_delete(pe_clip_buf);
    }
    pe_clip_buf = buffer_create(_w * _h * 4, buffer_fixed, 1);
    buffer_copy(_src, 0, _w * _h * 4, pe_clip_buf, 0);
    pe_clip_w = _w;
    pe_clip_h = _h;
}

function pe_copy()
{
    if (pe_float_active)
    {
        pe_clipboard_store(pe_float_buf, pe_float_w, pe_float_h);
        pe_notify("Copied " + string(pe_float_w) + "x" + string(pe_float_h));
        return true;
    }
    if (pe_sel_active)
    {
        var _w = pe_sel_x1 - pe_sel_x0;
        var _h = pe_sel_y1 - pe_sel_y0;
        var _tmp = pe_region_to_buffer(pe_sel_x0, pe_sel_y0, _w, _h);
        pe_clipboard_store(_tmp, _w, _h);
        buffer_delete(_tmp);
        pe_notify("Copied " + string(_w) + "x" + string(_h));
        return true;
    }
    pe_notify("Nothing selected");
    return false;
}

function pe_delete_selection()
{
    if (pe_float_active)
    {
        pe_float_discard(); // hole was already cleared (and undoable) at lift
        pe_touched();
        return;
    }
    if (pe_sel_active)
    {
        pe_undo_push();
        pe_clear_region(pe_sel_x0, pe_sel_y0, pe_sel_x1 - pe_sel_x0, pe_sel_y1 - pe_sel_y0);
    }
}

function pe_paste()
{
    if (!buffer_exists(pe_clip_buf))
    {
        pe_notify("Clipboard is empty");
        return;
    }
    pe_float_commit();
    pe_undo_push();

    pe_float_buf = buffer_create(pe_clip_w * pe_clip_h * 4, buffer_fixed, 1);
    buffer_copy(pe_clip_buf, 0, pe_clip_w * pe_clip_h * 4, pe_float_buf, 0);
    pe_float_w = pe_clip_w;
    pe_float_h = pe_clip_h;

    // Paste at the mouse if it is over the sheet, else at the selection / view centre
    if (pe_mouse_in_view && pe_hover_x >= 0 && pe_hover_y >= 0 && pe_hover_x < pe_w && pe_hover_y < pe_h)
    {
        pe_float_x = pe_hover_x;
        pe_float_y = pe_hover_y;
    }
    else if (pe_sel_active)
    {
        pe_float_x = pe_sel_x0;
        pe_float_y = pe_sel_y0;
    }
    else
    {
        pe_float_x = floor(((pe_vx0 + pe_vx1) * 0.5 - pe_view_x) / pe_zoom - pe_float_w * 0.5);
        pe_float_y = floor(((pe_vy0 + pe_vy1) * 0.5 - pe_view_y) / pe_zoom - pe_float_h * 0.5);
    }

    pe_float_active = true;
    pe_float_stale = true;
    pe_tool = "select";
    pe_sel_from_float();
}

/// @desc Mirror a rectangle inside any RGBA buffer of width _bw.
function pe_flip_buffer_region(_buf, _bw, _x0, _y0, _w, _h, _horizontal)
{
    if (_horizontal)
    {
        for (var _r = 0; _r < _h; _r++)
        {
            for (var _c = 0; _c < _w div 2; _c++)
            {
                var _oa = ((_y0 + _r) * _bw + _x0 + _c) * 4;
                var _ob = ((_y0 + _r) * _bw + _x0 + _w - 1 - _c) * 4;
                var _ua = buffer_peek(_buf, _oa, buffer_u32);
                buffer_poke(_buf, _oa, buffer_u32, buffer_peek(_buf, _ob, buffer_u32));
                buffer_poke(_buf, _ob, buffer_u32, _ua);
            }
        }
    }
    else
    {
        for (var _r = 0; _r < _h div 2; _r++)
        {
            for (var _c = 0; _c < _w; _c++)
            {
                var _oa = ((_y0 + _r) * _bw + _x0 + _c) * 4;
                var _ob = ((_y0 + _h - 1 - _r) * _bw + _x0 + _c) * 4;
                var _ua = buffer_peek(_buf, _oa, buffer_u32);
                buffer_poke(_buf, _oa, buffer_u32, buffer_peek(_buf, _ob, buffer_u32));
                buffer_poke(_buf, _ob, buffer_u32, _ua);
            }
        }
    }
}

/// @desc Flip the floating pixels, else the selection, else the tile under the mouse.
function pe_flip(_horizontal)
{
    if (pe_float_active)
    {
        pe_flip_buffer_region(pe_float_buf, pe_float_w, 0, 0, pe_float_w, pe_float_h, _horizontal);
        pe_float_stale = true;
        return;
    }
    if (pe_sel_active)
    {
        pe_undo_push();
        pe_flip_buffer_region(pe_buf, pe_w, pe_sel_x0, pe_sel_y0, pe_sel_x1 - pe_sel_x0, pe_sel_y1 - pe_sel_y0, _horizontal);
        pe_touched();
        return;
    }
    if (pe_hover_x >= 0 && pe_hover_y >= 0 && pe_hover_x < pe_w && pe_hover_y < pe_h)
    {
        var _cx = floor(pe_hover_x / pe_cell) * pe_cell;
        var _cy = floor(pe_hover_y / pe_cell) * pe_cell;
        pe_undo_push();
        pe_flip_buffer_region(pe_buf, pe_w, _cx, _cy, pe_cell, pe_cell, _horizontal);
        pe_touched();
        return;
    }
    pe_notify("Hover a tile or make a selection to flip");
}

// ============================================================
//  VIEW
// ============================================================

/// @desc Zoom one level in (_dir = 1) or out (-1), keeping (_mx,_my) fixed.
function pe_zoom_step(_dir, _mx, _my)
{
    var _idx = 0;
    for (var _i = 0; _i < array_length(pe_zoom_levels); _i++)
    {
        if (pe_zoom_levels[_i] <= pe_zoom)
        {
            _idx = _i;
        }
    }
    _idx = clamp(_idx + _dir, 0, array_length(pe_zoom_levels) - 1);
    var _new = pe_zoom_levels[_idx];
    if (_new == pe_zoom)
    {
        return;
    }
    var _fx = (_mx - pe_view_x) / pe_zoom;
    var _fy = (_my - pe_view_y) / pe_zoom;
    pe_zoom = _new;
    pe_view_x = floor(_mx - _fx * pe_zoom);
    pe_view_y = floor(_my - _fy * pe_zoom);
}

/// @desc Fit the whole sheet; if that is too small, zoom in on the active tile.
function pe_fit_view()
{
    var _vw = pe_vx1 - pe_vx0 - 20;
    var _vh = pe_vy1 - pe_vy0 - 20;
    pe_zoom = pe_zoom_levels[0];
    for (var _i = 0; _i < array_length(pe_zoom_levels); _i++)
    {
        var _z = pe_zoom_levels[_i];
        if (pe_w * _z <= _vw && pe_h * _z <= _vh)
        {
            pe_zoom = _z;
        }
    }

    if (pe_zoom >= 4)
    {
        pe_view_x = floor((pe_vx0 + pe_vx1 - pe_w * pe_zoom) * 0.5);
        pe_view_y = floor((pe_vy0 + pe_vy1 - pe_h * pe_zoom) * 0.5);
        return;
    }

    // Sheet is big: centre the active tile at 8x instead
    pe_zoom = 8;
    var _sub = clamp(active_sub, 0, max(0, pe_frame_count - 1));
    var _tx = (_sub mod pe_cols) * pe_cell + pe_cell * 0.5;
    var _ty = (_sub div pe_cols) * pe_cell + pe_cell * 0.5;
    pe_view_x = floor((pe_vx0 + pe_vx1) * 0.5 - _tx * pe_zoom);
    pe_view_y = floor((pe_vy0 + pe_vy1) * 0.5 - _ty * pe_zoom);
}

// ============================================================
//  ACTIONS (shared by menu, keyboard and on-screen buttons)
// ============================================================

function pe_do_action(_act)
{
    if (_act == "")
    {
        return;
    }

    if (string_copy(_act, 1, 5) == "tool_")
    {
        var _tool = string_delete(_act, 1, 5);
        if (_tool != pe_tool)
        {
            if (pe_tool == "select")
            {
                pe_float_commit();
            }
            pe_tool = _tool;
        }
        pe_stroking = false;
        pe_sel_mode = "";
        return;
    }

    switch (_act)
    {
        case "pe_toggle":
        case "pe_close":
            pe_close_editor();
            break;

        case "pe_escape":
            if (pe_float_active || pe_sel_active)
            {
                pe_float_commit();
                pe_sel_active = false;
            }
            else
            {
                pe_close_editor();
            }
            break;

        case "undo":
            pe_undo_perform();
            break;

        case "redo":
            pe_redo_perform();
            break;

        case "pe_apply":
            pe_apply();
            break;

        case "pe_save_png":
            pe_save_png(false);
            break;

        case "pe_save_png_as":
            pe_save_png(true);
            break;

        case "pe_copy":
            pe_copy();
            break;

        case "pe_cut":
            if (pe_copy())
            {
                pe_delete_selection();
            }
            break;

        case "pe_paste":
            pe_paste();
            break;

        case "pe_delete":
            pe_delete_selection();
            break;

        case "pe_select_all":
            pe_float_commit();
            pe_sel_x0 = 0;
            pe_sel_y0 = 0;
            pe_sel_x1 = pe_w;
            pe_sel_y1 = pe_h;
            pe_sel_active = true;
            pe_tool = "select";
            break;

        case "pe_deselect":
            pe_float_commit();
            pe_sel_active = false;
            break;

        case "pe_flip_h":
            pe_flip(true);
            break;

        case "pe_flip_v":
            pe_flip(false);
            break;

        case "pe_pixel_grid":
            pe_show_pixel_grid = !pe_show_pixel_grid;
            break;

        case "pe_tile_grid":
            pe_show_tile_grid = !pe_show_tile_grid;
            break;

        case "pe_tile_clip":
            pe_tile_clip = !pe_tile_clip;
            break;

        case "pe_swap_colours":
            pe_swap_colours();
            break;

        case "pe_brush_down":
            pe_brush = max(1, pe_brush - 1);
            break;

        case "pe_brush_up":
            pe_brush = min(pe_brush_max, pe_brush + 1);
            break;

        case "pe_zoom_in":
            pe_zoom_step(1, (pe_vx0 + pe_vx1) * 0.5, (pe_vy0 + pe_vy1) * 0.5);
            break;

        case "pe_zoom_out":
            pe_zoom_step(-1, (pe_vx0 + pe_vx1) * 0.5, (pe_vy0 + pe_vy1) * 0.5);
            break;

        case "pe_fit":
            pe_fit_view();
            break;
    }
}

function pe_tool_label(_tool)
{
    for (var _i = 0; _i < array_length(pe_tools); _i++)
    {
        if (pe_tools[_i].act == "tool_" + _tool)
        {
            return pe_tools[_i].label;
        }
    }
    return _tool;
}

// ============================================================
//  LAYOUT
// ============================================================

/// @desc Recompute panel rectangles and on-screen buttons for this frame.
function pe_layout()
{
    draw_set_font(-1);
    var _gw = display_get_gui_width();
    var _gh = display_get_gui_height();

    // Left panel wide enough for the longest "label ... key" pair
    var _need = string_width("Brush size  [ ]");
    for (var _n = 0; _n < array_length(pe_tools); _n++)
    {
        var _pair = string_width(pe_tools[_n].label) + string_width(pe_tools[_n].key) + 40;
        _need = max(_need, _pair);
    }
    pe_tool_w = max(pe_tool_w_min, _need + 12);

    pe_vx0 = pe_tool_w;
    pe_vy0 = menu_bar_h + pe_opt_h;
    pe_vx1 = _gw - pe_panel_w;
    pe_vy1 = _gh - pe_status_h;

    pe_buttons = [];

    // --- Left toolbar ---
    var _y = pe_vy0 + 8;
    for (var _i = 0; _i < array_length(pe_tools); _i++)
    {
        var _t = pe_tools[_i];
        array_push(pe_buttons, { x0: 6, y0: _y, x1: pe_tool_w - 6, y1: _y + 21, label: _t.label, key: _t.key, act: _t.act });
        _y += 24;
    }
    _y += 10;
    pe_brush_label_y = _y;
    _y += 20;
    array_push(pe_buttons, { x0: 6, y0: _y, x1: 36, y1: _y + 21, label: "-", key: "", act: "pe_brush_down" });
    array_push(pe_buttons, { x0: pe_tool_w - 36, y0: _y, x1: pe_tool_w - 6, y1: _y + 21, label: "+", key: "", act: "pe_brush_up" });
    pe_brush_value_y = _y;

    // --- Options bar ---
    var _ox = pe_tool_w + 6;
    var _oy0 = menu_bar_h + 4;
    var _oy1 = menu_bar_h + pe_opt_h - 5;
    var _opts = [
        ["Pixel grid", "pe_pixel_grid"],
        ["Tile grid", "pe_tile_grid"],
        ["Clip to tile", "pe_tile_clip"],
        ["Fit view", "pe_fit"],
        ["Apply to tiles", "pe_apply"],
        ["Save PNG", "pe_save_png"],
        ["Close editor", "pe_close"]
    ];
    for (var _o = 0; _o < array_length(_opts); _o++)
    {
        var _w = string_width(_opts[_o][0]) + 20;
        array_push(pe_buttons, { x0: _ox, y0: _oy0, x1: _ox + _w, y1: _oy1, label: _opts[_o][0], key: "", act: _opts[_o][1] });
        _ox += _w + 6;
    }

    // --- Right panel ---
    var _px = pe_vx1 + 10;
    var _py = pe_vy0 + 10;
    pe_swatch_x = _px;
    pe_swatch_y = _py;
    _py += 66;
    pe_sv_x = _px;
    pe_sv_y = _py;
    pe_sv_size = pe_panel_w - 20;
    _py += pe_sv_size + 8;
    pe_hue_x = _px;
    pe_hue_y = _py;
    pe_bar_w = pe_sv_size;
    _py += pe_bar_h + 8;
    pe_alpha_x = _px;
    pe_alpha_y = _py;
    _py += pe_bar_h + 12;
    pe_pal_x = _px;
    pe_pal_y = _py;
    var _pal_rows = ceil(array_length(pe_palette) / pe_pal_cols);
    _py += _pal_rows * (pe_pal_size + pe_pal_gap) + 10;
    pe_info_y = _py;
}

/// @desc Index of the palette swatch at a GUI point, or -1.
function pe_palette_at(_mx, _my)
{
    for (var _i = 0; _i < array_length(pe_palette); _i++)
    {
        var _sx = pe_pal_x + (_i mod pe_pal_cols) * (pe_pal_size + pe_pal_gap);
        var _sy = pe_pal_y + (_i div pe_pal_cols) * (pe_pal_size + pe_pal_gap);
        if (_mx >= _sx && _mx < _sx + pe_pal_size && _my >= _sy && _my < _sy + pe_pal_size)
        {
            return _i;
        }
    }
    return -1;
}

// ============================================================
//  STEP
// ============================================================

function pe_step()
{
    pe_layout();

    var _mx = device_mouse_x_to_gui(0);
    var _my = device_mouse_y_to_gui(0);
    var _ctrl = keyboard_check(vk_control);
    var _shift = keyboard_check(vk_shift);
    var _alt = keyboard_check(vk_alt);

    if (pe_message_timer > 0)
    {
        pe_message_timer -= 1;
    }

    // --- Menu actions ---
    if (menu_action != "")
    {
        pe_do_action(menu_action);
        if (!pe_open)
        {
            return;
        }
    }

    // --- Keyboard ---
    pe_keyboard(_ctrl, _shift);
    if (!pe_open)
    {
        return;
    }

    // --- Mouse position on the sheet ---
    pe_mouse_in_view = false;
    if (_mx >= pe_vx0 && _mx < pe_vx1 && _my >= pe_vy0 && _my < pe_vy1 && !menu_blocks_mouse)
    {
        pe_mouse_in_view = true;
    }
    pe_hover_x = floor((_mx - pe_view_x) / pe_zoom);
    pe_hover_y = floor((_my - pe_view_y) / pe_zoom);

    // --- Zoom ---
    if (pe_mouse_in_view)
    {
        if (mouse_wheel_up())
        {
            pe_zoom_step(1, _mx, _my);
        }
        if (mouse_wheel_down())
        {
            pe_zoom_step(-1, _mx, _my);
        }
        pe_hover_x = floor((_mx - pe_view_x) / pe_zoom);
        pe_hover_y = floor((_my - pe_view_y) / pe_zoom);
    }

    var _press_l = mouse_check_button_pressed(mb_left);
    var _press_r = mouse_check_button_pressed(mb_right);

    // --- Pan: MMB drag, or Space + LMB drag ---
    if (!pe_panning && pe_mouse_in_view)
    {
        var _start_pan = false;
        if (mouse_check_button_pressed(mb_middle))
        {
            _start_pan = true;
            pe_pan_btn = mb_middle;
        }
        if (_press_l && keyboard_check(vk_space))
        {
            _start_pan = true;
            pe_pan_btn = mb_left;
            _press_l = false; // not a paint click
        }
        if (_start_pan)
        {
            pe_panning = true;
            pe_pan_mx = _mx;
            pe_pan_my = _my;
            pe_pan_vx = pe_view_x;
            pe_pan_vy = pe_view_y;
        }
    }
    if (pe_panning)
    {
        if (mouse_check_button(pe_pan_btn))
        {
            pe_view_x = pe_pan_vx + (_mx - pe_pan_mx);
            pe_view_y = pe_pan_vy + (_my - pe_pan_my);
        }
        else
        {
            pe_panning = false;
        }
        return;
    }

    // --- Clicks on panels / buttons ---
    var _consumed = menu_blocks_mouse;
    if ((_press_l || _press_r) && !_consumed)
    {
        for (var _b = 0; _b < array_length(pe_buttons); _b++)
        {
            var _bt = pe_buttons[_b];
            if (_mx >= _bt.x0 && _mx < _bt.x1 && _my >= _bt.y0 && _my < _bt.y1)
            {
                if (_press_l)
                {
                    pe_do_action(_bt.act);
                }
                _consumed = true;
                break;
            }
        }
        if (!pe_open)
        {
            return;
        }

        if (!_consumed && _mx >= pe_vx1)
        {
            _consumed = true;
            pe_panel_click(_mx, _my, _press_l, _shift);
        }
        if (!_consumed && !pe_mouse_in_view)
        {
            _consumed = true; // toolbar / options bar / status bar background
        }
    }

    // --- Continue dragging a colour control ---
    if (pe_drag_ui != "")
    {
        if (mouse_check_button(mb_left))
        {
            pe_panel_drag(_mx, _my);
        }
        else
        {
            pe_drag_ui = "";
        }
        return;
    }

    // --- Canvas ---
    if ((_press_l || _press_r) && !_consumed && pe_mouse_in_view)
    {
        var _btn = mb_right;
        if (_press_l)
        {
            _btn = mb_left;
        }
        pe_canvas_press(_btn, _alt, _shift);
    }
    pe_canvas_hold();
}

/// @desc Keyboard shortcuts while the pixel editor is open.
function pe_keyboard(_ctrl, _shift)
{
    if (keyboard_check_pressed(vk_escape) && !menu_esc_consumed)
    {
        pe_do_action("pe_escape");
        return;
    }

    if (_ctrl)
    {
        if (keyboard_check_pressed(ord("Z")))
        {
            if (_shift)
            {
                pe_do_action("redo");
            }
            else
            {
                pe_do_action("undo");
            }
        }
        if (keyboard_check_pressed(ord("Y"))) { pe_do_action("redo"); }
        if (keyboard_check_pressed(ord("C"))) { pe_do_action("pe_copy"); }
        if (keyboard_check_pressed(ord("X"))) { pe_do_action("pe_cut"); }
        if (keyboard_check_pressed(ord("V"))) { pe_do_action("pe_paste"); }
        if (keyboard_check_pressed(ord("A"))) { pe_do_action("pe_select_all"); }
        if (keyboard_check_pressed(ord("D"))) { pe_do_action("pe_deselect"); }
        if (keyboard_check_pressed(ord("G"))) { pe_do_action("pe_pixel_grid"); }
        if (keyboard_check_pressed(ord("T"))) { pe_do_action("pe_tile_grid"); }
        if (keyboard_check_pressed(ord("S")))
        {
            if (_shift)
            {
                pe_do_action("pe_save_png_as");
            }
            else
            {
                pe_do_action("pe_save_png");
            }
        }
        return;
    }

    if (keyboard_check_pressed(ord("P")))
    {
        pe_do_action("pe_toggle");
        return;
    }
    if (keyboard_check_pressed(vk_enter)) { pe_do_action("pe_apply"); }

    // Tools
    if (keyboard_check_pressed(ord("B"))) { pe_do_action("tool_pencil"); }
    if (keyboard_check_pressed(ord("E"))) { pe_do_action("tool_eraser"); }
    if (keyboard_check_pressed(ord("L"))) { pe_do_action("tool_line"); }
    if (keyboard_check_pressed(ord("I"))) { pe_do_action("tool_picker"); }
    if (keyboard_check_pressed(ord("M"))) { pe_do_action("tool_select"); }
    if (keyboard_check_pressed(ord("G")))
    {
        if (_shift)
        {
            pe_do_action("tool_replace");
        }
        else
        {
            pe_do_action("tool_fill");
        }
    }
    if (keyboard_check_pressed(ord("U")))
    {
        if (_shift)
        {
            pe_do_action("tool_rect_fill");
        }
        else
        {
            pe_do_action("tool_rect");
        }
    }
    if (keyboard_check_pressed(ord("O")))
    {
        if (_shift)
        {
            pe_do_action("tool_ellipse_fill");
        }
        else
        {
            pe_do_action("tool_ellipse");
        }
    }

    // Options
    if (keyboard_check_pressed(ord("X"))) { pe_do_action("pe_swap_colours"); }
    if (keyboard_check_pressed(ord("H"))) { pe_do_action("pe_flip_h"); }
    if (keyboard_check_pressed(ord("V"))) { pe_do_action("pe_flip_v"); }
    if (keyboard_check_pressed(ord("K"))) { pe_do_action("pe_tile_clip"); }
    if (keyboard_check_pressed(vk_home)) { pe_do_action("pe_fit"); }
    if (keyboard_check_pressed(219)) { pe_do_action("pe_brush_down"); }  // [
    if (keyboard_check_pressed(221)) { pe_do_action("pe_brush_up"); }    // ]
    if (keyboard_check_pressed(187) || keyboard_check_pressed(vk_add)) { pe_do_action("pe_zoom_in"); }       // =
    if (keyboard_check_pressed(189) || keyboard_check_pressed(vk_subtract)) { pe_do_action("pe_zoom_out"); } // -
    if (keyboard_check_pressed(vk_delete) || keyboard_check_pressed(vk_backspace)) { pe_do_action("pe_delete"); }
}

/// @desc Mouse press on the right-hand colour panel.
function pe_panel_click(_mx, _my, _press_l, _shift)
{
    // Colour swatches: click swaps primary / secondary
    if (_mx >= pe_swatch_x && _mx < pe_swatch_x + 60 && _my >= pe_swatch_y && _my < pe_swatch_y + 60)
    {
        pe_swap_colours();
        return;
    }

    if (_press_l)
    {
        if (_mx >= pe_sv_x && _mx < pe_sv_x + pe_sv_size && _my >= pe_sv_y && _my < pe_sv_y + pe_sv_size)
        {
            pe_drag_ui = "sv";
            pe_panel_drag(_mx, _my);
            return;
        }
        if (_mx >= pe_hue_x && _mx < pe_hue_x + pe_bar_w && _my >= pe_hue_y && _my < pe_hue_y + pe_bar_h)
        {
            pe_drag_ui = "hue";
            pe_panel_drag(_mx, _my);
            return;
        }
        if (_mx >= pe_alpha_x && _mx < pe_alpha_x + pe_bar_w && _my >= pe_alpha_y && _my < pe_alpha_y + pe_bar_h)
        {
            pe_drag_ui = "alpha";
            pe_panel_drag(_mx, _my);
            return;
        }
    }

    var _sw = pe_palette_at(_mx, _my);
    if (_sw >= 0)
    {
        if (_press_l && _shift)
        {
            pe_palette[_sw] = pe_col; // store the current colour in this swatch
            pe_notify("Stored colour in swatch " + string(_sw + 1));
        }
        else if (_press_l)
        {
            pe_set_primary(pe_palette[_sw], 255);
        }
        else
        {
            pe_set_secondary(pe_palette[_sw], 255);
        }
    }
}

/// @desc Drag inside the SV square / hue bar / alpha bar.
function pe_panel_drag(_mx, _my)
{
    if (pe_drag_ui == "sv")
    {
        pe_sat = clamp((_mx - pe_sv_x) / pe_sv_size, 0, 1) * 255;
        pe_val = (1 - clamp((_my - pe_sv_y) / pe_sv_size, 0, 1)) * 255;
        pe_col = make_color_hsv(pe_hue, pe_sat, pe_val);
    }
    if (pe_drag_ui == "hue")
    {
        pe_hue = clamp((_mx - pe_hue_x) / pe_bar_w, 0, 1) * 255;
        pe_col = make_color_hsv(pe_hue, pe_sat, pe_val);
    }
    if (pe_drag_ui == "alpha")
    {
        pe_alpha = round(clamp((_mx - pe_alpha_x) / pe_bar_w, 0, 1) * 255);
    }
}

/// @desc Start a tool action on the canvas.
function pe_canvas_press(_btn, _alt, _shift)
{
    var _px = pe_hover_x;
    var _py = pe_hover_y;

    pe_stroke_btn = _btn;
    pe_stroke_u32 = pe_u32(pe_col2, pe_alpha2);
    if (_btn == mb_left)
    {
        pe_stroke_u32 = pe_u32(pe_col, pe_alpha);
    }
    if (pe_tool == "eraser")
    {
        pe_stroke_u32 = 0;
    }

    // Eyedropper: tool, or hold Alt with any tool
    if (_alt || pe_tool == "picker")
    {
        pe_picking = true;
        pe_pick(_px, _py, _btn);
        return;
    }

    switch (pe_tool)
    {
        case "pencil":
        case "eraser":
            pe_undo_push();
            pe_begin_limits(_px, _py);
            pe_write_spans(pe_shape_spans("line", _px, _py, _px, _py), pe_stroke_u32);
            pe_last_x = _px;
            pe_last_y = _py;
            pe_stroking = true;
            break;

        case "fill":
            pe_undo_push();
            pe_begin_limits(_px, _py);
            pe_flood_fill(_px, _py, pe_stroke_u32);
            break;

        case "replace":
            if (_px >= 0 && _py >= 0 && _px < pe_w && _py < pe_h)
            {
                pe_undo_push();
                pe_begin_limits(_px, _py);
                pe_replace_colour(pe_get(_px, _py), pe_stroke_u32);
            }
            break;

        case "line":
        case "rect":
        case "rect_fill":
        case "ellipse":
        case "ellipse_fill":
            pe_start_x = _px;
            pe_start_y = _py;
            pe_cur_x = _px;
            pe_cur_y = _py;
            pe_stroking = true;
            break;

        case "select":
            pe_select_press(_px, _py, _btn);
            break;
    }
}

/// @desc Select tool press: move floating pixels, lift a selection, or start a marquee.
function pe_select_press(_px, _py, _btn)
{
    if (_btn == mb_right)
    {
        pe_float_commit();
        pe_sel_active = false;
        return;
    }

    if (pe_float_active)
    {
        if (_px >= pe_float_x && _px < pe_float_x + pe_float_w && _py >= pe_float_y && _py < pe_float_y + pe_float_h)
        {
            pe_sel_mode = "move";
            pe_move_off_x = _px - pe_float_x;
            pe_move_off_y = _py - pe_float_y;
            return;
        }
        pe_float_commit();
    }
    else if (pe_sel_active)
    {
        if (_px >= pe_sel_x0 && _px < pe_sel_x1 && _py >= pe_sel_y0 && _py < pe_sel_y1)
        {
            pe_float_lift();
            pe_sel_mode = "move";
            pe_move_off_x = _px - pe_float_x;
            pe_move_off_y = _py - pe_float_y;
            return;
        }
    }

    // New marquee
    pe_sel_mode = "marquee";
    pe_start_x = clamp(_px, 0, pe_w - 1);
    pe_start_y = clamp(_py, 0, pe_h - 1);
    pe_cur_x = pe_start_x;
    pe_cur_y = pe_start_y;
    pe_sel_x0 = pe_start_x;
    pe_sel_y0 = pe_start_y;
    pe_sel_x1 = pe_start_x + 1;
    pe_sel_y1 = pe_start_y + 1;
    pe_sel_active = true;
}

/// @desc Per-frame continuation / release of the current canvas action.
function pe_canvas_hold()
{
    var _px = pe_hover_x;
    var _py = pe_hover_y;

    if (pe_picking)
    {
        if (mouse_check_button(pe_stroke_btn))
        {
            pe_pick(_px, _py, pe_stroke_btn);
        }
        else
        {
            pe_picking = false;
        }
        return;
    }

    // Select tool drags
    if (pe_sel_mode != "")
    {
        if (mouse_check_button(mb_left))
        {
            if (pe_sel_mode == "marquee")
            {
                pe_cur_x = clamp(_px, 0, pe_w - 1);
                pe_cur_y = clamp(_py, 0, pe_h - 1);
                pe_sel_x0 = min(pe_start_x, pe_cur_x);
                pe_sel_y0 = min(pe_start_y, pe_cur_y);
                pe_sel_x1 = max(pe_start_x, pe_cur_x) + 1;
                pe_sel_y1 = max(pe_start_y, pe_cur_y) + 1;
            }
            if (pe_sel_mode == "move")
            {
                pe_float_x = _px - pe_move_off_x;
                pe_float_y = _py - pe_move_off_y;
                pe_sel_from_float();
            }
        }
        else
        {
            // A click without a drag clears the marquee
            if (pe_sel_mode == "marquee" && pe_start_x == pe_cur_x && pe_start_y == pe_cur_y)
            {
                pe_sel_active = false;
            }
            pe_sel_mode = "";
        }
        return;
    }

    if (!pe_stroking)
    {
        return;
    }

    var _held = mouse_check_button(pe_stroke_btn);

    if (pe_tool == "pencil" || pe_tool == "eraser")
    {
        if (_held)
        {
            if (_px != pe_last_x || _py != pe_last_y)
            {
                pe_write_spans(pe_shape_spans("line", pe_last_x, pe_last_y, _px, _py), pe_stroke_u32);
                pe_last_x = _px;
                pe_last_y = _py;
            }
        }
        else
        {
            pe_stroking = false;
        }
        return;
    }

    // Shapes: preview while held, commit on release
    if (_held)
    {
        pe_cur_x = _px;
        pe_cur_y = _py;
    }
    else
    {
        pe_undo_push();
        pe_begin_limits(pe_start_x, pe_start_y);
        pe_write_spans(pe_shape_spans(pe_tool, pe_start_x, pe_start_y, pe_cur_x, pe_cur_y), pe_stroke_u32);
        pe_stroking = false;
    }
}

// ============================================================
//  DRAW (Draw GUI)
// ============================================================

/// @desc Draw spans as screen rectangles (previews and brush footprint).
function pe_draw_spans(_spans)
{
    for (var _i = 0; _i < array_length(_spans); _i++)
    {
        var _sp = _spans[_i];
        var _x1 = pe_view_x + _sp[0] * pe_zoom;
        var _y1 = pe_view_y + _sp[2] * pe_zoom;
        var _x2 = pe_view_x + (_sp[1] + 1) * pe_zoom - 1;
        var _y2 = _y1 + pe_zoom - 1;
        draw_rectangle(_x1, _y1, _x2, _y2, false);
    }
}

/// @desc Draw a rectangle outline around sheet pixels [x0,x1) x [y0,y1).
function pe_draw_sheet_rect(_x0, _y0, _x1, _y1, _col)
{
    var _sx0 = pe_view_x + _x0 * pe_zoom;
    var _sy0 = pe_view_y + _y0 * pe_zoom;
    var _sx1 = pe_view_x + _x1 * pe_zoom - 1;
    var _sy1 = pe_view_y + _y1 * pe_zoom - 1;
    draw_set_colour(_col);
    draw_rectangle(_sx0, _sy0, _sx1, _sy1, true);
}

function pe_draw_button(_bt, _mx, _my)
{
    var _hover = (_mx >= _bt.x0 && _mx < _bt.x1 && _my >= _bt.y0 && _my < _bt.y1);
    var _on = menu_item_checked(_bt.act);

    draw_set_colour(pe_col_button);
    if (_hover)
    {
        draw_set_colour(menu_col_hover);
    }
    if (_on)
    {
        draw_set_colour(menu_col_accent);
    }
    draw_rectangle(_bt.x0, _bt.y0, _bt.x1 - 1, _bt.y1 - 1, false);
    draw_set_colour(menu_col_line);
    draw_rectangle(_bt.x0, _bt.y0, _bt.x1 - 1, _bt.y1 - 1, true);

    var _cy = (_bt.y0 + _bt.y1) * 0.5;
    draw_set_colour(c_white);
    if (_bt.key == "" && string_length(_bt.label) <= 1)
    {
        draw_set_halign(fa_center);
        draw_text((_bt.x0 + _bt.x1) * 0.5, _cy, _bt.label);
    }
    else
    {
        draw_set_halign(fa_left);
        draw_text(_bt.x0 + 8, _cy, _bt.label);
        if (_bt.key != "")
        {
            draw_set_halign(fa_right);
            draw_set_colour(c_ltgray);
            draw_text(_bt.x1 - 7, _cy, _bt.key);
        }
    }
    draw_set_halign(fa_left);
}

function pe_draw()
{
    pe_layout();

    var _gw = display_get_gui_width();
    var _gh = display_get_gui_height();
    var _mx = device_mouse_x_to_gui(0);
    var _my = device_mouse_y_to_gui(0);

    gpu_set_cullmode(cull_noculling);
    gpu_set_tex_filter(false);
    draw_set_alpha(1);

    // --- Viewport background ---
    draw_set_colour(pe_col_bg);
    draw_rectangle(0, 0, _gw, _gh, false);

    // Sheet rectangle on screen, clipped to the viewport
    var _sx0 = max(pe_vx0, pe_view_x);
    var _sy0 = max(pe_vy0, pe_view_y);
    var _sx1 = min(pe_vx1, pe_view_x + pe_w * pe_zoom);
    var _sy1 = min(pe_vy1, pe_view_y + pe_h * pe_zoom);

    // --- Checkerboard behind the sheet (shows transparency) ---
    var _vw = pe_vx1 - pe_vx0;
    var _vh = pe_vy1 - pe_vy0;
    if (_vw > 0 && _vh > 0)
    {
        if (!surface_exists(pe_checker_surf) || pe_checker_w != _vw || pe_checker_h != _vh)
        {
            if (surface_exists(pe_checker_surf))
            {
                surface_free(pe_checker_surf);
            }
            pe_checker_surf = surface_create(_vw, _vh);
            pe_checker_w = _vw;
            pe_checker_h = _vh;
            surface_set_target(pe_checker_surf);
            draw_clear(pe_col_check_a);
            draw_set_colour(pe_col_check_b);
            var _cs = 8;
            for (var _cy = 0; _cy < _vh; _cy += _cs)
            {
                for (var _cx = 0; _cx < _vw; _cx += _cs)
                {
                    if (((_cx div _cs) + (_cy div _cs)) mod 2 == 1)
                    {
                        draw_rectangle(_cx, _cy, _cx + _cs - 1, _cy + _cs - 1, false);
                    }
                }
            }
            surface_reset_target();
        }
        if (_sx1 > _sx0 && _sy1 > _sy0)
        {
            draw_surface_part(pe_checker_surf, _sx0 - pe_vx0, _sy0 - pe_vy0, _sx1 - _sx0, _sy1 - _sy0, _sx0, _sy0);
        }
    }

    // --- Sheet ---
    pe_sync_surface();
    var _px0 = max(0, floor((pe_vx0 - pe_view_x) / pe_zoom));
    var _py0 = max(0, floor((pe_vy0 - pe_view_y) / pe_zoom));
    var _px1 = min(pe_w, ceil((pe_vx1 - pe_view_x) / pe_zoom));
    var _py1 = min(pe_h, ceil((pe_vy1 - pe_view_y) / pe_zoom));
    if (_px1 > _px0 && _py1 > _py0)
    {
        draw_surface_part_ext(pe_surf, _px0, _py0, _px1 - _px0, _py1 - _py0, pe_view_x + _px0 * pe_zoom, pe_view_y + _py0 * pe_zoom, pe_zoom, pe_zoom, c_white, 1);
    }

    // --- Floating pixels ---
    if (pe_float_active)
    {
        if (!surface_exists(pe_float_surf))
        {
            pe_float_surf = surface_create(pe_float_w, pe_float_h);
            pe_float_stale = true;
        }
        if (pe_float_stale)
        {
            buffer_set_surface(pe_float_buf, pe_float_surf, 0);
            pe_float_stale = false;
        }
        draw_surface_ext(pe_float_surf, pe_view_x + pe_float_x * pe_zoom, pe_view_y + pe_float_y * pe_zoom, pe_zoom, pe_zoom, 0, c_white, 1);
    }

    // --- Shape preview ---
    if (pe_stroking && pe_tool != "pencil" && pe_tool != "eraser")
    {
        var _pcol = pe_col2;
        var _palpha = pe_alpha2;
        if (pe_stroke_btn == mb_left)
        {
            _pcol = pe_col;
            _palpha = pe_alpha;
        }
        draw_set_colour(_pcol);
        draw_set_alpha(max(0.35, _palpha / 255));
        pe_draw_spans(pe_shape_spans(pe_tool, pe_start_x, pe_start_y, pe_cur_x, pe_cur_y));
        draw_set_alpha(1);
    }

    // --- Pixel grid ---
    if (pe_show_pixel_grid && pe_zoom >= 6 && _px1 > _px0 && _py1 > _py0)
    {
        draw_set_colour(c_black);
        draw_set_alpha(0.18);
        var _gy0 = pe_view_y + _py0 * pe_zoom;
        var _gy1 = pe_view_y + _py1 * pe_zoom;
        var _gx0 = pe_view_x + _px0 * pe_zoom;
        var _gx1 = pe_view_x + _px1 * pe_zoom;
        for (var _gx = _px0; _gx <= _px1; _gx++)
        {
            var _plx = pe_view_x + _gx * pe_zoom;
            draw_line(_plx, _gy0, _plx, _gy1);
        }
        for (var _gy = _py0; _gy <= _py1; _gy++)
        {
            var _ply = pe_view_y + _gy * pe_zoom;
            draw_line(_gx0, _ply, _gx1, _ply);
        }
        draw_set_alpha(1);
    }

    // --- Tile grid ---
    if (pe_show_tile_grid && _px1 > _px0 && _py1 > _py0)
    {
        draw_set_colour(pe_col_tile_grid);
        draw_set_alpha(0.55);
        var _tc0 = _px0 div pe_cell;
        var _tc1 = ceil(_px1 / pe_cell);
        var _tr0 = _py0 div pe_cell;
        var _tr1 = ceil(_py1 / pe_cell);
        var _ty0 = pe_view_y + _py0 * pe_zoom;
        var _ty1 = pe_view_y + _py1 * pe_zoom;
        var _tx0 = pe_view_x + _px0 * pe_zoom;
        var _tx1 = pe_view_x + _px1 * pe_zoom;
        for (var _tc = _tc0; _tc <= _tc1; _tc++)
        {
            var _tlx = pe_view_x + _tc * pe_cell * pe_zoom;
            draw_line(_tlx, _ty0, _tlx, _ty1);
        }
        for (var _tr = _tr0; _tr <= _tr1; _tr++)
        {
            var _tly = pe_view_y + _tr * pe_cell * pe_zoom;
            draw_line(_tx0, _tly, _tx1, _tly);
        }
        draw_set_alpha(1);
    }

    // Active tile (the one the 3D brush starts on)
    var _asub = clamp(active_sub, 0, max(0, pe_frame_count - 1));
    var _ax = (_asub mod pe_cols) * pe_cell;
    var _ay = (_asub div pe_cols) * pe_cell;
    pe_draw_sheet_rect(_ax, _ay, _ax + pe_cell, _ay + pe_cell, c_white);

    // --- Selection ---
    if (pe_float_active)
    {
        pe_draw_sheet_rect(pe_float_x, pe_float_y, pe_float_x + pe_float_w, pe_float_y + pe_float_h, c_black);
        var _ants = c_white;
        if ((current_time div 250) mod 2 == 0)
        {
            _ants = c_yellow;
        }
        draw_set_colour(_ants);
        draw_rectangle(pe_view_x + pe_float_x * pe_zoom + 1, pe_view_y + pe_float_y * pe_zoom + 1, pe_view_x + (pe_float_x + pe_float_w) * pe_zoom - 2, pe_view_y + (pe_float_y + pe_float_h) * pe_zoom - 2, true);
    }
    else if (pe_sel_active)
    {
        pe_draw_sheet_rect(pe_sel_x0, pe_sel_y0, pe_sel_x1, pe_sel_y1, c_black);
        var _ants2 = c_white;
        if ((current_time div 250) mod 2 == 0)
        {
            _ants2 = c_yellow;
        }
        draw_set_colour(_ants2);
        draw_rectangle(pe_view_x + pe_sel_x0 * pe_zoom + 1, pe_view_y + pe_sel_y0 * pe_zoom + 1, pe_view_x + pe_sel_x1 * pe_zoom - 2, pe_view_y + pe_sel_y1 * pe_zoom - 2, true);
    }

    // --- Cursor footprint ---
    if (pe_mouse_in_view && !pe_panning)
    {
        if (pe_tool == "pencil" || pe_tool == "eraser" || pe_tool == "line")
        {
            var _half = floor((pe_brush - 1) / 2);
            pe_draw_sheet_rect(pe_hover_x - _half, pe_hover_y - _half, pe_hover_x - _half + pe_brush, pe_hover_y - _half + pe_brush, c_white);
        }
        else
        {
            pe_draw_sheet_rect(pe_hover_x, pe_hover_y, pe_hover_x + 1, pe_hover_y + 1, c_white);
        }
    }

    // ==== Panels (drawn over the canvas, so they also clip its edges) ====
    gpu_set_tex_filter(true);
    draw_set_font(-1);
    draw_set_valign(fa_middle);

    draw_set_colour(pe_col_panel);
    draw_rectangle(0, menu_bar_h, pe_vx0 - 1, _gh, false);                       // left
    draw_rectangle(pe_vx1, menu_bar_h, _gw, _gh, false);                           // right
    draw_rectangle(pe_vx0, menu_bar_h, pe_vx1, pe_vy0 - 1, false);                 // options bar
    draw_rectangle(pe_vx0, pe_vy1, pe_vx1, _gh, false);                            // status bar
    draw_set_colour(menu_col_line);
    draw_line(pe_vx0 - 1, pe_vy0, pe_vx0 - 1, pe_vy1);
    draw_line(pe_vx1, pe_vy0, pe_vx1, pe_vy1);
    draw_line(pe_vx0, pe_vy0 - 1, pe_vx1, pe_vy0 - 1);
    draw_line(pe_vx0, pe_vy1, pe_vx1, pe_vy1);

    // Buttons (toolbar + options bar)
    for (var _b = 0; _b < array_length(pe_buttons); _b++)
    {
        pe_draw_button(pe_buttons[_b], _mx, _my);
    }

    // Brush size readout
    draw_set_colour(c_ltgray);
    draw_set_halign(fa_left);
    draw_text(8, pe_brush_label_y + 9, "Brush size  [ ]");
    draw_set_halign(fa_center);
    draw_set_colour(c_white);
    draw_text(pe_tool_w * 0.5, pe_brush_value_y + 11, string(pe_brush) + " px");
    draw_set_halign(fa_left);

    pe_draw_colour_panel();

    // --- Status bar ---
    var _status = pe_tool_label(pe_tool) + "   |   Zoom " + string(pe_zoom) + "x";
    if (pe_hover_x >= 0 && pe_hover_y >= 0 && pe_hover_x < pe_w && pe_hover_y < pe_h)
    {
        var _tile = (pe_hover_y div pe_cell) * pe_cols + (pe_hover_x div pe_cell);
        _status += "   |   Pixel " + string(pe_hover_x) + "," + string(pe_hover_y);
        _status += "   |   Tile #" + string(_tile) + " (" + string(pe_hover_x mod pe_cell) + "," + string(pe_hover_y mod pe_cell) + ")";
    }
    if (pe_sel_active)
    {
        _status += "   |   Sel " + string(pe_sel_x1 - pe_sel_x0) + "x" + string(pe_sel_y1 - pe_sel_y0);
    }
    if (pe_dirty)
    {
        _status += "   |   Not applied";
    }
    if (pe_png_dirty)
    {
        _status += "   |   PNG unsaved";
    }
    draw_set_colour(c_white);
    draw_text(pe_vx0 + 8, (pe_vy1 + _gh) * 0.5, _status);
    if (pe_message_timer > 0)
    {
        draw_set_halign(fa_right);
        draw_set_colour(c_yellow);
        draw_text(pe_vx1 - 8, (pe_vy1 + _gh) * 0.5, pe_message);
        draw_set_halign(fa_left);
    }

    // Restore shared draw state
    draw_set_valign(fa_top);
    draw_set_halign(fa_left);
    draw_set_colour(c_white);
    draw_set_alpha(1);
    gpu_set_tex_filter(tex_filter_on);
}

/// @desc Right-hand panel: swatches, HSV picker, alpha, palette, sheet info.
function pe_draw_colour_panel()
{
    var _px = pe_swatch_x;
    var _py = pe_swatch_y;

    // Secondary (behind) then primary (front)
    draw_set_colour(pe_col_check_a);
    draw_rectangle(_px + 22, _py + 22, _px + 58, _py + 58, false);
    draw_set_alpha(pe_alpha2 / 255);
    draw_set_colour(pe_col2);
    draw_rectangle(_px + 22, _py + 22, _px + 58, _py + 58, false);
    draw_set_alpha(1);
    draw_set_colour(c_white);
    draw_rectangle(_px + 22, _py + 22, _px + 58, _py + 58, true);

    draw_set_colour(pe_col_check_a);
    draw_rectangle(_px, _py, _px + 36, _py + 36, false);
    draw_set_alpha(pe_alpha / 255);
    draw_set_colour(pe_col);
    draw_rectangle(_px, _py, _px + 36, _py + 36, false);
    draw_set_alpha(1);
    draw_set_colour(c_white);
    draw_rectangle(_px, _py, _px + 36, _py + 36, true);

    draw_set_halign(fa_left);
    draw_set_colour(c_white);
    draw_text(_px + 68, _py + 9, pe_colour_hex(pe_col) + "  A " + string(pe_alpha));
    draw_set_colour(c_ltgray);
    draw_text(_px + 68, _py + 29, pe_colour_hex(pe_col2) + "  A " + string(pe_alpha2));
    draw_text(_px + 68, _py + 49, "X / click: swap");

    // --- Saturation / value square (columns of vertical gradients) ---
    var _steps = 48;
    var _cw = pe_sv_size / _steps;
    for (var _i = 0; _i < _steps; _i++)
    {
        var _s = (_i / (_steps - 1)) * 255;
        var _top = make_color_hsv(pe_hue, _s, 255);
        var _x1 = pe_sv_x + _i * _cw;
        draw_rectangle_colour(_x1, pe_sv_y, _x1 + _cw, pe_sv_y + pe_sv_size, _top, _top, c_black, c_black, false);
    }
    draw_set_colour(menu_col_line);
    draw_rectangle(pe_sv_x, pe_sv_y, pe_sv_x + pe_sv_size, pe_sv_y + pe_sv_size, true);
    var _mkx = pe_sv_x + (pe_sat / 255) * pe_sv_size;
    var _mky = pe_sv_y + (1 - pe_val / 255) * pe_sv_size;
    draw_set_colour(c_black);
    draw_circle(_mkx, _mky, 5, true);
    draw_set_colour(c_white);
    draw_circle(_mkx, _mky, 4, true);

    // --- Hue bar ---
    var _hsteps = 64;
    var _hw = pe_bar_w / _hsteps;
    for (var _h = 0; _h < _hsteps; _h++)
    {
        var _c0 = make_color_hsv((_h / _hsteps) * 255, 255, 255);
        var _c1 = make_color_hsv(((_h + 1) / _hsteps) * 255, 255, 255);
        var _hx = pe_hue_x + _h * _hw;
        draw_rectangle_colour(_hx, pe_hue_y, _hx + _hw, pe_hue_y + pe_bar_h, _c0, _c1, _c1, _c0, false);
    }
    var _hmx = pe_hue_x + (pe_hue / 255) * pe_bar_w;
    draw_set_colour(c_white);
    draw_rectangle(_hmx - 2, pe_hue_y - 2, _hmx + 2, pe_hue_y + pe_bar_h + 2, true);

    // --- Alpha bar ---
    draw_rectangle_colour(pe_alpha_x, pe_alpha_y, pe_alpha_x + pe_bar_w, pe_alpha_y + pe_bar_h, pe_col_check_a, pe_col, pe_col, pe_col_check_a, false);
    var _amx = pe_alpha_x + (pe_alpha / 255) * pe_bar_w;
    draw_set_colour(c_white);
    draw_rectangle(_amx - 2, pe_alpha_y - 2, _amx + 2, pe_alpha_y + pe_bar_h + 2, true);

    // --- Palette ---
    for (var _p = 0; _p < array_length(pe_palette); _p++)
    {
        var _sx = pe_pal_x + (_p mod pe_pal_cols) * (pe_pal_size + pe_pal_gap);
        var _sy = pe_pal_y + (_p div pe_pal_cols) * (pe_pal_size + pe_pal_gap);
        draw_set_colour(pe_palette[_p]);
        draw_rectangle(_sx, _sy, _sx + pe_pal_size - 1, _sy + pe_pal_size - 1, false);
        draw_set_colour(menu_col_line);
        if (pe_palette[_p] == pe_col)
        {
            draw_set_colour(c_white);
        }
        draw_rectangle(_sx, _sy, _sx + pe_pal_size - 1, _sy + pe_pal_size - 1, true);
    }

    // --- Info ---
    var _iy = pe_info_y;
    draw_set_colour(c_ltgray);
    draw_text(pe_swatch_x, _iy + 8, "LMB primary, RMB secondary");
    draw_text(pe_swatch_x, _iy + 26, "Shift+click swatch: store");
    draw_text(pe_swatch_x, _iy + 50, "Sheet " + string(pe_w) + "x" + string(pe_h) + " px");
    draw_text(pe_swatch_x, _iy + 68, string(pe_frame_count) + " tiles, " + string(pe_cell) + "px, " + string(pe_cols) + " cols");
    draw_text(pe_swatch_x, _iy + 86, "Active tile #" + string(active_sub));
    draw_text(pe_swatch_x, _iy + 104, "Undo " + string(array_length(pe_undo)) + " / " + string(pe_undo_max));
}
