/// BRUSH_system
/// Sub-tile nudging of the held brush with the arrow keys.
///
/// One step is one texture pixel of a tile. A tile quad is exactly 1 world unit
/// across and carries one cell of the sheet, so a single texel is
/// 1 / global.tile_cell world units - 0.0625 at the default 16px cell. Change
/// the cell size and the step follows it.
///
/// The nudge is stored per world axis in texel steps (nudge_x / nudge_y /
/// nudge_z, initialised in the Create event) and folded into ghost_off_* each
/// frame, so placing a tile bakes the current nudge into its off_x/off_y/off_z
/// exactly like the decal offset does. Only the two in-plane axes of the active
/// plane are applied; the plane's constant axis stays under the decal offset's
/// control.
///
/// Directions are camera-relative: Right nudges toward screen right whatever
/// the orbit, by projecting the camera basis onto the active plane and taking
/// the dominant in-plane axis.

#macro NUDGE_FAST_STEP 4    // Shift + arrow moves this many texels at once

/// @desc Screen-right and screen-up as world vectors, from the orbit camera.
function brush_cam_basis()
{
    var _cx = cam_look_x + dcos(cam_yaw) * dcos(cam_pitch) * cam_dist;
    var _cy = cam_look_y + dsin(cam_yaw) * dcos(cam_pitch) * cam_dist;
    var _cz = cam_look_z - dsin(cam_pitch) * cam_dist;

    var _fx = cam_look_x - _cx;
    var _fy = cam_look_y - _cy;
    var _fz = cam_look_z - _cz;
    var _fl = sqrt(_fx * _fx + _fy * _fy + _fz * _fz);
    if (_fl < 0.00001)
    {
        _fl = 1;
    }
    _fx /= _fl;
    _fy /= _fl;
    _fz /= _fl;

    var _rx = dcos(cam_yaw - 90);
    var _ry = dsin(cam_yaw - 90);
    var _rz = 0;

    // up = cross(right, forward)
    var _ux = _ry * _fz - _rz * _fy;
    var _uy = _rz * _fx - _rx * _fz;
    var _uz = _rx * _fy - _ry * _fx;

    return { rx: _rx, ry: _ry, rz: _rz, ux: _ux, uy: _uy, uz: _uz };
}

/// @desc Map a screen direction onto the active plane's dominant world axis.
/// Returns [axis, sign] with axis "x", "y" or "z" - or ["", 0] when the
/// direction has no usable component in the plane.
function brush_nudge_axis(_vx, _vy, _vz)
{
    // Keep only the in-plane components; the plane's constant axis is dropped,
    // which is what projecting onto the plane amounts to for an axis-aligned one.
    var _ax = 0;
    var _ay = 0;
    var _az = 0;

    if (active_plane == "XY")
    {
        _ax = _vx;
        _ay = _vy;
    }
    if (active_plane == "XZ")
    {
        _ax = _vx;
        _az = _vz;
    }
    if (active_plane == "YZ")
    {
        _ay = _vy;
        _az = _vz;
    }

    var _best = "";
    var _mag = 0;
    if (abs(_ax) > _mag)
    {
        _best = "x";
        _mag = abs(_ax);
    }
    if (abs(_ay) > _mag)
    {
        _best = "y";
        _mag = abs(_ay);
    }
    if (abs(_az) > _mag)
    {
        _best = "z";
        _mag = abs(_az);
    }

    if (_mag < 0.0001)
    {
        return ["", 0];
    }

    var _sign = 1;
    if (_best == "x" && _ax < 0)
    {
        _sign = -1;
    }
    if (_best == "y" && _ay < 0)
    {
        _sign = -1;
    }
    if (_best == "z" && _az < 0)
    {
        _sign = -1;
    }

    return [_best, _sign];
}

/// @desc Add texel steps to one world axis, clamped to nudge_max.
function brush_nudge_add(_axis, _amount)
{
    if (_axis == "x")
    {
        nudge_x = clamp(nudge_x + _amount, -nudge_max, nudge_max);
    }
    if (_axis == "y")
    {
        nudge_y = clamp(nudge_y + _amount, -nudge_max, nudge_max);
    }
    if (_axis == "z")
    {
        nudge_z = clamp(nudge_z + _amount, -nudge_max, nudge_max);
    }
}

/// @desc Back to no offset.
function brush_nudge_reset()
{
    nudge_x = 0;
    nudge_y = 0;
    nudge_z = 0;
}

/// @desc Read the arrow keys (and the Place menu items). Call in the Step event
/// before brush_nudge_apply().
function brush_nudge_update()
{
    if ((keyboard_check_pressed(ord("N")) && !keyboard_check(vk_control)) || menu_action == "nudge_reset")
    {
        brush_nudge_reset();
        return;
    }

    var _step = 1;
    if (keyboard_check(vk_shift))
    {
        _step = NUDGE_FAST_STEP;
    }

    var _right = 0;
    var _up = 0;

    if (keyboard_check_pressed(vk_right))
    {
        _right += 1;
    }
    if (keyboard_check_pressed(vk_left))
    {
        _right -= 1;
    }
    if (keyboard_check_pressed(vk_up))
    {
        _up += 1;
    }
    if (keyboard_check_pressed(vk_down))
    {
        _up -= 1;
    }

    // The menu items run the same code as the keys
    if (menu_action == "nudge_right")
    {
        _right += 1;
    }
    if (menu_action == "nudge_left")
    {
        _right -= 1;
    }
    if (menu_action == "nudge_up")
    {
        _up += 1;
    }
    if (menu_action == "nudge_down")
    {
        _up -= 1;
    }

    if (_right == 0 && _up == 0)
    {
        return;
    }

    var _basis = brush_cam_basis();

    if (_right != 0)
    {
        var _ra = brush_nudge_axis(_basis.rx, _basis.ry, _basis.rz);
        brush_nudge_add(_ra[0], _ra[1] * _right * _step);
    }

    if (_up != 0)
    {
        var _ua = brush_nudge_axis(_basis.ux, _basis.uy, _basis.uz);
        brush_nudge_add(_ua[0], _ua[1] * _up * _step);
    }
}

/// @desc Fold the nudge into ghost_off_*. Call straight after the decal offset
/// is computed, so both land on the same variables and place together.
function brush_nudge_apply()
{
    var _texel = 1 / max(global.tile_cell, 1);

    if (active_plane == "XY")
    {
        ghost_off_x += nudge_x * _texel;
        ghost_off_y += nudge_y * _texel;
    }
    if (active_plane == "XZ")
    {
        ghost_off_x += nudge_x * _texel;
        ghost_off_z += nudge_z * _texel;
    }
    if (active_plane == "YZ")
    {
        ghost_off_y += nudge_y * _texel;
        ghost_off_z += nudge_z * _texel;
    }
}

/// @desc Signed number with an explicit plus, for the HUD.
function brush_nudge_num(_v)
{
    if (_v > 0)
    {
        return "+" + string(_v);
    }
    return string(_v);
}

