/// @desc Raycast every placed tile and return the nearest one the ray hits.
/// Each tile is tested against its OWN plane, so a ray finds floors and walls
/// alike. Used by the Shift depth match and by Alt+click tile picking.
/// Returns a struct, always fully populated:
///   found - true when a tile was hit
///   key   - its key in global.world_tiles ("" when nothing was hit)
///   tile  - the tile struct itself (undefined when nothing was hit)
///   t     - distance along the ray
///   hx/hy/hz - the hit point, with the tile's decal offset taken back out
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
    var _hx = 0;
    var _hy = 0;
    var _hz = 0;

    for (var _i = 0; _i < array_length(_names); _i++)
    {
        var _t = variable_struct_get(global.world_tiles, _names[_i]);

        var _hit_ok = false;
        var _tt = 0;

        if (_t.plane == "XY")
        {
            // Drawn at world Z = -z, plus its decal offset
            if (abs(_rz) > 0.0001)
            {
                _tt = (-_t.z + _t.off_z - _oz) / _rz;
                _hx = _ox + _rx * _tt - _t.off_x;
                _hy = _oy + _ry * _tt - _t.off_y;
                _hz = -_t.z;
                if (_hx >= _t.x && _hx < _t.x + 1 && _hy >= _t.y && _hy < _t.y + 1)
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
                if (_hx >= _t.x && _hx < _t.x + 1 && _hz >= _t.z && _hz < _t.z + 1)
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
                if (_hy >= _t.y && _hy < _t.y + 1 && _hz >= _t.z && _hz < _t.z + 1)
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
