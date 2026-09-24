/// FILE_system
/// Wrappers around the OS file dialogs.
///
/// These used to drop out of fullscreen and back around each dialog, because
/// a modal dialog over an EXCLUSIVE fullscreen window traps focus. The editor
/// no longer uses exclusive fullscreen at all (see WINDOW_system - "fullscreen"
/// is a borderless window filling the display), so that dance is not needed,
/// and it was costing a full swap chain teardown and rebuild on every save and
/// load. A modal dialog over a borderless window behaves itself.

/// @desc Show an open-file dialog.
function get_open_filename_safe(_filter, _fname)
{
    return get_open_filename(_filter, _fname);
}

/// @desc Show a save-file dialog.
function get_save_filename_safe(_filter, _fname)
{
    return get_save_filename(_filter, _fname);
}

// ============================================================
//  RECENT SCENES
// ============================================================
// The list lives next to the user's other app data, not beside the exe: the
// file sandbox is off on both targets, so a relative path would land in the
// install folder, which is not writable once installed.

#macro RECENT_MAX 10

/// @desc Where the recent list is kept.
function recent_store_path()
{
    var _dir = environment_get_variable("APPDATA");   // Windows
    if (_dir == "")
    {
        _dir = environment_get_variable("HOME");      // macOS / Linux
    }
    if (_dir == "")
    {
        return "pix3ll3d_recent.txt";
    }
    return _dir + "/pix3ll3d_recent.txt";
}

/// @desc Read the list from disk into global.recent_scenes (newest first).
function recent_load()
{
    global.recent_scenes = [];

    var _file = recent_store_path();
    if (!file_exists(_file))
    {
        return;
    }

    var _f = file_text_open_read(_file);
    if (_f < 0)
    {
        return;
    }

    while (!file_text_eof(_f) && array_length(global.recent_scenes) < RECENT_MAX)
    {
        var _line = string_trim(file_text_read_string(_f));
        file_text_readln(_f);
        if (_line != "")
        {
            array_push(global.recent_scenes, _line);
        }
    }
    file_text_close(_f);
}

/// @desc Write global.recent_scenes back out.
function recent_write()
{
    var _f = file_text_open_write(recent_store_path());
    if (_f < 0)
    {
        return;
    }
    for (var _i = 0; _i < array_length(global.recent_scenes); _i++)
    {
        file_text_write_string(_f, global.recent_scenes[_i]);
        file_text_writeln(_f);
    }
    file_text_close(_f);
}

/// @desc Put a scene at the top of the list, dropping any earlier copy of it
/// and anything past RECENT_MAX. Saves the list and refreshes the File menu.
function recent_add(_path)
{
    if (_path == "")
    {
        return;
    }

    for (var _i = array_length(global.recent_scenes) - 1; _i >= 0; _i--)
    {
        if (global.recent_scenes[_i] == _path)
        {
            array_delete(global.recent_scenes, _i, 1);
        }
    }

    array_insert(global.recent_scenes, 0, _path);

    while (array_length(global.recent_scenes) > RECENT_MAX)
    {
        array_delete(global.recent_scenes, array_length(global.recent_scenes) - 1, 1);
    }

    recent_write();
    recent_menu_sync();
}

/// @desc Forget the whole list.
function recent_clear()
{
    global.recent_scenes = [];
    recent_write();
    recent_menu_sync();
}

/// @desc Drop one entry (a file that has gone missing).
function recent_remove_at(_index)
{
    if (_index < 0 || _index >= array_length(global.recent_scenes))
    {
        return;
    }
    array_delete(global.recent_scenes, _index, 1);
    recent_write();
    recent_menu_sync();
}

/// @desc Rebuild the File menu from menu_file_base, with the recent scenes
/// slotted in after "Load scene..." Call whenever the list changes.
function recent_menu_sync()
{
    var _fi = -1;
    for (var _i = 0; _i < array_length(menu_defs); _i++)
    {
        if (menu_defs[_i].title == "File")
        {
            _fi = _i;
        }
    }
    if (_fi < 0)
    {
        return;
    }

    var _items = [];
    for (var _i = 0; _i < array_length(menu_file_base); _i++)
    {
        var _it = menu_file_base[_i];
        array_push(_items, _it);

        if (_it.act == "scene_load")
        {
            array_push(_items, { label: "-", key: "", act: "", mode: "3d" });

            var _count = array_length(global.recent_scenes);
            if (_count == 0)
            {
                array_push(_items, { label: "Recent scenes (none yet)", key: "", act: "", mode: "3d" });
            }
            else
            {
                for (var _r = 0; _r < _count; _r++)
                {
                    array_push(_items, {
                        label: string(_r + 1) + "  " + filename_name(global.recent_scenes[_r]),
                        key: "",
                        act: "recent_" + string(_r),
                        mode: "3d"
                    });
                }
                array_push(_items, { label: "Clear recent scenes", key: "", act: "recent_clear", mode: "3d" });
            }
        }
    }

    menu_defs[_fi].items = _items;
}