/// @desc The active plane's nudge as HUD text, or "" when there is none.
function brush_nudge_text()
{
    var _a = 0;
    var _b = 0;
    var _la = "X";
    var _lb = "Y";

    if (active_plane == "XY")
    {
        _a = nudge_x;
        _b = nudge_y;
        _la = "X";
        _lb = "Y";
    }
    if (active_plane == "XZ")
    {
        _a = nudge_x;
        _b = nudge_z;
        _la = "X";
        _lb = "Z";
    }
    if (active_plane == "YZ")
    {
        _a = nudge_y;
        _b = nudge_z;
        _la = "Y";
        _lb = "Z";
    }

    if (_a == 0 && _b == 0)
    {
        return "";
    }

    // Kept short: it shares the HUD box with the plane label, which is only
    // 120px wide before it would run into the background gradient swatch.
    return _la + brush_nudge_num(_a) + " " + _lb + brush_nudge_num(_b) + " px";
}

// ============================================================
//  TILE KEYS AND FACING
// ============================================================
// A tile's key says where it physically is: cell, plane, and how far its decal
// offset pushes it along the plane's own world axis, in cm steps. Two tiles in
// the same physical place always make the same key, so the tile struct can
// only ever hold one of them.
//
// The key used to end with the raw decal counter (grid_offset), whose
// direction flips with the camera side. That let "1 from above" and "Tab+1
// from below" land in the same spot under different keys - two faces in one
// place - while two different spots could share a key and overwrite each other.

/// @desc A whole number as key text. Never "-0", never float noise.
function tile_key_num(_v)
{
    var _r = round(_v);
    if (_r == 0)
    {
        return "0";
    }
    return string(_r);
}

/// @desc Signed decal step along the plane's own world axis.
function tile_offset_step(_plane, _ox, _oy, _oz)
{
    var _o = _oz;
    if (_plane == "XZ")
    {
        _o = _oy;
    }
    if (_plane == "YZ")
    {
        _o = _ox;
    }
    return round(_o / cm_world);
}

/// @desc The key for a tile at this cell / plane / decal offset.
function tile_key(_x, _y, _z, _plane, _ox, _oy, _oz)
{
    return tile_key_num(_x) + "," + tile_key_num(_y) + "," + tile_key_num(_z) + "," + _plane + "," + tile_key_num(tile_offset_step(_plane, _ox, _oy, _oz));
}

/// @desc The key a tile struct belongs under.
function tile_key_of(_t)
{
    return tile_key(_t.x, _t.y, _t.z, _t.plane, _t.off_x, _t.off_y, _t.off_z);
}

/// @desc True when the tile's visible side faces this point. Uses the same
/// winding the draw function builds: XY and XZ show toward +axis at facing >= 0,
/// YZ toward -X. (Reading nrm_x for YZ got this backwards: the placement code
/// stores nrm_x = facing, which points AWAY from a YZ wall's visible side.)
function tile_faces_point(_t, _px, _py, _pz)
{
    var _f = 1;
    if (_t.facing < 0)
    {
        _f = -1;
    }

    if (_t.plane == "XY")
    {
        return (_f * (_pz - (-_t.z + _t.off_z))) > 0;
    }
    if (_t.plane == "XZ")
    {
        return (_f * (_py - (_t.y + _t.off_y))) > 0;
    }
    return (-_f * (_px - (_t.x + _t.off_x))) > 0;
}

/// @desc Tiles from old saves can predate some fields. Fill in what the key
/// and facing code needs so nothing reads a missing variable.
function tile_fill_defaults(_t)
{
    if (!variable_struct_exists(_t, "off_x"))
    {
        _t.off_x = 0;
        _t.off_y = 0;
        _t.off_z = 0;
    }
    if (!variable_struct_exists(_t, "facing"))
    {
        _t.facing = 1;
    }
}

/// @desc Rebuild every key from the tile it holds. Anything left sharing a
/// place is resolved: same facing keeps one, opposite facing cancels both.
/// Run on load (older saves keyed by the raw decal counter) and from the
/// Edit menu. Returns a struct: dropped (duplicates), cancelled (pairs x2).
function world_rekey()
{
    var _out = { dropped: 0, cancelled: 0 };
    var _fresh = {};
    var _dead = {};
    var _names = variable_struct_get_names(global.world_tiles);

    for (var _i = 0; _i < array_length(_names); _i++)
    {
        var _t = variable_struct_get(global.world_tiles, _names[_i]);
        tile_fill_defaults(_t);
        var _k = tile_key_of(_t);

        if (variable_struct_exists(_dead, _k))
        {
            _out.dropped += 1;
            continue;
        }

        if (variable_struct_exists(_fresh, _k))
        {
            var _there = variable_struct_get(_fresh, _k);
            if (sign(_there.facing) == -sign(_t.facing))
            {
                // Back to back in one place: neither can be the right one
                struct_remove(_fresh, _k);
                variable_struct_set(_dead, _k, true);
                _out.cancelled += 2;
            }
            else
            {
                _out.dropped += 1;
            }
            continue;
        }

        variable_struct_set(_fresh, _k, _t);
    }

    global.world_tiles = _fresh;
    return _out;
}

/// @desc Raycast every placed tile and return the nearest one the ray hits.
/// Each tile is tested against its OWN plane, so a ray finds floors and walls
/// alike. Used by the Shift depth match and by Alt+click tile picking.
/// Returns a struct, always fully populated:
///   found - true when a tile was hit
///   key   - its key in global.world_tiles ("" when nothing was hit)
///   tile  - the tile struct itself (undefined when nothing was hit)
///   t     - distance along the ray
///   hx/hy/hz - the hit point, with the tile's decal offset taken back out
/// A small tolerance is allowed around each tile so pointing exactly at a seam
/// still hits the tile there instead of carrying on to one behind it. While
/// backface culling is on, tiles facing away from the camera are skipped: they
/// are not on screen, so they should not be picked through what is.
function tile_raycast_nearest(_ox, _oy, _oz, _rx, _ry, _rz)
{
    var _out = {
        found: false,
        key: "",
        tile: undefined,
        t: 0,
        hx: 0,
        hy: 0,
        hz: 0
    };

    var _names = variable_struct_get_names(global.world_tiles);
    var _edge = 0.002;   // seam tolerance, in tile units
    var _hx = 0;
    var _hy = 0;
    var _hz = 0;

    for (var _i = 0; _i < array_length(_names); _i++)
    {
        var _t = variable_struct_get(global.world_tiles, _names[_i]);

        var _hit_ok = false;
        var _tt = 0;

        // Skip what the view is culling anyway (its visible side faces away)
        if (cull_on && !tile_faces_point(_t, _ox, _oy, _oz))
        {
            continue;
        }

        if (_t.plane == "XY")
        {
            // Drawn at world Z = -z, plus its decal offset
            if (abs(_rz) > 0.0001)
            {
                _tt = (-_t.z + _t.off_z - _oz) / _rz;
                _hx = _ox + _rx * _tt - _t.off_x;
                _hy = _oy + _ry * _tt - _t.off_y;
                _hz = -_t.z;
                if (_hx >= _t.x - _edge && _hx <= _t.x + 1 + _edge && _hy >= _t.y - _edge && _hy <= _t.y + 1 + _edge)
                {
                    _hit_ok = true;
                }
            }
        }
        if (_t.plane == "XZ")
        {
            if (abs(_ry) > 0.0001)
            {
                _tt = (_t.y + _t.off_y - _oy) / _ry;
                _hx = _ox + _rx * _tt - _t.off_x;
                _hy = _t.y;
                _hz = _oz + _rz * _tt - _t.off_z;
                if (_hx >= _t.x - _edge && _hx <= _t.x + 1 + _edge && _hz >= _t.z - _edge && _hz <= _t.z + 1 + _edge)
                {
                    _hit_ok = true;
                }
            }
        }
        if (_t.plane == "YZ")
        {
            if (abs(_rx) > 0.0001)
            {
                _tt = (_t.x + _t.off_x - _ox) / _rx;
                _hx = _t.x;
                _hy = _oy + _ry * _tt - _t.off_y;
                _hz = _oz + _rz * _tt - _t.off_z;
                if (_hy >= _t.y - _edge && _hy <= _t.y + 1 + _edge && _hz >= _t.z - _edge && _hz <= _t.z + 1 + _edge)
                {
                    _hit_ok = true;
                }
            }
        }

        // Only in front of the camera, and keep the nearest
        if (_hit_ok && _tt > 0)
        {
            if (!_out.found || _tt < _out.t)
            {
                _out.found = true;
                _out.key = _names[_i];
                _out.tile = _t;
                _out.t = _tt;
                _out.hx = _hx;
                _out.hy = _hy;
                _out.hz = _hz;
            }
        }
    }

    return _out;
}

