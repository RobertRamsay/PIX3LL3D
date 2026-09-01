function brush_rotate_cw(_subs, _cols, _rows)
{
    // Rotate a row-major cols x rows grid 90° clockwise.
    // Result is rows x cols. New[r][c] = Old[rows-1-c][r].
    var _new = array_create(_cols * _rows);
    var _new_cols = _rows;
    var _new_rows = _cols;

    for (var _r = 0; _r < _new_rows; _r++)
    {
        for (var _c = 0; _c < _new_cols; _c++)
        {
            var _src_r = _rows - 1 - _c;
            var _src_c = _r;
            _new[_r * _new_cols + _c] = _subs[_src_r * _cols + _src_c];
        }
    }

    return { subs: _new, cols: _new_cols, rows: _new_rows };
}