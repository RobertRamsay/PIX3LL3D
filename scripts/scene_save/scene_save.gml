function scene_save(_path) {
    // Envelope: tileset metadata + the tile data. Old saves were a bare
    // tiles struct; load handles both shapes.
    var _envelope = {
        format: 2,
        tileset: {
            is_custom: global.tile_is_custom,
            path: global.tile_custom_path,
            cell: global.tile_cell
        },
        tiles: global.world_tiles
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

        // Restore the tileset this scene was saved with
        var _want_custom = false;
        var _want_path = "";
        if (variable_struct_exists(_data, "tileset")) {
            var _ts = _data.tileset;
            _want_custom = variable_struct_exists(_ts, "is_custom") ? _ts.is_custom : false;
            _want_path = variable_struct_exists(_ts, "path") ? _ts.path : "";
        }

        if (_want_custom && _want_path != "" && file_exists(_want_path)) {
            // Re-import the original sheet and switch to it
            var _loaded = tileset_import(_want_path, global.tile_cell);
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
            palette_cols = palette_cols_builtin;
        }
    } else {
        // Legacy save: just the tiles, assume built-in tileset
        global.world_tiles = _data;
        global.tile_sprite = spr_tile;
        global.tile_is_custom = false;
        palette_cols = palette_cols_builtin;
    }

    return true;
}