// ============================================================
//  CLUSTER SELECT / COPY / CLIP HISTORY
// ============================================================
// Ctrl+Shift+drag picks a screen-space rectangle and selects every placed tile
// touching it. Ctrl+C turns the selection into a "clip": a rigid lump of world
// geometry (each tile keeps its plane, rotation, flips and decal offset) plus a
// square thumbnail grabbed from the view. Clips sit in a strip down the left
// edge, newest first. Left-click one to hold it, left-click in the scene to
// stamp it centred on the cursor cell, right-click one to throw it away.

#macro CLIP_MAX 10        // clips kept in the strip
#macro CLIP_THUMB 64      // thumbnail pixels (square)
#macro CLIP_CELL 72       // strip cell size in GUI pixels
#macro CLIP_PAD 6         // gap between cells
#macro CLIP_STRIP_X 12    // left margin of the strip

/// @desc Stored tile z -> world z. XY tiles store z up-positive and draw at
/// world Z = -z; XZ and YZ store world Z directly.
function clip_world_z(_plane, _z)
{
    if (_plane == "XY")
    {
        return -_z;
    }
    return _z;
}

/// @desc World z -> stored tile z for a tile on this plane.
function clip_store_z(_plane, _wz)
{
    if (_plane == "XY")
    {
        return -_wz;
    }
    return _wz;
}

/// @desc Camera position, axes and lens, matching the 3D view exactly.
/// Everything needed to project a world point to window pixels.
function clip_cam_basis()
{
    var _px = cam_look_x + dcos(cam_yaw) * dcos(cam_pitch) * cam_dist;
    var _py = cam_look_y + dsin(cam_yaw) * dcos(cam_pitch) * cam_dist;
    var _pz = cam_look_z - dsin(cam_pitch) * cam_dist;

    var _fx = cam_look_x - _px;
    var _fy = cam_look_y - _py;
    var _fz = cam_look_z - _pz;
    var _flen = sqrt(_fx * _fx + _fy * _fy + _fz * _fz);
    if (_flen <= 0)
    {
        _flen = 1;
    }
    _fx /= _flen;
    _fy /= _flen;
    _fz /= _flen;

    var _rx = dcos(cam_yaw - 90);
    var _ry = dsin(cam_yaw - 90);
    var _rz = 0;

    var _ux = _ry * _fz - _rz * _fy;
    var _uy = _rz * _fx - _rx * _fz;
    var _uz = _rx * _fy - _ry * _fx;

    var _ww = max(1, window_get_width());
    var _wh = max(1, window_get_height());

    return {
        px: _px, py: _py, pz: _pz,
        fx: _fx, fy: _fy, fz: _fz,
        rx: _rx, ry: _ry, rz: _rz,
        ux: _ux, uy: _uy, uz: _uz,
        win_w: _ww,
        win_h: _wh,
        aspect: _ww / _wh,
        tan_half: tan(degtorad(FX_FOV) / 2)
    };
}

/// @desc Project a world point to window pixels. ok is false behind the eye.
function clip_project(_b, _wx, _wy, _wz)
{
    var _dx = _wx - _b.px;
    var _dy = _wy - _b.py;
    var _dz = _wz - _b.pz;

    var _vz = _dx * _b.fx + _dy * _b.fy + _dz * _b.fz;
    if (_vz <= 0.01)
    {
        return { ok: false, sx: 0, sy: 0 };
    }

    var _vx = _dx * _b.rx + _dy * _b.ry + _dz * _b.rz;
    var _vy = _dx * _b.ux + _dy * _b.uy + _dz * _b.uz;

    var _ndc_x = (_vx / _vz) / (_b.tan_half * _b.aspect);
    var _ndc_y = (_vy / _vz) / _b.tan_half;

    return {
        ok: true,
        sx: (_ndc_x * 0.5 + 0.5) * _b.win_w,
        sy: (0.5 - _ndc_y * 0.5) * _b.win_h
    };
}

/// @desc The four world-space corners of a placed tile's quad.
function clip_tile_corners(_t)
{
    var _x = _t.x + _t.off_x;
    var _y = _t.y + _t.off_y;

    if (_t.plane == "XY")
    {
        var _zw = -_t.z + _t.off_z;
        return [
            [_x, _y, _zw],
            [_x + 1, _y, _zw],
            [_x, _y + 1, _zw],
            [_x + 1, _y + 1, _zw]
        ];
    }

    var _z = _t.z + _t.off_z;
    if (_t.plane == "XZ")
    {
        return [
            [_x, _y, _z],
            [_x + 1, _y, _z],
            [_x, _y, _z + 1],
            [_x + 1, _y, _z + 1]
        ];
    }

    // YZ
    return [
        [_x, _y, _z],
        [_x, _y + 1, _z],
        [_x, _y, _z + 1],
        [_x, _y + 1, _z + 1]
    ];
}

/// @desc Keys of every placed tile whose projected quad touches this window-space
/// rectangle. Backfaces are skipped while culling is on, same as picking.
function clip_select_rect(_x0, _y0, _x1, _y1)
{
    var _rx0 = min(_x0, _x1);
    var _rx1 = max(_x0, _x1);
    var _ry0 = min(_y0, _y1);
    var _ry1 = max(_y0, _y1);

    var _b = clip_cam_basis();
    var _hits = [];
    var _names = variable_struct_get_names(global.world_tiles);

    for (var _i = 0; _i < array_length(_names); _i++)
    {
        var _t = variable_struct_get(global.world_tiles, _names[_i]);

        if (cull_on && !tile_faces_point(_t, _b.px, _b.py, _b.pz))
        {
            continue;
        }

        var _c = clip_tile_corners(_t);
        var _minx = 0;
        var _maxx = 0;
        var _miny = 0;
        var _maxy = 0;
        var _ok = true;

        for (var _k = 0; _k < 4; _k++)
        {
            var _p = clip_project(_b, _c[_k][0], _c[_k][1], _c[_k][2]);
            if (!_p.ok)
            {
                _ok = false;
                break;
            }
            if (_k == 0)
            {
                _minx = _p.sx;
                _maxx = _p.sx;
                _miny = _p.sy;
                _maxy = _p.sy;
            }
            else
            {
                _minx = min(_minx, _p.sx);
                _maxx = max(_maxx, _p.sx);
                _miny = min(_miny, _p.sy);
                _maxy = max(_maxy, _p.sy);
            }
        }

        if (!_ok)
        {
            continue;
        }

        // Touching counts: plain rectangle overlap
        if (_maxx >= _rx0 && _minx <= _rx1 && _maxy >= _ry0 && _miny <= _ry1)
        {
            array_push(_hits, _names[_i]);
        }
    }

    return _hits;
}

