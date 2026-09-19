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
