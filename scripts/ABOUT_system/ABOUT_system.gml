/// ABOUT_system
/// Credits / version panel, plus the update check.
///
/// The app's version lives in the included file "version.txt" (one line, e.g.
/// 1.0.0). The SAME file sits in the repo, so the running build fetches the
/// GitHub copy over HTTP and compares it with its own: bump version.txt, build,
/// commit, and everyone already running an older build is told there is a new
/// one on itch.io.
///
/// All state lives on obj_editor and is initialised in its Create event.
/// The panel is modal: while it is open the Step event returns early, so
/// neither the 3D editor nor the pixel editor sees any input.

#macro ABOUT_APP_NAME    "PIX3LL3D"
#macro ABOUT_TAGLINE     "3D tile-based voxel level editor"
#macro ABOUT_VERSION_FILE "version.txt"
#macro ABOUT_VERSION_URL "https://raw.githubusercontent.com/RobertRamsay/PIX3LL3D/master/datafiles/version.txt"
#macro ABOUT_ITCH_URL    "https://polytricity.itch.io/pixell3d"
#macro ABOUT_CHECK_ON_START true   // fetch the remote version once at launch

// ============================================================
//  VERSION FILE
// ============================================================

/// @desc First non-blank, non-comment line of a version file's text.
/// @param {String} _text raw file contents
/// @returns {String} version string, or "" when nothing usable was found
function version_parse_text(_text)
{
    var _clean = string_replace_all(string(_text), "\r", "");
    var _lines = string_split(_clean, "\n", false);
    for (var _i = 0; _i < array_length(_lines); _i++)
    {
        var _line = string_trim(_lines[_i]);
        if (_line == "")
        {
            continue;
        }
        if (string_char_at(_line, 1) == "#")
        {
            continue;
        }
        return _line;
    }
    return "";
}

/// @desc Read version.txt from the included files. Sets global.app_version.
/// Falls back through the usual locations so it works with the sandbox on or off.
function version_local_load()
{
    global.app_version = "";

    var _paths = [
        ABOUT_VERSION_FILE,
        working_directory + ABOUT_VERSION_FILE,
        program_directory + ABOUT_VERSION_FILE
    ];

    for (var _i = 0; _i < array_length(_paths); _i++)
    {
        var _path = _paths[_i];
        if (!file_exists(_path))
        {
            continue;
        }

        var _text = "";
        var _f = file_text_open_read(_path);
        if (_f == -1)
        {
            continue;
        }
        while (!file_text_eof(_f))
        {
            _text += file_text_read_string(_f) + "\n";
            file_text_readln(_f);
        }
        file_text_close(_f);

        var _ver = version_parse_text(_text);
        if (_ver != "")
        {
            global.app_version = _ver;
            return;
        }
    }

    // No file shipped with the build - say so rather than pretending
    global.app_version = "unknown";
}

/// @desc Split a version string into an array of 3 numbers (missing parts = 0).
/// Any trailing text on a part is dropped, so "1.2.0-beta" reads as 1.2.0.
function version_to_numbers(_v)
{
    var _out = [0, 0, 0];
    var _parts = string_split(string(_v), ".", false);
    for (var _i = 0; _i < 3; _i++)
    {
        if (_i < array_length(_parts))
        {
            var _digits = string_digits(_parts[_i]);
            if (_digits == "")
            {
                _out[_i] = 0;
            }
            else
            {
                _out[_i] = real(_digits);
            }
        }
    }
    return _out;
}

/// @desc Compare two version strings. Returns -1 (_a older), 0 (same), 1 (_a newer).
function version_compare(_a, _b)
{
    var _na = version_to_numbers(_a);
    var _nb = version_to_numbers(_b);
    for (var _i = 0; _i < 3; _i++)
    {
        if (_na[_i] < _nb[_i])
        {
            return -1;
        }
        if (_na[_i] > _nb[_i])
        {
            return 1;
        }
    }
    return 0;
}

// ============================================================
//  UPDATE CHECK (async HTTP; result arrives in the Async HTTP event)
// ============================================================

/// @desc Start fetching the remote version file. Safe to call repeatedly.
function about_check_update()
{
    if (about_state == "checking")
    {
        return;
    }
    about_state = "checking";
    about_message = "Checking for updates...";
    about_ver_remote = "";
    about_http_id = http_get(ABOUT_VERSION_URL);
}