/// @desc Grab a square thumbnail of a window-space rectangle from the last
/// rendered frame. The square is the longer side of the rectangle, centred on
/// it and clamped to the view, so nothing is squashed.
/// Returns a struct: ok, spr, w, h, data (packed pixels for saving).
function clip_thumb_grab(_x0, _y0, _x1, _y1)
{
    var _out = {
        ok: false,
        spr: -1,
        w: CLIP_THUMB,
        h: CLIP_THUMB,
        data: ""
    };

    if (!surface_exists(application_surface))
    {
        return _out;
    }

    var _sw = surface_get_width(application_surface);
    var _sh = surface_get_height(application_surface);
    var _scale_x = _sw / max(1, window_get_width());
    var _scale_y = _sh / max(1, window_get_height());

    var _ax0 = min(_x0, _x1) * _scale_x;
    var _ax1 = max(_x0, _x1) * _scale_x;
    var _ay0 = min(_y0, _y1) * _scale_y;
    var _ay1 = max(_y0, _y1) * _scale_y;

    var _side = max(_ax1 - _ax0, _ay1 - _ay0, 8);
    _side = min(_side, _sw, _sh);

    var _cx = (_ax0 + _ax1) * 0.5;
    var _cy = (_ay0 + _ay1) * 0.5;
    var _gx = clamp(_cx - _side * 0.5, 0, _sw - _side);
    var _gy = clamp(_cy - _side * 0.5, 0, _sh - _side);

    var _thumb = surface_create(CLIP_THUMB, CLIP_THUMB);
    surface_set_target(_thumb);
    draw_clear_alpha(c_black, 1);
    gpu_set_blendenable(false);
    gpu_set_tex_filter(true);
    draw_surface_part_ext(application_surface, _gx, _gy, _side, _side, 0, 0, CLIP_THUMB / _side, CLIP_THUMB / _side, c_white, 1);
    gpu_set_blendenable(true);
    surface_reset_target();

    // Pixels kept as well as the sprite, so the clip can go in the scene file
    var _buf = buffer_create(CLIP_THUMB * CLIP_THUMB * 4, buffer_fixed, 1);
    buffer_get_surface(_buf, _thumb, 0);
    var _cmp = buffer_compress(_buf, 0, buffer_get_size(_buf));
    buffer_delete(_buf);
    if (_cmp >= 0)
    {
        _out.data = buffer_base64_encode(_cmp, 0, buffer_get_size(_cmp));
        buffer_delete(_cmp);
    }

    _out.spr = sprite_create_from_surface(_thumb, 0, 0, CLIP_THUMB, CLIP_THUMB, false, false, 0, 0);
    surface_free(_thumb);
    _out.ok = (_out.spr >= 0);
    return _out;
}

/// @desc Rebuild a thumbnail sprite from packed pixels (loading a scene).
function clip_thumb_unpack(_w, _h, _data)
{
    if (_data == "" || _w <= 0 || _h <= 0)
    {
        return -1;
    }

    var _cmp = buffer_base64_decode(_data);
    if (_cmp < 0)
    {
        return -1;
    }
    var _buf = buffer_decompress(_cmp);
    buffer_delete(_cmp);
    if (_buf < 0)
    {
        return -1;
    }
    if (buffer_get_size(_buf) < _w * _h * 4)
    {
        buffer_delete(_buf);
        return -1;
    }

    var _surf = surface_create(_w, _h);
    buffer_set_surface(_buf, _surf, 0);
    buffer_delete(_buf);
    var _spr = sprite_create_from_surface(_surf, 0, 0, _w, _h, false, false, 0, 0);
    surface_free(_surf);
    return _spr;
}

/// @desc Turn a set of tile keys into a clip and put it at the top of the strip.
/// _rect is the window-space drag rectangle the thumbnail comes from.
/// Returns the number of tiles taken.
function clip_grab(_keys, _rx0, _ry0, _rx1, _ry1)
{
    var _count = array_length(_keys);
    if (_count == 0)
    {
        return 0;
    }

    // Bounds in world space, so mixed planes stay in step with each other
    var _minx = 0;
    var _maxx = 0;
    var _miny = 0;
    var _maxy = 0;
    var _minz = 0;
    var _maxz = 0;
    var _first = true;
    var _tiles = [];

    for (var _i = 0; _i < _count; _i++)
    {
        if (!variable_struct_exists(global.world_tiles, _keys[_i]))
        {
            continue;
        }
        var _t = variable_struct_get(global.world_tiles, _keys[_i]);
        var _wz = clip_world_z(_t.plane, _t.z);

        if (_first)
        {
            _minx = _t.x;
            _maxx = _t.x;
            _miny = _t.y;
            _maxy = _t.y;
            _minz = _wz;
            _maxz = _wz;
            _first = false;
        }
        else
        {
            _minx = min(_minx, _t.x);
            _maxx = max(_maxx, _t.x);
            _miny = min(_miny, _t.y);
            _maxy = max(_maxy, _t.y);
            _minz = min(_minz, _wz);
            _maxz = max(_maxz, _wz);
        }

        // Kept for older clip data; keys now come from the offset itself
        var _koff = 0;
        var _parts = string_split(_keys[_i], ",");
        if (array_length(_parts) >= 5)
        {
            _koff = real(_parts[4]);
        }

        array_push(_tiles, {
            dx: _t.x,
            dy: _t.y,
            dz: _wz,
            plane: _t.plane,
            sub: _t.sub,
            rot: _t.rot,
            facing: _t.facing,
            nrm_x: _t.nrm_x,
            nrm_y: _t.nrm_y,
            nrm_z: _t.nrm_z,
            flip_x: _t.flip_x,
            flip_y: _t.flip_y,
            off_x: _t.off_x,
            off_y: _t.off_y,
            off_z: _t.off_z,
            koff: _koff
        });
    }

    if (array_length(_tiles) == 0)
    {
        return 0;
    }

    // Offsets from the cluster's centre cell
    var _ax = floor((_minx + _maxx) / 2);
    var _ay = floor((_miny + _maxy) / 2);
    var _az = floor((_minz + _maxz) / 2);
    for (var _i = 0; _i < array_length(_tiles); _i++)
    {
        _tiles[_i].dx -= _ax;
        _tiles[_i].dy -= _ay;
        _tiles[_i].dz -= _az;
    }

    var _thumb = clip_thumb_grab(_rx0, _ry0, _rx1, _ry1);

    clip_item_add({
        tiles: _tiles,
        thumb_spr: _thumb.spr,
        thumb_w: _thumb.w,
        thumb_h: _thumb.h,
        thumb_data: _thumb.data,
        turns: 0,      // quarter turns applied since the grab (badge only)
        mirrored: false
    });

    return array_length(_tiles);
}

/// @desc Put a clip at the top of the strip, dropping the oldest past CLIP_MAX.
function clip_item_add(_item)
{
    array_insert(global.clip_items, 0, _item);

    while (array_length(global.clip_items) > CLIP_MAX)
    {
        var _last = array_length(global.clip_items) - 1;
        var _old = global.clip_items[_last];
        if (_old.thumb_spr >= 0 && sprite_exists(_old.thumb_spr))
        {
            sprite_delete(_old.thumb_spr);
        }
        array_delete(global.clip_items, _last, 1);
    }

    // The new clip is the one in hand
    clip_held = 0;
}

