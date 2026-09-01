function draw_tile_quad_textured(_x, _y, _z, _plane, _color, _sub, _alpha = 1, _rot = 0, _facing = 1, _ox = 0, _oy = 0, _oz = 0, _flip_x = false, _flip_y = false) {
    // Clamp sub to the active tileset's frame range
    var _frame_count = sprite_get_number(global.tile_sprite);
    if (_sub < 0 || _sub >= _frame_count) {
        _sub = 0;
    }
    var _tex = sprite_get_texture(global.tile_sprite, _sub);
    // UV rect of this sub-image on its texture page
    var _uvs = sprite_get_uvs(global.tile_sprite, _sub);
    var _u0 = _uvs[0];
    var _v0 = _uvs[3]; // swap V extents to correct upside-down mapping
    var _u1 = _uvs[2];
    var _v1 = _uvs[1];

    // Mirror the UV rect for flips (swap extents)
    if (_flip_x) {
        var _ut = _u0; _u0 = _u1; _u1 = _ut;
    }
    if (_flip_y) {
        var _vt = _v0; _v0 = _v1; _v1 = _vt;
    }

    // Corner UVs in quad-local order: TL, TR, BL, BR
    // Rotate the assignment of sheet corners by _rot * 90 degrees
    var _c = [[_u0, _v0], [_u1, _v0], [_u0, _v1], [_u1, _v1]];
    var _r = _rot mod 4;
    var _tl, _tr, _bl, _br;
    if (_r == 0)      { _tl = _c[0]; _tr = _c[1]; _bl = _c[2]; _br = _c[3]; }
    else if (_r == 1) { _tl = _c[2]; _tr = _c[0]; _bl = _c[3]; _br = _c[1]; }
    else if (_r == 2) { _tl = _c[3]; _tr = _c[2]; _bl = _c[1]; _br = _c[0]; }
    else              { _tl = _c[1]; _tr = _c[3]; _bl = _c[0]; _br = _c[2]; }

    // Per-corner UV components used below
    var _tlu = _tl[0]; var _tlv = _tl[1];
    var _tru = _tr[0]; var _trv = _tr[1];
    var _blu = _bl[0]; var _blv = _bl[1];
    var _bru = _br[0]; var _brv = _br[1];

    vertex_begin(global.v_buffer_tex, global.v_format_tex);

    var _x2 = _x + 1;
    var _y2 = _y + 1;
    var _z2 = _z + 1;

    var _zoff = -_z - 0.01;

    // Build the four quad corners as [px, py, pz, u, v] per plane.
    // Corner roles: TL, TR, BL, BR
    var _pTL, _pTR, _pBL, _pBR;
    if (_plane == "XY") {
        _pTL = [_x,  _y,  _zoff, _tlu, _tlv];
        _pTR = [_x2, _y,  _zoff, _tru, _trv];
        _pBL = [_x,  _y2, _zoff, _blu, _blv];
        _pBR = [_x2, _y2, _zoff, _bru, _brv];
    }
    else if (_plane == "XZ") {
        _pTL = [_x,  _y, _z2, _tlu, _tlv];
        _pTR = [_x2, _y, _z2, _tru, _trv];
        _pBL = [_x,  _y, _z,  _blu, _blv];
        _pBR = [_x2, _y, _z,  _bru, _brv];
    }
    else { // YZ
        _pTL = [_x, _y,  _z2, _tlu, _tlv];
        _pTR = [_x, _y2, _z2, _tru, _trv];
        _pBL = [_x, _y,  _z,  _blu, _blv];
        _pBR = [_x, _y2, _z,  _bru, _brv];
    }

    // Two triangles. Forward winding (facing >= 0): TL,TR,BL  /  TR,BR,BL
    // Reversed winding (facing < 0): swap 2nd and 3rd of each triangle.
    var _tris;
    if (_facing >= 0) {
        _tris = [_pTL, _pTR, _pBL,  _pTR, _pBR, _pBL];
    } else {
        _tris = [_pTL, _pBL, _pTR,  _pTR, _pBL, _pBR];
    }

    for (var _vi = 0; _vi < 6; _vi++) {
        var _vtx = _tris[_vi];
        vertex_position_3d(global.v_buffer_tex, _vtx[0] + _ox, _vtx[1] + _oy, _vtx[2] + _oz);
        vertex_texcoord(global.v_buffer_tex, _vtx[3], _vtx[4]);
        vertex_color(global.v_buffer_tex, _color, _alpha);
    }
    vertex_end(global.v_buffer_tex);
    vertex_submit(global.v_buffer_tex, pr_trianglelist, _tex);
}