/// @desc Handle one async HTTP reply. Called from the Async HTTP event with async_load.
function about_http_result(_async)
{
    var _id = _async[? "id"];
    if (_id != about_http_id)
    {
        return;
    }

    var _status = _async[? "status"];
    if (_status > 0)
    {
        return; // still downloading
    }

    if (_status < 0)
    {
        about_state = "failed";
        about_message = "Could not reach the update server.";
        return;
    }

    var _http = _async[? "http_status"];
    if (_http != 200)
    {
        about_state = "failed";
        about_message = "Update check failed (HTTP " + string(_http) + ").";
        return;
    }

    var _remote = version_parse_text(string(_async[? "result"]));
    if (_remote == "")
    {
        about_state = "failed";
        about_message = "Update check failed (empty version file).";
        return;
    }

    about_ver_remote = _remote;

    if (version_compare(global.app_version, _remote) < 0)
    {
        about_state = "update";
        about_message = "Version " + _remote + " is available.";
    }
    else
    {
        about_state = "current";
        about_message = "You are up to date.";
    }
}

// ============================================================
//  PANEL LAYOUT
// ============================================================

/// @desc Centre the panel on the GUI layer and lay out its buttons.
function about_layout()
{
    var _gw = display_get_gui_width();
    var _gh = display_get_gui_height();

    about_w = 560;
    about_h = 330;
    about_x = floor((_gw - about_w) * 0.5);
    about_y = floor((_gh - about_h) * 0.5);

    var _bw = 190;
    var _bh = 28;
    var _by = about_y + about_h - _bh - 18;

    about_btn_check = [about_x + 20, _by, about_x + 20 + _bw, _by + _bh];
    about_btn_itch = [about_x + 30 + _bw, _by, about_x + 30 + _bw * 2, _by + _bh];
    about_btn_close = [about_x + about_w - 20 - 90, _by, about_x + about_w - 20, _by + _bh];
}

/// @desc Is the GUI mouse inside a [x1, y1, x2, y2] button rect?
function about_over(_rect, _mx, _my)
{
    return (_mx >= _rect[0] && _mx < _rect[2] && _my >= _rect[1] && _my < _rect[3]);
}

// ============================================================
//  PER-FRAME INPUT
// ============================================================

/// @desc Open the panel (and remember it was asked for by name).
function about_show()
{
    about_visible = true;
}

/// @desc Per-frame menu actions, keys and clicks for the About panel.
/// Call in the Step event straight after menu_update(), before anything else.
function about_update()
{
    // --- Menu actions (consumed so the editors never see them) ---
    if (menu_action == "about_show")
    {
        about_show();
        menu_action = "";
    }
    else if (menu_action == "about_check")
    {
        about_show();
        about_check_update();
        menu_action = "";
    }
    else if (menu_action == "about_itch")
    {
        url_open(ABOUT_ITCH_URL);
        menu_action = "";
    }

    // --- F12 toggles the panel ---
    if (keyboard_check_pressed(vk_f12))
    {
        if (about_visible)
        {
            about_visible = false;
        }
        else
        {
            about_show();
        }
    }

    if (!about_visible)
    {
        return;
    }

    // Any other menu choice made while the panel is up dismisses it and runs as normal
    if (menu_action != "")
    {
        about_visible = false;
        return;
    }

    // The panel owns the mouse while it is up
    menu_blocks_mouse = true;

    about_layout();

    var _mx = device_mouse_x_to_gui(0);
    var _my = device_mouse_y_to_gui(0);

    about_hover = "";
    if (about_over(about_btn_check, _mx, _my))
    {
        about_hover = "check";
    }
    else if (about_over(about_btn_itch, _mx, _my))
    {
        about_hover = "itch";
    }
    else if (about_over(about_btn_close, _mx, _my))
    {
        about_hover = "close";
    }

    // --- Esc closes the panel (and must not fall through to quitting) ---
    if (keyboard_check_pressed(vk_escape) && !menu_esc_consumed)
    {
        about_visible = false;
        menu_esc_consumed = true;
        return;
    }

    // --- Clicks (a click the menu bar already took is left alone) ---
    if (mouse_check_button_pressed(mb_left) && !menu_click_consumed)
    {
        if (about_hover == "check")
        {
            about_check_update();
        }
        else if (about_hover == "itch")
        {
            url_open(ABOUT_ITCH_URL);
        }
        else if (about_hover == "close")
        {
            about_visible = false;
        }
        else
        {
            var _inside = (_mx >= about_x && _mx < about_x + about_w && _my >= about_y && _my < about_y + about_h);
            if (!_inside)
            {
                about_visible = false;
            }
        }
    }
}

// ============================================================
//  DRAW
// ============================================================

/// @desc One button of the panel.
function about_draw_button(_rect, _label, _hot, _enabled)
{
    var _col = menu_col_hover;
    if (!_enabled)
    {
        _col = menu_col_panel;
    }
    else if (_hot)
    {
        _col = menu_col_accent;
    }

    draw_set_colour(_col);
    draw_rectangle(_rect[0], _rect[1], _rect[2], _rect[3], false);
    draw_set_colour(menu_col_line);
    draw_rectangle(_rect[0], _rect[1], _rect[2], _rect[3], true);

    if (_enabled)
    {
        draw_set_colour(c_white);
    }
    else
    {
        draw_set_colour(c_gray);
    }
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_text((_rect[0] + _rect[2]) * 0.5, (_rect[1] + _rect[3]) * 0.5, _label);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}