/// @desc Throw a clip away.
function clip_item_remove(_index)
{
    if (_index < 0 || _index >= array_length(global.clip_items))
    {
        return;
    }

    var _item = global.clip_items[_index];
    if (_item.thumb_spr >= 0 && sprite_exists(_item.thumb_spr))
    {
        sprite_delete(_item.thumb_spr);
    }
    array_delete(global.clip_items, _index, 1);

    if (clip_held == _index)
    {
        clip_held = -1;
    }
    else if (clip_held > _index)
    {
        clip_held -= 1;
    }
}

/// @desc Stamp a clip into the world, centred on a cell of the active plane.
/// The caller pushes the undo snapshot.
/// A face landing where an opposite-facing one already sits cancels it out:
/// both go, rather than the newcomer quietly replacing it (the tile key is
/// cell + plane + decal step, so facing alone never kept them apart).
/// Returns a struct: written, cancelled.
function clip_paste(_index, _gx, _gy, _gz)
{
    var _result = { written: 0, cancelled: 0, skipped: 0 };
    if (_index < 0 || _index >= array_length(global.clip_items))
    {
        return _result;
    }

    var _item = global.clip_items[_index];
    var _anchor_z = clip_world_z(active_plane, _gz);

    for (var _i = 0; _i < array_length(_item.tiles); _i++)
    {
        var _c = _item.tiles[_i];

        // Never lay down a tile with no graphic
        if (tile_frame_is_empty(_c.sub))
        {
            _result.skipped += 1;
            continue;
        }

        var _wx = _gx + _c.dx;
        var _wy = _gy + _c.dy;
        var _wz = _anchor_z + _c.dz;
        var _zs = clip_store_z(_c.plane, _wz);

        var _key = tile_key(_wx, _wy, _zs, _c.plane, _c.off_x, _c.off_y, _c.off_z);

        // One face per place. Something already here facing the other way
        // cancels with the newcomer; facing the same way, the newcomer wins.
        if (variable_struct_exists(global.world_tiles, _key))
        {
            var _old = variable_struct_get(global.world_tiles, _key);
            if (sign(_old.facing) == -sign(_c.facing))
            {
                struct_remove(global.world_tiles, _key);
                _result.cancelled += 1;
                continue;
            }
        }

        variable_struct_set(global.world_tiles, _key, {
            x: _wx,
            y: _wy,
            z: _zs,
            plane: _c.plane,
            sub: _c.sub,
            rot: _c.rot,
            facing: _c.facing,
            nrm_x: _c.nrm_x,
            nrm_y: _c.nrm_y,
            nrm_z: _c.nrm_z,
            flip_x: _c.flip_x,
            flip_y: _c.flip_y,
            off_x: _c.off_x,
            off_y: _c.off_y,
            off_z: _c.off_z
        });
        _result.written += 1;
    }

    return _result;
}

/// @desc Draw the held clip as a ghost, centred on a cell of the active plane.
/// Call from the Draw event, inside the 3D camera.
function clip_ghost_draw(_index, _gx, _gy, _gz)
{
    if (_index < 0 || _index >= array_length(global.clip_items))
    {
        return;
    }

    var _item = global.clip_items[_index];
    var _anchor_z = clip_world_z(active_plane, _gz);

    for (var _i = 0; _i < array_length(_item.tiles); _i++)
    {
        var _c = _item.tiles[_i];
        var _wz = _anchor_z + _c.dz;
        var _zs = clip_store_z(_c.plane, _wz);
        draw_tile_quad_textured(_gx + _c.dx, _gy + _c.dy, _zs, _c.plane, c_white, _c.sub, 0.5, _c.rot, _c.facing, _c.off_x, _c.off_y, _c.off_z, _c.flip_x, _c.flip_y);
    }
}

/// @desc Strip geometry in GUI pixels. Sits under the axis readout on the left.
function clip_strip_rect()
{
    var _count = array_length(global.clip_items);
    var _h = _count * CLIP_CELL + max(0, _count - 1) * CLIP_PAD;
    return {
        x: CLIP_STRIP_X,
        y: menu_bar_h + 200,
        w: CLIP_CELL,
        h: _h,
        count: _count
    };
}

/// @desc Which clip the mouse is over (-1 for none).
function clip_strip_hover()
{
    var _r = clip_strip_rect();
    if (_r.count == 0)
    {
        return -1;
    }

    var _mx = device_mouse_x_to_gui(0);
    var _my = device_mouse_y_to_gui(0);

    if (_mx < _r.x || _mx > _r.x + _r.w)
    {
        return -1;
    }

    for (var _i = 0; _i < _r.count; _i++)
    {
        var _cy = _r.y + _i * (CLIP_CELL + CLIP_PAD);
        if (_my >= _cy && _my <= _cy + CLIP_CELL)
        {
            return _i;
        }
    }
    return -1;
}

/// @desc Strip input: left-click holds a clip, right-click throws it away.
/// Sets clip_blocks_mouse so the click never reaches the scene as well.
/// Call in the Step event, before tile placement.
function clip_strip_update()
{
    clip_blocks_mouse = false;
    clip_hover = clip_strip_hover();

    if (clip_hover < 0)
    {
        return;
    }

    clip_blocks_mouse = true;

    if (mouse_check_button_pressed(mb_left))
    {
        clip_held = clip_hover;
        tile_msg = "Holding cluster " + string(clip_hover + 1) + " - click to place it";
        tile_msg_timer = room_speed * 2;
    }

    if (mouse_check_button_pressed(mb_right))
    {
        clip_item_remove(clip_hover);
        clip_hover = clip_strip_hover();
        tile_msg = "Cluster removed";
        tile_msg_timer = room_speed * 2;
    }
}

/// @desc Draw the strip. Call from Draw GUI, under the menu bar.
function clip_strip_draw()
{
    var _r = clip_strip_rect();
    if (_r.count == 0)
    {
        return;
    }

    draw_set_font(-1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);

    for (var _i = 0; _i < _r.count; _i++)
    {
        var _item = global.clip_items[_i];
        var _cx = _r.x;
        var _cy = _r.y + _i * (CLIP_CELL + CLIP_PAD);

        // Cell backing
        draw_set_alpha(0.85);
        draw_set_colour(make_colour_rgb(24, 26, 34));
        draw_rectangle(_cx, _cy, _cx + CLIP_CELL, _cy + CLIP_CELL, false);
        draw_set_alpha(1);

        if (_item.thumb_spr >= 0 && sprite_exists(_item.thumb_spr))
        {
            var _inset = 4;
            var _size = CLIP_CELL - _inset * 2;
            var _scale = _size / max(1, sprite_get_width(_item.thumb_spr));
            var _old_filter = gpu_get_tex_filter();
            gpu_set_tex_filter(true);
            draw_sprite_ext(_item.thumb_spr, 0, _cx + _inset, _cy + _inset, _scale, _scale, 0, c_white, 1);
            gpu_set_tex_filter(_old_filter);
        }

        // Border: white when held, yellow when hovered, grey otherwise
        var _col = make_colour_rgb(90, 94, 110);
        if (_i == clip_hover)
        {
            _col = c_yellow;
        }
        if (_i == clip_held)
        {
            _col = c_white;
        }
        draw_set_colour(_col);
        draw_rectangle(_cx, _cy, _cx + CLIP_CELL, _cy + CLIP_CELL, true);

        // Tile count, bottom right of the cell
        draw_set_colour(c_white);
        var _label = string(array_length(_item.tiles));
        draw_text(_cx + CLIP_CELL - string_width(_label) - 5, _cy + CLIP_CELL - 18, _label);

        // The thumbnail is the snapshot from the grab and never turns, so say
        // how the cluster has been turned or mirrored since.
        var _badge = "";
        if (_item.turns != 0)
        {
            _badge = string(_item.turns * 90) + chr(176);
        }
        if (_item.mirrored)
        {
            if (_badge != "")
            {
                _badge += " ";
            }
            _badge += "M";
        }
        if (_badge != "")
        {
            draw_set_colour(c_yellow);
            draw_text(_cx + 5, _cy + CLIP_CELL - 18, _badge);
            draw_set_colour(c_white);
        }
    }

    draw_set_colour(c_white);
}

