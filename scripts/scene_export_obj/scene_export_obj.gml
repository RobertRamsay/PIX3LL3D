function scene_export_obj(_path)
{
    var _keys = struct_get_names(global.world_tiles);
    var _key_count = array_length(_keys);

    if (_key_count == 0)
    {
        show_debug_message("OBJ export: no tiles to export.");
        return false;
    }

    // --- Derive sibling paths from the chosen .obj path ---
    var _dir = filename_dir(_path);
    var _name = filename_name(_path);
    var _base = string_copy(_name, 1, string_length(_name) - string_length(filename_ext(_name)));
    var _mtl_name = _base + ".mtl";
    var _png_name = _base + "_atlas.png";
    var _mtl_path = _dir + "\\" + _mtl_name;
    var _png_path = _dir + "\\" + _png_name;

    // --- Plan the atlas layout, recording each frame's exact pixel rect ---
    var _frames = sprite_get_number(global.tile_sprite);
    var _cell_w = sprite_get_width(global.tile_sprite);
    var _cell_h = sprite_get_height(global.tile_sprite);

    var _cols = ceil(sqrt(_frames));
    var _rows = ceil(_frames / _cols);

    // The atlas is exactly this many pixels — one integer, reused everywhere
    var _atlas_w = _cols * _cell_w;
    var _atlas_h = _rows * _cell_h;

    // Record each frame's pixel rectangle as we lay it out
    var _frame_px = array_create(_frames);

    var _f = 0;
    repeat (_frames)
    {
        var _col = _f mod _cols;
        var _row = _f div _cols;

        var _px = _col * _cell_w;
        var _py = _row * _cell_h;

        _frame_px[_f] = {
            left:   _px,
            top:    _py,
            right:  _px + _cell_w,
            bottom: _py + _cell_h
        };

        _f += 1;
    }

    // --- Render the atlas using those exact recorded rects ---
    var _surf = surface_create(_atlas_w, _atlas_h);
    surface_set_target(_surf);
    draw_clear_alpha(c_black, 0);

    var _g = 0;
    repeat (_frames)
    {
        var _r = _frame_px[_g];
        draw_sprite(global.tile_sprite, _g, _r.left + sprite_get_xoffset(global.tile_sprite), _r.top + sprite_get_yoffset(global.tile_sprite));
        _g += 1;
    }

    surface_reset_target();
    surface_save(_surf, _png_path);
    surface_free(_surf);

    // --- Write the .mtl (one material, the atlas) ---
    var _mtl_str = "newmtl tile_atlas\n";
    _mtl_str += "Ka 1.0 1.0 1.0\n";
    _mtl_str += "Kd 1.0 1.0 1.0\n";
    _mtl_str += "d 1.0\n";
    _mtl_str += "illum 1\n";
    _mtl_str += "map_Kd " + _png_name + "\n";

    var _mbuf = buffer_create(string_byte_length(_mtl_str) + 1, buffer_grow, 1);
    buffer_write(_mbuf, buffer_text, _mtl_str);
    buffer_save(_mbuf, _mtl_path);
    buffer_delete(_mbuf);

    // --- Build the OBJ ---
    var _str = "# Exported from GameMaker tile editor\n";
    _str += "mtllib " + _mtl_name + "\n";
    _str += "usemtl tile_atlas\n";

    // Exact cell boundaries — no inset. Corners map to corners.
    var _half_u = 0;
    var _half_v = 0;

    // GML's string() truncates reals to 2 decimals — fatal for UVs.
    // Format with full precision instead.
    var _fmt = function(_v) {
        return string_format(_v, 0, 8);
    };

    // --- WINDING LOOKUP, one entry per direction (plane + facing sign) ---
    // Each value is the corner order for the face. The four corners are
    // 0,1,2,3 (a,b,c,d). Flip a direction by swapping its array to the
    // reverse, e.g. [3,2,1,0] <-> [0,1,2,3]. Tune these freely.
    var _winding = {
        XY_pos: [3, 2, 1, 0],   // corrected
        XY_neg: [3, 2, 1, 0],   // corrected
        XZ_pos: [3, 2, 1, 0],
        XZ_neg: [0, 1, 2, 3],
        YZ_pos: [0, 1, 2, 3],   // corrected
        YZ_neg: [3, 2, 1, 0]    // corrected
    };

    var _vert_index = 1;

    var _i = 0;
    repeat (_key_count)
    {
        var _tile = global.world_tiles[$ _keys[_i]];

        var _x = _tile.x + _tile.off_x;
        var _y = _tile.y + _tile.off_y;
        var _z = _tile.z + _tile.off_z;
        var _plane = _tile.plane;
        var _sub = _tile.sub;
        var _rot = _tile.rot;

        // --- Position corners (Y/Z swapped on write for Y-up) ---
        var _v0_x = 0;
        var _v0_y = 0;
        var _v0_z = 0;
        var _v1_x = 0;
        var _v1_y = 0;
        var _v1_z = 0;
        var _v2_x = 0;
        var _v2_y = 0;
        var _v2_z = 0;
        var _v3_x = 0;
        var _v3_y = 0;
        var _v3_z = 0;

        switch (_plane)
        {
            case "XY":
                _v0_x = _x;       _v0_y = _y;       _v0_z = _z;
                _v1_x = _x + 1;   _v1_y = _y;       _v1_z = _z;
                _v2_x = _x + 1;   _v2_y = _y + 1;   _v2_z = _z;
                _v3_x = _x;       _v3_y = _y + 1;   _v3_z = _z;
            break;

            case "XZ":
                _v0_x = _x;       _v0_y = _y;       _v0_z = _z;
                _v1_x = _x + 1;   _v1_y = _y;       _v1_z = _z;
                _v2_x = _x + 1;   _v2_y = _y;       _v2_z = _z + 1;
                _v3_x = _x;       _v3_y = _y;       _v3_z = _z + 1;
            break;

            case "YZ":
                _v0_x = _x;       _v0_y = _y + 1;   _v0_z = _z;
                _v1_x = _x;       _v1_y = _y;       _v1_z = _z;
                _v2_x = _x;       _v2_y = _y;       _v2_z = _z + 1;
                _v3_x = _x;       _v3_y = _y + 1;   _v3_z = _z + 1;
            break;
        }

        // Up-axis (slot 2) sign. XY base needs the opposite Z sign to the
        // walls so it sits at the bottom of them, not below.
        var _zs = (_plane == "XY") ? 1 : -1;

        _str += "v " + _fmt(_v0_x) + " " + _fmt(_zs * _v0_z) + " " + _fmt(_v0_y) + "\n";
        _str += "v " + _fmt(_v1_x) + " " + _fmt(_zs * _v1_z) + " " + _fmt(_v1_y) + "\n";
        _str += "v " + _fmt(_v2_x) + " " + _fmt(_zs * _v2_z) + " " + _fmt(_v2_y) + "\n";
        _str += "v " + _fmt(_v3_x) + " " + _fmt(_zs * _v3_z) + " " + _fmt(_v3_y) + "\n";

        // --- UV box from the recorded pixel rect, divided by true atlas size ---
        // Clamp to the active sheet's frame count: tiles placed from a
        // different tileset may hold a sub index that no longer exists.
        if (_sub < 0 || _sub >= _frames)
        {
            _sub = 0;
        }
        var _r = _frame_px[_sub];

        var _u0 = (_r.left / _atlas_w) + _half_u;
        var _u1 = (_r.right / _atlas_w) - _half_u;

        // OBJ V is bottom-up; surface is top-down, so flip V
        var _v_top = (1 - (_r.top / _atlas_h)) - _half_v;
        var _v_bot = (1 - (_r.bottom / _atlas_h)) + _half_v;

        // Four UV corners matching vertex order v0,v1,v2,v3
        // V flipped per-tile: top/bottom swapped
        var _uv_x = [_u0, _u1, _u1, _u0];
        var _uv_y = [_v_top, _v_top, _v_bot, _v_bot];

        // XY plane reads V the other way — reverse it for XY tiles only
        if (_plane == "XY")
        {
            _uv_y = [_v_bot, _v_bot, _v_top, _v_top];
        }

        // YZ horizontal (U) runs opposite to the other planes — mirror it
        // so YZ tiles read 12/34 not 21/43.
        if (_plane == "YZ")
        {
            var _mir0 = _uv_x[0];
            var _mir1 = _uv_x[1];
            var _mir2 = _uv_x[2];
            var _mir3 = _uv_x[3];
            _uv_x[0] = _mir1;
            _uv_x[1] = _mir0;
            _uv_x[2] = _mir3;
            _uv_x[3] = _mir2;
        }

        // --- Bake horizontal flip (X) ---
        if (_tile.flip_x == true)
        {
            var _tmp_x0 = _uv_x[0];
            var _tmp_x1 = _uv_x[1];
            var _tmp_x2 = _uv_x[2];
            var _tmp_x3 = _uv_x[3];
            _uv_x[0] = _tmp_x1;
            _uv_x[1] = _tmp_x0;
            _uv_x[2] = _tmp_x3;
            _uv_x[3] = _tmp_x2;
        }

        // --- Bake vertical flip (Y) ---
        if (_tile.flip_y == true)
        {
            var _tmp_y0 = _uv_y[0];
            var _tmp_y1 = _uv_y[1];
            var _tmp_y2 = _uv_y[2];
            var _tmp_y3 = _uv_y[3];
            _uv_y[0] = _tmp_y3;
            _uv_y[1] = _tmp_y2;
            _uv_y[2] = _tmp_y1;
            _uv_y[3] = _tmp_y0;
        }

        // --- Bake rotation (R), 90-degree steps, by rolling the corner order ---
        var _steps = _rot mod 4;
        repeat (_steps)
        {
            var _roll_x0 = _uv_x[3];
            var _roll_x1 = _uv_x[0];
            var _roll_x2 = _uv_x[1];
            var _roll_x3 = _uv_x[2];
            _uv_x[0] = _roll_x0;
            _uv_x[1] = _roll_x1;
            _uv_x[2] = _roll_x2;
            _uv_x[3] = _roll_x3;

            var _roll_y0 = _uv_y[3];
            var _roll_y1 = _uv_y[0];
            var _roll_y2 = _uv_y[1];
            var _roll_y3 = _uv_y[2];
            _uv_y[0] = _roll_y0;
            _uv_y[1] = _roll_y1;
            _uv_y[2] = _roll_y2;
            _uv_y[3] = _roll_y3;
        }

        // --- Normal: read the stored vector verbatim, apply the SAME
        // coordinate transform as positions (X kept, world Z -> slot 2 negated,
        // world Y -> slot 3 kept). No per-plane reconstruction. ---
        // Prefer the stored normal vector. If absent (tile placed before
        // nrm_* existed, or loaded from old save), reconstruct it from
        // facing + plane so it still points the camera-facing way.
        var _wn_x = 0;
        var _wn_y = 0;
        var _wn_z = 0;

        if (variable_struct_exists(_tile, "nrm_x"))
        {
            _wn_x = _tile.nrm_x;
            _wn_y = _tile.nrm_y;
            _wn_z = _tile.nrm_z;
        }
        else
        {
            var _fb = variable_struct_exists(_tile, "facing") ? _tile.facing : 1;
            if (_plane == "XY") { _wn_z = _fb; }
            if (_plane == "XZ") { _wn_y = _fb; }
            if (_plane == "YZ") { _wn_x = _fb; }
        }

        var _nx = _wn_x;
        var _ny = -_wn_z;
        var _nz = _wn_y;

        _str += "vn " + _fmt(_nx) + " " + _fmt(_ny) + " " + _fmt(_nz) + "\n";

        _str += "vt " + _fmt(_uv_x[0]) + " " + _fmt(_uv_y[0]) + "\n";
        _str += "vt " + _fmt(_uv_x[1]) + " " + _fmt(_uv_y[1]) + "\n";
        _str += "vt " + _fmt(_uv_x[2]) + " " + _fmt(_uv_y[2]) + "\n";
        _str += "vt " + _fmt(_uv_x[3]) + " " + _fmt(_uv_y[3]) + "\n";
        // --- Face referencing position/UV/normal triples (v/vt/vn) ---
        var _a = _vert_index;
        var _b = _vert_index + 1;
        var _c = _vert_index + 2;
        var _d = _vert_index + 3;

        var _n = _i + 1; // one normal per tile, shared by all four corners

        // Build the direction key: plane + facing sign.
        var _fc = variable_struct_exists(_tile, "facing") ? _tile.facing : 1;
        var _dir_key = _plane + ((_fc < 0) ? "_neg" : "_pos");

        // Look up the corner order for this direction.
        var _order = _winding[$ _dir_key];

        // The four corner vertex indices in array form, indexed by _order.
        var _corner = [_a, _b, _c, _d];

        var _o0 = _corner[_order[0]];
        var _o1 = _corner[_order[1]];
        var _o2 = _corner[_order[2]];
        var _o3 = _corner[_order[3]];

        _str += "f " + string(_o0) + "/" + string(_o0) + "/" + string(_n)
              + " " + string(_o1) + "/" + string(_o1) + "/" + string(_n)
              + " " + string(_o2) + "/" + string(_o2) + "/" + string(_n)
              + " " + string(_o3) + "/" + string(_o3) + "/" + string(_n) + "\n";
        _vert_index += 4;

        _i += 1;
    }

    var _buf = buffer_create(string_byte_length(_str) + 1, buffer_grow, 1);
    buffer_write(_buf, buffer_text, _str);
    buffer_save(_buf, _path);
    buffer_delete(_buf);

    show_debug_message("OBJ export: wrote " + string(_key_count) + " tiles, atlas " + string(_atlas_w) + "x" + string(_atlas_h) + "px to " + _path);
    return true;
}