/// @desc Draw the About panel. Call in Draw GUI, just before menu_draw().
function about_draw()
{
    if (!about_visible)
    {
        return;
    }

    about_layout();

    var _gw = display_get_gui_width();
    var _gh = display_get_gui_height();

    gpu_set_cullmode(cull_noculling);
    gpu_set_tex_filter(true);
    draw_set_font(-1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);

    // Dim everything behind the panel
    draw_set_alpha(0.55);
    draw_set_colour(c_black);
    draw_rectangle(0, 0, _gw, _gh, false);
    draw_set_alpha(1);

    var _x1 = about_x;
    var _y1 = about_y;
    var _x2 = about_x + about_w;
    var _y2 = about_y + about_h;

    // Shadow, body, outline
    draw_set_alpha(0.35);
    draw_set_colour(c_black);
    draw_rectangle(_x1 + 6, _y1 + 6, _x2 + 6, _y2 + 6, false);
    draw_set_alpha(1);
    draw_set_colour(menu_col_panel);
    draw_rectangle(_x1, _y1, _x2, _y2, false);
    draw_set_colour(menu_col_line);
    draw_rectangle(_x1, _y1, _x2, _y2, true);

    // Title strip
    draw_set_colour(menu_col_bar);
    draw_rectangle(_x1 + 1, _y1 + 1, _x2 - 1, _y1 + 44, false);
    draw_set_colour(menu_col_line);
    draw_line(_x1 + 1, _y1 + 44, _x2 - 1, _y1 + 44);

    draw_set_colour(c_white);
    draw_text(_x1 + 20, _y1 + 8, ABOUT_APP_NAME);
    draw_set_colour(c_ltgray);
    draw_text(_x1 + 20, _y1 + 25, ABOUT_TAGLINE);

    var _lx = _x1 + 20;
    var _vx = _x1 + 190;
    var _ty = _y1 + 62;
    var _line = 19;

    // --- Version ---
    draw_set_colour(c_ltgray);
    draw_text(_lx, _ty, "Version");
    draw_set_colour(c_white);
    draw_text(_vx, _ty, global.app_version);
    _ty += _line;

    draw_set_colour(c_ltgray);
    draw_text(_lx, _ty, "Latest release");
    if (about_state == "update")
    {
        draw_set_colour(c_yellow);
        draw_text(_vx, _ty, about_ver_remote + "  -  update available");
    }
    else if (about_state == "current")
    {
        draw_set_colour(c_lime);
        draw_text(_vx, _ty, about_ver_remote + "  -  up to date");
    }
    else if (about_state == "checking")
    {
        draw_set_colour(c_white);
        draw_text(_vx, _ty, "checking...");
    }
    else if (about_state == "failed")
    {
        draw_set_colour(c_orange);
        draw_text(_vx, _ty, about_message);
    }
    else
    {
        draw_set_colour(c_gray);
        draw_text(_vx, _ty, "not checked yet");
    }
    _ty += _line + 12;

    // --- Credits ---
    draw_set_colour(menu_col_line);
    draw_line(_lx, _ty, _x2 - 20, _ty);
    _ty += 10;

    draw_set_colour(c_white);
    draw_text(_lx, _ty, "Credits");
    _ty += _line + 4;

    draw_set_colour(c_ltgray);
    draw_text(_lx, _ty, "Code and design");
    draw_set_colour(c_white);
    draw_text(_vx, _ty, "Robert Ramsay");
    _ty += _line;

    draw_set_colour(c_ltgray);
    draw_text(_lx, _ty, "Built-in graphics");
    draw_set_colour(c_white);
    draw_text(_vx, _ty, "Robert Ramsay");
    _ty += _line;

    draw_set_colour(c_ltgray);
    draw_text(_lx, _ty, "Published by");
    draw_set_colour(c_white);
    draw_text(_vx, _ty, "Polytricity Ltd");
    _ty += _line + 8;

    draw_set_colour(c_gray);
    draw_text(_lx, _ty, ABOUT_ITCH_URL);

    // --- Buttons ---
    var _can_check = (about_state != "checking");
    about_draw_button(about_btn_check, "Check for updates", (about_hover == "check"), _can_check);
    about_draw_button(about_btn_itch, "Get it on itch.io", (about_hover == "itch"), true);
    about_draw_button(about_btn_close, "Close", (about_hover == "close"), true);

    // Restore shared draw state
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_colour(c_white);
    draw_set_alpha(1);
    gpu_set_tex_filter(tex_filter_on);
}