/// @desc Clips packed for the scene file.
function clip_serialize()
{
    var _out = [];
    for (var _i = 0; _i < array_length(global.clip_items); _i++)
    {
        var _item = global.clip_items[_i];
        array_push(_out, {
            tiles: _item.tiles,
            thumb_w: _item.thumb_w,
            thumb_h: _item.thumb_h,
            thumb_data: _item.thumb_data,
            turns: _item.turns,
            mirrored: _item.mirrored
        });
    }
    return _out;
}

/// @desc Replace the strip with clips read back from a scene file.
function clip_deserialize(_list)
{
    for (var _i = 0; _i < array_length(global.clip_items); _i++)
    {
        var _old = global.clip_items[_i];
        if (_old.thumb_spr >= 0 && sprite_exists(_old.thumb_spr))
        {
            sprite_delete(_old.thumb_spr);
        }
    }
    global.clip_items = [];
    clip_held = -1;
    clip_hover = -1;

    if (!is_array(_list))
    {
        return;
    }

    for (var _i = 0; _i < array_length(_list) && _i < CLIP_MAX; _i++)
    {
        var _src = _list[_i];
        var _w = CLIP_THUMB;
        var _h = CLIP_THUMB;
        var _data = "";
        if (variable_struct_exists(_src, "thumb_w"))
        {
            _w = _src.thumb_w;
            _h = _src.thumb_h;
            _data = _src.thumb_data;
        }

        var _turns = 0;
        var _mirrored = false;
        if (variable_struct_exists(_src, "turns"))
        {
            _turns = _src.turns;
            _mirrored = _src.mirrored;
        }

        array_push(global.clip_items, {
            tiles: _src.tiles,
            thumb_spr: clip_thumb_unpack(_w, _h, _data),
            thumb_w: _w,
            thumb_h: _h,
            thumb_data: _data,
            turns: _turns,
            mirrored: _mirrored
        });
    }
}

// ------------------------------------------------------------
//  TURNING AND MIRRORING A HELD CLUSTER
// ------------------------------------------------------------
// Both of these keep every tile on the grid and keep each tile's texture
// looking the way it did - the plane, quarter-turn and flip flags all have to
// change together for that to hold. The rules below were derived from
// draw_tile_quad_textured's own corner and UV layout and checked exhaustively
// against it for every plane, cell and orientation, so please don't "tidy"
// them by hand: rebuild them from the draw function if it ever changes.

/// @desc How a tile's plane / quarter-turn / flips come out after the cluster
/// turns 90 degrees about the vertical axis. Returns a struct.
function clip_orient_turn(_plane, _rot, _fx, _fy)
{
    if (_plane == "XY")
    {
        return { plane: "XY", rot: (_rot + 3) mod 4, fx: _fx, fy: _fy };
    }
    if (_plane == "YZ")
    {
        return { plane: "XZ", rot: _rot, fx: _fx, fy: _fy };
    }

    // XZ becomes YZ, and that wall's in-plane right axis reverses, so the
    // texture has to be mirrored locally to look the same from the front.
    if ((_rot mod 2) == 0)
    {
        return { plane: "YZ", rot: _rot, fx: !_fx, fy: _fy };
    }
    return { plane: "YZ", rot: _rot, fx: _fx, fy: !_fy };
}

/// @desc The same, for mirroring the cluster across the world X axis.
/// A YZ wall's own axes are untouched by that mirror; the others are not.
function clip_orient_mirror(_plane, _rot, _fx, _fy)
{
    if (_plane == "YZ")
    {
        return { plane: "YZ", rot: _rot, fx: _fx, fy: _fy };
    }
    if ((_rot mod 2) == 0)
    {
        return { plane: _plane, rot: _rot, fx: !_fx, fy: _fy };
    }
    return { plane: _plane, rot: _rot, fx: _fx, fy: !_fy };
}

/// @desc Re-centre a clip's tiles on their own middle cell, so it keeps
/// sitting under the cursor after being turned or mirrored.
function clip_recentre(_item)
{
    var _n = array_length(_item.tiles);
    if (_n == 0)
    {
        return;
    }

    var _minx = _item.tiles[0].dx;
    var _maxx = _minx;
    var _miny = _item.tiles[0].dy;
    var _maxy = _miny;

    for (var _i = 1; _i < _n; _i++)
    {
        _minx = min(_minx, _item.tiles[_i].dx);
        _maxx = max(_maxx, _item.tiles[_i].dx);
        _miny = min(_miny, _item.tiles[_i].dy);
        _maxy = max(_maxy, _item.tiles[_i].dy);
    }

    var _cx = floor((_minx + _maxx) / 2);
    var _cy = floor((_miny + _maxy) / 2);
    for (var _i = 0; _i < _n; _i++)
    {
        _item.tiles[_i].dx -= _cx;
        _item.tiles[_i].dy -= _cy;
    }
}

/// @desc The world direction a tile is seen from, worked out from the winding
/// draw_tile_quad_textured builds for this plane at facing >= 0:
/// XY winds toward +Z, XZ toward +Y, and YZ toward -X. That last one is the
/// odd one out, which is why "facing" cannot simply be carried across when a
/// wall changes plane - the same number means opposite sides on XZ and YZ.
function clip_visible_normal(_plane, _facing)
{
    var _s = 1;
    if (_facing < 0)
    {
        _s = -1;
    }

    if (_plane == "XY")
    {
        return [0, 0, _s];
    }
    if (_plane == "XZ")
    {
        return [0, _s, 0];
    }
    return [-_s, 0, 0];
}

/// @desc The facing value that shows a tile on _plane from direction _v.
function clip_facing_from_visible(_plane, _v)
{
    var _d = 0;
    if (_plane == "XY")
    {
        _d = _v[2];
    }
    if (_plane == "XZ")
    {
        _d = _v[1];
    }
    if (_plane == "YZ")
    {
        _d = -_v[0];
    }

    if (_d < 0)
    {
        return -1;
    }
    return 1;
}

/// @desc Keep the stored normal in step with facing (the placement code writes
/// the two the same way round).
function clip_normal_from_facing(_tile)
{
    _tile.nrm_x = 0;
    _tile.nrm_y = 0;
    _tile.nrm_z = 0;

    if (_tile.plane == "XY")
    {
        _tile.nrm_z = _tile.facing;
    }
    if (_tile.plane == "XZ")
    {
        _tile.nrm_y = _tile.facing;
    }
    if (_tile.plane == "YZ")
    {
        _tile.nrm_x = _tile.facing;
    }
}

