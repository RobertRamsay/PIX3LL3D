function scene_save(_path) {
    // Envelope: tileset metadata + the tile data. Old saves were a bare
    // tiles struct; load handles both shapes.
    // A custom sheet travels inside the file (compressed pixels), so a scene
    // keeps its own art even when the source PNG moves, is renamed, was never
    // saved, or the scene goes to somebody else.
    var _sheet = {
        ok: false,
        w: 0,
        h: 0,
        cell: 0,
        cols: 0,
        data: ""
    };
    if (global.tile_is_custom) {
        _sheet = tileset_sheet_data(palette_cols);
    }

    var _envelope = {
        format: 3,
        tileset: {
            is_custom: global.tile_is_custom,
            path: global.tile_custom_path,
            cell: global.tile_cell,
            sheet_w: _sheet.w,
            sheet_h: _sheet.h,
            sheet_cell: _sheet.cell,
            sheet_cols: _sheet.cols,
            sheet_data: _sheet.data
        },
        tiles: global.world_tiles,
        clips: clip_serialize()
    };

    var _str = json_stringify(_envelope);
    var _buf = buffer_create(string_byte_length(_str) + 1, buffer_grow, 1);
    buffer_write(_buf, buffer_string, _str);
    buffer_save(_buf, _path);
    buffer_delete(_buf);
}

function scene_load(_path) {
    if (!file_exists(_path)) {
        return false;
    }
    var _buf = buffer_load(_path);
    if (_buf < 0) {
        return false;
    }
    var _str = buffer_read(_buf, buffer_string);
    buffer_delete(_buf);
    var _data = json_parse(_str);

    // New format (envelope with "tiles") vs old format (bare tiles struct)
    var _is_envelope = is_struct(_data) && variable_struct_exists(_data, "tiles");

    if (_is_envelope) {
        global.world_tiles = _data.tiles;

        // Copied clusters travel with the scene (thumbnails and all)
        if (variable_struct_exists(_data, "clips")) {
            clip_deserialize(_data.clips);
        }
        else {
            clip_deserialize([]);
        }

        // Restore the tileset this scene was saved with
        var _want_custom = false;
        var _want_path = "";
        var _want_cell = 0;   // 0 = let the importer detect it (legacy saves)
        if (variable_struct_exists(_data, "tileset")) {
            var _ts = _data.tileset;
            _want_custom = variable_struct_exists(_ts, "is_custom") ? _ts.is_custom : false;
            _want_path = variable_struct_exists(_ts, "path") ? _ts.path : "";
            // The cell size was always written but never read back, so a scene
            // saved with one cell size reimported at whatever was current.
            if (variable_struct_exists(_ts, "cell")) {
                _want_cell = _ts.cell;
            }
        }

        // Format 3 carries the sheet itself - always prefer it
        var _sheet_w = 0;
        var _sheet_h = 0;
        var _sheet_cell = 0;
        var _sheet_data = "";
        if (variable_struct_exists(_data, "tileset")) {
            var _ts2 = _data.tileset;
            if (variable_struct_exists(_ts2, "sheet_data")) {
                _sheet_data = _ts2.sheet_data;
                _sheet_w = _ts2.sheet_w;
                _sheet_h = _ts2.sheet_h;
                _sheet_cell = _ts2.sheet_cell;
            }
        }

        var _embedded = -1;
        if (_sheet_data != "") {
            _embedded = tileset_from_data(_sheet_w, _sheet_h, _sheet_cell, _sheet_data);
        }

        if (_embedded >= 0) {
            if (global.tile_custom >= 0 && sprite_exists(global.tile_custom)) {
                sprite_delete(global.tile_custom);
            }
            global.tile_custom = _embedded;
            global.tile_custom_path = _want_path; // may be "" for a sheet never saved
            global.tile_sprite = _embedded;
            global.tile_is_custom = true;
            palette_cols = max(1, global.tile_custom_cols);
            show_debug_message("Scene load: tileset restored from the scene file (" + string(sprite_get_number(_embedded)) + " tiles at " + string(global.tile_cell) + "px).");
        }
        else if (_want_custom && _want_path != "" && file_exists(_want_path)) {
            // Re-import the original sheet and switch to it
            var _loaded = tileset_import(_want_path, _want_cell);
            if (_loaded >= 0) {
                if (global.tile_custom >= 0 && sprite_exists(global.tile_custom)) {
                    sprite_delete(global.tile_custom);
                }
                global.tile_custom = _loaded;
                global.tile_custom_path = _want_path;
                global.tile_sprite = _loaded;
                global.tile_is_custom = true;
                palette_cols = max(1, global.tile_custom_cols);
            } else {
                // Import failed — fall back to built-in
                global.tile_sprite = spr_tile;
                global.tile_is_custom = false;
                global.tile_cell = sprite_get_width(spr_tile);
                palette_cols = palette_cols_builtin;
                show_debug_message("Scene load: custom tileset failed to import, using built-in.");
            }
        } else {
            if (_want_custom) {
                // Was custom, but the source PNG is gone
                show_debug_message("Scene load: custom tileset file not found (" + _want_path + "), using built-in.");
            }
            global.tile_sprite = spr_tile;
            global.tile_is_custom = false;
            global.tile_cell = sprite_get_width(spr_tile);
            palette_cols = palette_cols_builtin;
        }
    } else {
        // Legacy save: just the tiles, assume built-in tileset
        global.world_tiles = _data;
        global.tile_sprite = spr_tile;
        global.tile_is_custom = false;
        global.tile_cell = sprite_get_width(spr_tile);
        palette_cols = palette_cols_builtin;
    }

    return true;
}