/// @desc Turn a clip 90 degrees about the vertical axis, in place.
function clip_turn(_index)
{
    if (_index < 0 || _index >= array_length(global.clip_items))
    {
        return;
    }
    var _item = global.clip_items[_index];

    for (var _i = 0; _i < array_length(_item.tiles); _i++)
    {
        var _t = _item.tiles[_i];

        // The side this tile is seen from, turned as a direction
        var _v = clip_visible_normal(_t.plane, _t.facing);
        var _seen = [_v[1], -_v[0], _v[2]];

        // Cell: (x, y) -> (y, -x - 1), and -x for a YZ wall, whose x is a
        // plane position rather than a one-cell span.
        var _ox = _t.dx;
        var _oy = _t.dy;
        _t.dx = _oy;
        if (_t.plane == "YZ")
        {
            _t.dy = -_ox;
        }
        else
        {
            _t.dy = -_ox - 1;
        }

        // The decal offset turns as a direction too
        var _fx2 = _t.off_x;
        var _fy2 = _t.off_y;
        _t.off_x = _fy2;
        _t.off_y = -_fx2;

        var _o = clip_orient_turn(_t.plane, _t.rot, _t.flip_x, _t.flip_y);
        _t.plane = _o.plane;
        _t.rot = _o.rot;
        _t.flip_x = _o.fx;
        _t.flip_y = _o.fy;

        _t.facing = clip_facing_from_visible(_t.plane, _seen);
        clip_normal_from_facing(_t);
    }

    clip_recentre(_item);
    _item.turns = (_item.turns + 1) mod 4;
}

/// @desc Mirror a clip across the world X axis, in place.
function clip_mirror(_index)
{
    if (_index < 0 || _index >= array_length(global.clip_items))
    {
        return;
    }
    var _item = global.clip_items[_index];

    for (var _i = 0; _i < array_length(_item.tiles); _i++)
    {
        var _t = _item.tiles[_i];

        var _v = clip_visible_normal(_t.plane, _t.facing);
        var _seen = [-_v[0], _v[1], _v[2]];

        if (_t.plane == "YZ")
        {
            _t.dx = -_t.dx;
        }
        else
        {
            _t.dx = -_t.dx - 1;
        }

        _t.off_x = -_t.off_x;

        var _o = clip_orient_mirror(_t.plane, _t.rot, _t.flip_x, _t.flip_y);
        _t.plane = _o.plane;
        _t.rot = _o.rot;
        _t.flip_x = _o.fx;
        _t.flip_y = _o.fy;

        _t.facing = clip_facing_from_visible(_t.plane, _seen);
        clip_normal_from_facing(_t);
    }

    clip_recentre(_item);
    _item.mirrored = !_item.mirrored;
}

/// @desc Mirror across the world Y axis: the X mirror plus a half turn.
/// (Checked against the draw function as its own transform.)
function clip_mirror_y(_index)
{
    clip_mirror(_index);
    clip_turn(_index);
    clip_turn(_index);

    // Those two turns were bookkeeping for the mirror, not the user's doing
    var _item = global.clip_items[_index];
    _item.turns = (_item.turns + 2) mod 4;
}

/// @desc X on a held cluster: mirror along whichever world axis reads as
/// left-right on screen from where the camera is now.
function clip_mirror_on_screen(_index)
{
    if (abs(dsin(cam_yaw)) >= abs(dcos(cam_yaw)))
    {
        clip_mirror(_index);
    }
    else
    {
        clip_mirror_y(_index);
    }
}

// ============================================================
//  WIREFRAME OVERLAY (F)
// ============================================================
// Outlines every placed tile, drawn through the scene so nothing can hide:
//   cyan    - an ordinary tile
//   orange  - a tile whose back is toward you (culled when culling is on)
//   magenta - a tile whose graphic is completely transparent, crossed through.
//             These are invisible in the normal view but are still real tiles:
//             they get selected, copied, and pasted over things like any other.

/// @desc Work out which frames of the active tileset are completely
/// transparent. Cached; only redone when the tileset sprite changes.
/// Call in the Step event (it draws into a surface).
function wire_refresh_empty()
{
    var _spr = global.tile_sprite;
    if (!sprite_exists(_spr))
    {
        wire_empty = [];
        wire_empty_spr = -1;
        wire_empty_count = -1;
        return;
    }

    var _n = sprite_get_number(_spr);
    if (_spr == wire_empty_spr && _n == wire_empty_count)
    {
        return;
    }

    var _w = sprite_get_width(_spr);
    var _h = sprite_get_height(_spr);
    var _size = _w * _h * 4;
    var _surf = surface_create(_w, _h);
    var _buf = buffer_create(_size, buffer_fixed, 1);
    var _xo = sprite_get_xoffset(_spr);
    var _yo = sprite_get_yoffset(_spr);

    wire_empty = array_create(_n, false);

    for (var _i = 0; _i < _n; _i++)
    {
        // Copy the frame's pixels exactly, alpha and all
        surface_set_target(_surf);
        draw_clear_alpha(c_black, 0);
        gpu_set_blendenable(false);
        gpu_set_alphatestenable(false);
        draw_sprite(_spr, _i, _xo, _yo);
        gpu_set_blendenable(true);
        gpu_set_alphatestenable(true);
        surface_reset_target();

        buffer_get_surface(_buf, _surf, 0);

        // Empty means not one pixel with any alpha (which way up the surface
        // came out doesn't matter for that)
        var _any = false;
        for (var _p = 3; _p < _size; _p += 4)
        {
            if (buffer_peek(_buf, _p, buffer_u8) > 0)
            {
                _any = true;
                break;
            }
        }
        wire_empty[_i] = !_any;
    }

    buffer_delete(_buf);
    surface_free(_surf);

    wire_empty_spr = _spr;
    wire_empty_count = _n;
}

/// @desc True when this tile's graphic is completely transparent.
function wire_tile_is_empty(_t)
{
    var _s = _t.sub;
    if (_s < 0 || _s >= array_length(wire_empty))
    {
        return false;
    }
    return wire_empty[_s];
}

/// @desc One line into the open vertex buffer.
function wire_edge(_a, _b, _col)
{
    vertex_position_3d(global.v_buffer, _a[0], _a[1], _a[2]);
    vertex_color(global.v_buffer, _col, 1);
    vertex_position_3d(global.v_buffer, _b[0], _b[1], _b[2]);
    vertex_color(global.v_buffer, _col, 1);
}

/// @desc Draw the overlay. Call from the Draw event, inside the 3D camera,
/// after the tiles. Also counts the invisible tiles for the legend.
function wire_draw()
{
    wire_invisible = 0;
    wire_backfacing = 0;

    var _names = variable_struct_get_names(global.world_tiles);
    var _n = array_length(_names);
    if (_n == 0)
    {
        return;
    }

    var _b = clip_cam_basis();
    var _col_ok = make_colour_rgb(80, 220, 255);
    var _col_back = make_colour_rgb(255, 150, 40);
    var _col_empty = make_colour_rgb(255, 40, 220);

    gpu_set_ztestenable(false);
    gpu_set_cullmode(cull_noculling);

    vertex_begin(global.v_buffer, global.v_format);
    for (var _i = 0; _i < _n; _i++)
    {
        var _t = variable_struct_get(global.world_tiles, _names[_i]);
        var _c = clip_tile_corners(_t);   // TL, TR, BL, BR
        var _empty = wire_tile_is_empty(_t);

        var _col = _col_ok;
        if (_empty)
        {
            _col = _col_empty;
            wire_invisible += 1;
        }
        else if (!tile_faces_point(_t, _b.px, _b.py, _b.pz))
        {
            _col = _col_back;
            wire_backfacing += 1;
        }

        wire_edge(_c[0], _c[1], _col);
        wire_edge(_c[1], _c[3], _col);
        wire_edge(_c[3], _c[2], _col);
        wire_edge(_c[2], _c[0], _col);

        // Cross the invisible ones through so they can't be missed
        if (_empty)
        {
            wire_edge(_c[0], _c[3], _col);
            wire_edge(_c[1], _c[2], _col);
        }
    }
    vertex_end(global.v_buffer);
    vertex_submit(global.v_buffer, pr_linelist, -1);

    gpu_set_ztestenable(true);
}

/// @desc Legend in the bottom-left corner. Call from Draw GUI.
function wire_legend_draw()
{
    var _x = 16;
    var _y = display_get_gui_height() - 78;

    draw_set_font(-1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);

    draw_set_alpha(0.75);
    draw_set_colour(make_colour_rgb(20, 22, 30));
    draw_rectangle(_x - 8, _y - 8, _x + 420, _y + 66, false);
    draw_set_alpha(1);

    draw_set_colour(make_colour_rgb(80, 220, 255));
    draw_text(_x, _y, "WIREFRAME (F)   cyan: tile");
    draw_set_colour(make_colour_rgb(255, 150, 40));
    draw_text(_x, _y + 18, "orange: back toward you   (" + string(wire_backfacing) + ")");
    draw_set_colour(make_colour_rgb(255, 40, 220));
    draw_text(_x, _y + 36, "magenta, crossed: empty graphic - invisible   (" + string(wire_invisible) + ")");
    draw_set_colour(c_white);
}

// ============================================================
//  EMPTY-GRAPHIC TILES: GUARD, WARNING AND CLEAN-UP
// ============================================================
// A tile whose frame is fully transparent (0,0,0,0 everywhere) can't be seen,
// but it is still a real tile: it gets selected, copied, and pasted over
// visible ones. So such tiles are never placed or pasted, any already in the
// scene are counted and flagged, and one click removes them.
// Uses the same per-frame table as the wireframe (wire_refresh_empty).

/// @desc True when frame _sub of the active tileset is completely transparent.
function tile_frame_is_empty(_sub)
{
    if (_sub < 0 || _sub >= array_length(wire_empty))
    {
        return false;
    }
    return wire_empty[_sub];
}

/// @desc How many placed tiles use an empty frame right now.
function world_count_invisible()
{
    var _names = variable_struct_get_names(global.world_tiles);
    var _count = 0;
    for (var _i = 0; _i < array_length(_names); _i++)
    {
        var _t = variable_struct_get(global.world_tiles, _names[_i]);
        if (tile_frame_is_empty(_t.sub))
        {
            _count += 1;
        }
    }
    return _count;
}

/// @desc Remove every placed tile that uses an empty frame. The caller pushes
/// the undo snapshot. Returns how many went.
function world_remove_invisible()
{
    wire_refresh_empty();

    var _names = variable_struct_get_names(global.world_tiles);
    var _removed = 0;
    for (var _i = 0; _i < array_length(_names); _i++)
    {
        var _t = variable_struct_get(global.world_tiles, _names[_i]);
        if (tile_frame_is_empty(_t.sub))
        {
            struct_remove(global.world_tiles, _names[_i]);
            _removed += 1;
        }
    }

    invisible_count = 0;
    invisible_recount = 0;
    return _removed;
}

/// @desc Geometry of the warning bar (GUI pixels), bottom centre.
function invisible_warn_rect()
{
    draw_set_font(-1);
    var _msg = invisible_warn_text();
    var _btn_w = string_width("Clean up") + 28;
    var _w = string_width(_msg) + 24 + _btn_w + 16;
    var _h = 34;
    var _x = floor((display_get_gui_width() - _w) * 0.5);
    var _y = display_get_gui_height() - 70;
    return {
        x: _x,
        y: _y,
        w: _w,
        h: _h,
        bx: _x + _w - _btn_w - 8,
        by: _y + 5,
        bw: _btn_w,
        bh: _h - 10
    };
}

/// @desc The warning line itself.
function invisible_warn_text()
{
    var _noun = " tiles have";
    if (invisible_count == 1)
    {
        _noun = " tile has";
    }
    return string(invisible_count) + _noun + " no graphic (fully transparent) - they can't be seen but can overwrite others.  F shows them.";
}

/// @desc Keep the count fresh and handle the Clean up button. Call in the
/// Step event after clip_strip_update(); it claims the mouse through
/// clip_blocks_mouse while over the bar, so the click never reaches the scene.
function invisible_warn_update()
{
    // Recount a few times a second, not every frame
    invisible_recount -= 1;
    if (invisible_recount <= 0)
    {
        invisible_count = world_count_invisible();
        invisible_recount = 20;
    }

    invisible_btn_hover = false;
    if (invisible_count <= 0)
    {
        return;
    }

    var _r = invisible_warn_rect();
    var _mx = device_mouse_x_to_gui(0);
    var _my = device_mouse_y_to_gui(0);

    if (_mx >= _r.x && _mx <= _r.x + _r.w && _my >= _r.y && _my <= _r.y + _r.h)
    {
        clip_blocks_mouse = true; // the bar owns the mouse, same as the clip strip
    }

    if (_mx >= _r.bx && _mx <= _r.bx + _r.bw && _my >= _r.by && _my <= _r.by + _r.bh)
    {
        invisible_btn_hover = true;
        if (mouse_check_button_pressed(mb_left))
        {
            undo_push_snapshot();
            var _gone = world_remove_invisible();
            tile_msg = "Removed " + string(_gone) + " invisible tiles";
            tile_msg_timer = room_speed * 3;
        }
    }
}

/// @desc Draw the warning bar. Call from Draw GUI.
function invisible_warn_draw()
{
    if (invisible_count <= 0)
    {
        return;
    }

    var _r = invisible_warn_rect();

    draw_set_font(-1);
    draw_set_valign(fa_middle);

    draw_set_alpha(0.9);
    draw_set_colour(make_colour_rgb(60, 16, 56));
    draw_rectangle(_r.x, _r.y, _r.x + _r.w, _r.y + _r.h, false);
    draw_set_alpha(1);
    draw_set_colour(make_colour_rgb(255, 40, 220));
    draw_rectangle(_r.x, _r.y, _r.x + _r.w, _r.y + _r.h, true);

    draw_set_halign(fa_left);
    draw_set_colour(c_white);
    draw_text(_r.x + 12, _r.y + _r.h * 0.5, invisible_warn_text());

    // Clean up button
    var _fill = make_colour_rgb(150, 30, 130);
    if (invisible_btn_hover)
    {
        _fill = make_colour_rgb(210, 50, 185);
    }
    draw_set_colour(_fill);
    draw_rectangle(_r.bx, _r.by, _r.bx + _r.bw, _r.by + _r.bh, false);
    draw_set_colour(c_white);
    draw_rectangle(_r.bx, _r.by, _r.bx + _r.bw, _r.by + _r.bh, true);
    draw_set_halign(fa_center);
    draw_text(_r.bx + _r.bw * 0.5, _r.by + _r.bh * 0.5, "Clean up");

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}
